#!/usr/bin/env python3
"""Actual BlockerWatch boundaries with isolated fake GitHub/harness processes."""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/github-requests"))
import report


def bash_path():
    if os.name == "nt":
        return str(Path(os.environ["ProgramFiles"]) / "Git/bin/bash.exe")
    return shutil.which("bash")


class ActiveReceipts(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.state = self.root / "state"
        self.fake = self.root / "gh"
        self.fake.write_text('''#!/usr/bin/env bash
set -eu
printf '%s\\n' "${AI_GH_WORKFLOW_ID:-unset}" >> "$FIXTURE/ids"
args=("$@"); q=''
for ((i=0;i<${#args[@]};i++)); do
  case "${args[$i]}" in --jq|-q) q="${args[$((i+1))]}" ;; esac
done
out(){ if [ -n "$q" ]; then printf '%s' "$1" | jq -r "$q"; else printf '%s\\n' "$1"; fi; }
case "$*" in
 *graphql*states:OPEN*)
   [ ! -f "$FIXTURE/read-fail" ] || exit 7
   out "$(cat "$FIXTURE/snapshot.json")" ;;
 *graphql*) out "$(cat "$FIXTURE/detail.json")" ;;
 *'-X POST'*blocked_by*)
   if [ -f "$FIXTURE/fail-all" ] || { [ -f "$FIXTURE/fail-second" ] && [[ "$*" = *issue_id=208* ]]; }; then exit 7; fi
   out '{}' ;;
 'issue comment'*) [ ! -f "$FIXTURE/comment-fail" ] || exit 7; out '{}' ;;
 'search issues'*) out '[]' ;;
 'issue create'*) [ ! -f "$FIXTURE/create-fail" ] || exit 7; out '"https://example.invalid/31"' ;;
 'issue edit'*) out '{}' ;;
 'api user'*) out '{"id":1}' ;;
 *search/issues*) out '{"items":[]}' ;;
 *) out '{}' ;;
esac
''', newline="\n")
        self.fake.chmod(0o700)
        self.harness = self.root / "harness"
        self.harness.write_text('''#!/usr/bin/env bash
case "${HARNESS_MODE:-ok}" in
 fail) exit 7 ;;
 active) printf 'already has an active writer (code -32600)\\n' >&2; exit 1 ;;
 interrupt) kill -TERM "$PPID"; exit 143 ;;
esac
exit 0
''', newline="\n")
        self.harness.chmod(0o700)
        self.config = json.loads((ROOT / "config/blocker-watch.json").read_text())
        self.config.update(repos=["o/r"], stuck_watchdog_enabled=False, fixer_enabled=False,
                           transcript_glob={}, max_wake_attempts=2, wake_timeout_minutes=1)
        self.config.pop("propagate_on_host", None)
        self.config["harness"]["codex"] = [self.harness.as_posix()]
        self.environment = dict(os.environ, HOME=self.home.as_posix(), FIXTURE=self.root.as_posix(),
                                AI_BLOCKER_WATCH_HOME=(self.root / "watch").as_posix(),
                                AI_GH_STATE_DIR=self.state.as_posix(), AI_GH_REAL_GH=self.fake.as_posix(),
                                AI_GH_MIN_SPACING_SECONDS="0", AI_GH_QUOTA_PROBE_SECONDS="off",
                                GH_CONFIG_DIR=(self.home / "gh").as_posix(),
                                XDG_CONFIG_HOME=(self.home / "config").as_posix(), SSH_CONNECTION="",
                                AI_DEVOPS_TEST_MODE="1", GH_TOKEN="fake-private-token")
        for name in ("AI_BLOCKER_WATCH_TEST_GH", "AI_BLOCKER_WATCH_GH", "AI_GH_WORKFLOW_ID",
                     "GITHUB_TOKEN", "GH_ENTERPRISE_TOKEN"):
            self.environment.pop(name, None)
        self.snapshot([])
        self.detail = dict(updatedAt="2000-01-01T00:00:00Z", createdAt="2000-01-01T00:00:00Z",
                           body="", comments={"nodes": []}, timelineItems={"nodes": []}, blocking={"nodes": []})
        self.write_detail()

    def write_detail(self):
        (self.root / "detail.json").write_text(json.dumps({"data": {"rateLimit": self.cost(),
                                                          "repository": {"issue": self.detail}}}))

    def cost(self):
        return {"cost": 1, "remaining": 4999, "resetAt": "2026-11-02T00:00:00Z"}

    def snapshot(self, nodes):
        (self.root / "snapshot.json").write_text(json.dumps({"data": {"rateLimit": self.cost(), "repository": {
            "issues": {"nodes": nodes, "pageInfo": {"hasNextPage": False, "endCursor": None}}}}}))

    def links(self, dependencies="7", present=False):
        self.snapshot([{"number": 20, "databaseId": 220, "body": "```db-work-scope\ndepends_on: " + dependencies + "\n```",
                        "blockedBy": {"nodes": [{"number": 7}] if present else []}},
                       {"number": 7, "databaseId": 207, "body": "", "blockedBy": {"nodes": []}},
                       {"number": 8, "databaseId": 208, "body": "", "blockedBy": {"nodes": []}}])

    def alarm(self):
        self.snapshot([{"number": 20, "databaseId": 220, "body": "", "blockedBy": {"nodes": [
            {"number": 7, "state": "OPEN", "repository": {"nameWithOwner": "o/r"},
             "assignees": {"totalCount": 0}, "title": "synthetic blocker"}]}}])

    def run_command(self, command, *args):
        p = self.root / "config.json"
        p.write_text(json.dumps(self.config))
        env = dict(self.environment, AI_BLOCKER_WATCH_CONFIG=p.as_posix())
        argv = [bash_path(), (ROOT / "bin/ai-blocker-watch").as_posix(), command, *args]
        if getattr(self, "path_prefix", None) is not None:
            # Native Windows PATH is translated at MSYS startup. Bind this
            # one failure stub afterward, using the shell's own path spelling.
            # Keep the original source/arguments in this same shell: a second
            # native Bash startup can reset PATH again. The caller uses
            # BASH_SOURCE (not $0), and retains its own set-e and EXIT cleanup.
            argv = [bash_path(), "-c", 'prefix="$1"; script="$2"; shift 2; if command -v cygpath >/dev/null 2>&1; then prefix="$(cygpath -u "$prefix")" || exit 2; fi; PATH="$prefix:$PATH"; export PATH; source "$script" "$@"',
                    "fixture", self.path_prefix, *argv[1:]]
        return subprocess.run(argv,
                              env=env, capture_output=True, text=True, timeout=45)

    def rows(self):
        return [json.loads(line) for p in (self.state / "measurements").glob("*.jsonl") for line in p.read_text().splitlines()]

    def active(self, workflow):
        return [r for r in self.rows() if r.get("schema") == 3 and r.get("workflow") == "blocker_watch_" + workflow][-1]

    def test_links_active_and_cost_correlation(self):
        self.links()
        result = self.run_command("links")
        self.assertEqual(result.returncode, 0, result.stderr)
        row = self.active("links")
        self.assertEqual((row["outcome"], row["attempted_count"], row["succeeded_count"]), ("completed", 1, 1))
        self.assertIsNone(row["parent_workflow_id"])
        costs = [r for r in self.rows() if r.get("schema") == 2]
        self.assertTrue(costs)
        self.assertTrue(all(r["workflow_id"] == row["workflow_id"] for r in costs))
        summary = report.summarize(self.state / "measurements")
        self.assertEqual(summary["completed_workflow_receipts"], 0)
        self.assertEqual(summary["active_blocker_watch_operations"][0]["successful_active_operations"], 1)

    def test_links_partial_and_failure_keep_original_status(self):
        self.links("7,8")
        (self.root / "fail-second").touch()
        result = self.run_command("links")
        self.assertEqual(result.returncode, 1, result.stderr)
        row = self.active("links")
        self.assertEqual((row["outcome"], row["attempted_count"], row["succeeded_count"], row["failed_count"]), ("partial", 2, 1, 1))
        (self.root / "fail-all").touch()
        self.assertEqual(self.run_command("links").returncode, 1)
        self.assertEqual(self.active("links")["outcome"], "failed")

    def test_shared_tick_snapshot_is_not_counted_for_both_children(self):
        result = self.run_command("tick")
        self.assertEqual(result.returncode, 0, result.stderr)
        active = [r for r in self.rows() if r.get("schema") == 3 and "parent_workflow_id" in r]
        parent = next(r for r in self.rows() if r.get("workflow") == "blocker_watch_tick" and r.get("schema") == 3)
        self.assertEqual(len({r["workflow_id"] for r in active}), 2)
        self.assertTrue(all(r["parent_workflow_id"] == parent["workflow_id"] for r in active))
        costs = [r for r in self.rows() if r.get("schema") == 2]
        self.assertEqual(sum(r["graphql_points"] for r in costs), 1)
        self.assertTrue(all(r["workflow_id"] != parent["workflow_id"] for r in costs))
        self.assertEqual(report.summarize(self.state / "measurements")["linked_graphql_points"], 1)

    def test_scan_read_failure_is_failed_without_invented_write_attempt(self):
        (self.root / "read-fail").touch()
        self.assertEqual(self.run_command("links").returncode, 1)
        row = self.active("links")
        self.assertEqual((row["outcome"], row["attempted_count"], row["succeeded_count"], row["failed_count"]), ("failed", 0, 0, 0))

    def test_idle_dry_locked_and_host_refusal_are_not_active(self):
        self.assertEqual(self.run_command("links").returncode, 0)
        self.assertEqual(self.active("links")["outcome"], "skipped")
        self.links()
        self.assertEqual(self.run_command("links", "--dry-run").returncode, 0)
        self.assertEqual(self.active("links")["attempted_count"], 0)
        self.config["propagate_on_host"] = "synthetic-other-host"
        self.assertEqual(self.run_command("links").returncode, 0)
        self.assertEqual(self.active("links")["outcome"], "skipped")
        lock = self.root / "watch/tick.lock"
        lock.mkdir()
        self.assertEqual(self.run_command("links").returncode, 0)
        self.assertEqual(self.active("links")["outcome"], "skipped")
        summary = report.summarize(self.state / "measurements")
        self.assertEqual(sum(r["successful_active_operations"] for r in summary["active_blocker_watch_operations"]), 0)

    def test_alarm_active_partial_and_preflight_failure(self):
        self.alarm()
        self.assertEqual(self.run_command("alarm").returncode, 0)
        self.assertEqual((self.active("alarm")["outcome"], self.active("alarm")["succeeded_count"]), ("completed", 2))
        (self.root / "comment-fail").touch()
        self.assertEqual(self.run_command("alarm").returncode, 1)
        self.assertEqual(self.active("alarm")["outcome"], "partial")
        (self.root / "read-fail").touch()
        for p in (self.root / "watch").glob("digest-*"):
            p.unlink()
        self.assertEqual(self.run_command("alarm").returncode, 1)
        self.assertEqual(self.active("alarm")["outcome"], "failed")

    def test_scan_cleanup_failure_cannot_emit_completed(self):
        self.alarm()
        self.config["links_enabled"] = False
        fake_bin = self.root / "fake-bin"
        fake_bin.mkdir()
        command = fake_bin / "rm"
        command.write_text('''#!/usr/bin/env bash
printf 'entered\\n' >> "$FIXTURE/cleanup-stub-entry"
for argument in "$@"; do
  case "$argument" in */alarm-tick) printf '9\\n' >> "$FIXTURE/cleanup-failure-status"; exit 9 ;; esac
done
exec /usr/bin/rm "$@"
''', newline="\n")
        command.chmod(0o700)
        self.path_prefix = fake_bin.as_posix()
        result = self.run_command("tick")
        # Existing tick behavior ignores this cleanup status; do not change it.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "cleanup-stub-entry").exists(), "cleanup failure stub was not selected")
        status_file = self.root / "cleanup-failure-status"
        self.assertTrue(status_file.exists(), "cleanup nonzero status was not injected")
        self.assertEqual(set(status_file.read_text().splitlines()), {"9"})
        row = self.active("alarm")
        self.assertEqual((row["outcome"], row["succeeded_count"]), ("partial", 2))

    def make_wait(self):
        self.config.update(repos=[], alarm_enabled=False, links_enabled=False, propagate_on_host="synthetic-other-host")
        directory = self.root / "watch/waits"
        directory.mkdir(parents=True)
        row = dict(id="synthetic", blocker="", harness="codex", session="private-session-sentinel",
                   cwd=self.root.as_posix(), until="2000-01-01T00:00:00Z", state="waiting", attempts=0,
                   note="private-prompt-sentinel", parked_issue="", parked_url="", main_checkout="")
        (directory / "synthetic.json").write_text(json.dumps(row))

    def test_wake_success_has_tick_parent_and_no_private_content(self):
        self.make_wait()
        result = self.run_command("tick")
        self.assertEqual(result.returncode, 0, result.stderr)
        row = self.active("wake")
        self.assertEqual((row["outcome"], row["attempted_count"], row["succeeded_count"]), ("process_succeeded", 1, 1))
        parent = next(r for r in self.rows() if r.get("workflow") == "blocker_watch_tick" and r.get("schema") == 3)
        self.assertEqual(row["parent_workflow_id"], parent["workflow_id"])
        raw = json.dumps(self.rows())
        self.assertNotIn("private-session-sentinel", raw)
        self.assertNotIn("private-prompt-sentinel", raw)
        self.assertNotIn(self.root.as_posix(), raw)

    def test_failed_wake_keeps_failed_tick_and_unmatched_child(self):
        self.make_wait()
        self.environment["HARNESS_MODE"] = "fail"
        self.assertEqual(self.run_command("tick").returncode, 1)
        row = self.active("wake")
        self.assertEqual((row["outcome"], row["failed_count"]), ("process_failed", 1))
        summary = report.summarize(self.state / "measurements")
        self.assertEqual(summary["active_blocker_watch_operations"][0]["parent_state"], "unmatched_unknown")

    def test_active_writer_refusal_does_not_spend_retry(self):
        self.make_wait()
        self.environment["HARNESS_MODE"] = "active"
        self.assertEqual(self.run_command("tick").returncode, 0)
        row = self.active("wake")
        self.assertEqual((row["outcome"], row["attempted_count"], row["failed_count"], row["skipped_count"]), ("refused", 1, 0, 1))
        wait = json.loads((self.root / "watch/waits/synthetic.json").read_text())
        self.assertEqual((wait["state"], wait["attempts"]), ("waiting", 0))

    def test_dry_or_unreleased_wake_never_counts_success(self):
        self.make_wait()
        self.assertEqual(self.run_command("tick", "--dry-run").returncode, 0)
        self.assertEqual((self.active("wake")["outcome"], self.active("wake")["attempted_count"]), ("skipped", 0))
        path = self.root / "watch/waits/synthetic.json"
        row = json.loads(path.read_text()); row["until"] = "2999-01-01T00:00:00Z"
        path.write_text(json.dumps(row))
        self.assertEqual(self.run_command("tick").returncode, 0)
        self.assertEqual(self.active("wake")["outcome"], "skipped")

    def test_interrupted_harness_cannot_emit_success(self):
        self.make_wait()
        self.environment["HARNESS_MODE"] = "interrupt"
        self.assertEqual(self.run_command("tick").returncode, 1)
        self.assertEqual(self.active("wake")["outcome"], "process_failed")

    def test_measurement_failure_preserves_failed_process(self):
        self.make_wait()
        self.environment["HARNESS_MODE"] = "fail"
        self.state.mkdir()
        (self.state / "measurements").write_text("owned refusal fixture")
        self.assertEqual(self.run_command("tick").returncode, 1)
        wait = json.loads((self.root / "watch/waits/synthetic.json").read_text())
        self.assertEqual((wait["state"], wait["attempts"]), ("waiting", 1))

    def receipt(self, **changes):
        row = dict(schema=3, utc="2026-11-01T12:00:00Z", measurement="workflow_outcome",
                   caller="ai-blocker-watch", workflow="blocker_watch_links", workflow_id="a" * 32,
                   outcome="completed", elapsed_ms=1, boundary="links_scan", attempted_count=1,
                   succeeded_count=1, failed_count=0, skipped_count=0, parent_workflow_id=None)
        row.update(changes)
        return row

    def aggregate_rows(self, rows, raw=None):
        directory = self.root / "validator"
        directory.mkdir(exist_ok=True)
        (directory / "2026-11-01.jsonl").write_text(raw if raw is not None else "".join(json.dumps(r) + "\n" for r in rows))
        return report.summarize(directory)

    def test_strict_counts_ids_shape_and_duplicate_keys(self):
        for changes in [dict(attempted_count=True), dict(succeeded_count=1.0), dict(failed_count=-1),
                        dict(skipped_count=1000000000), dict(boundary="wake_process_exit"),
                        dict(parent_workflow_id="a" * 32), dict(parent_workflow_id="private-target"),
                        dict(private_target="must never enter receipts"), dict(succeeded_count=2),
                        dict(attempted_count=0, succeeded_count=0), dict(outcome="partial", succeeded_count=0),
                        dict(outcome="skipped", succeeded_count=1)]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                self.aggregate_rows([self.receipt(**changes)])
        with self.assertRaises(ValueError):
            self.aggregate_rows([self.receipt(), self.receipt()])
        raw = json.dumps(self.receipt()).replace('"attempted_count": 1', '"attempted_count": 0, "attempted_count": 1') + "\n"
        with self.assertRaises(ValueError):
            self.aggregate_rows([], raw=raw)

    def test_backward_compatibility_and_parent_validation(self):
        legacy = dict(schema=3, utc="2026-11-01T12:00:00Z", measurement="workflow_outcome",
                      caller="ai-blocker-watch", workflow="blocker_watch_tick", workflow_id="b" * 32,
                      outcome="completed", elapsed_ms=1)
        result = self.aggregate_rows([legacy, self.receipt(parent_workflow_id="b" * 32)])
        self.assertEqual(result["completed_workflow_receipts"], 1)
        self.assertEqual(result["active_blocker_watch_operations"][0]["parent_state"], "matched")
        result = self.aggregate_rows([self.receipt(parent_workflow_id="b" * 32)])
        self.assertEqual(result["active_blocker_watch_operations"][0]["parent_state"], "unmatched_unknown")
        with self.assertRaises(ValueError):
            self.aggregate_rows([self.receipt(parent_workflow_id="b" * 32),
                                 self.receipt(workflow_id="b" * 32, parent_workflow_id="a" * 32)])
        bad = copy.deepcopy(legacy); bad.update(caller="ai-pr-wait", workflow="pr_wait", outcome="merged")
        with self.assertRaises(ValueError):
            self.aggregate_rows([bad, self.receipt(parent_workflow_id="b" * 32)])
        self.assertEqual(result["qualified_latency_ms"]["count"], 0)

    def test_finite_emitter_preserves_legacy_shape_and_refuses_bad_fields(self):
        def emit(args):
            return subprocess.run([bash_path(), "-c", 'source "$1"; shift; gh_measure_workflow_outcome "$@"',
                                   "fixture", (ROOT / "tools/github-requests/telemetry.sh").as_posix(), *args],
                                  env=self.environment, capture_output=True, timeout=10)
        legacy = ["ai-blocker-watch", "blocker_watch_tick", "b" * 32, "completed", "1"]
        active = ["ai-blocker-watch", "blocker_watch_links", "a" * 32, "completed", "1",
                  "links_scan", "1", "1", "0", "0", "b" * 32]
        self.assertEqual(emit(legacy).returncode, 0)
        self.assertEqual(emit(active).returncode, 0)
        rows = [r for r in self.rows() if r.get("schema") == 3]
        self.assertEqual(set(rows[0]), report.RECEIPT_KEYS)
        self.assertEqual(set(rows[1]), report.ACTIVE_RECEIPT_KEYS)
        for index, value in [(2, "bad"), (5, "alarm_scan"), (6, "01"), (7, "1.0"), (8, "-1"), (10, "a" * 32)]:
            args = active.copy(); args[index] = value
            self.assertEqual(emit(args).returncode, 2)
        self.assertEqual(emit(active[:-1]).returncode, 2)
        self.assertEqual(emit(legacy + ["private-content"]).returncode, 2)


if __name__ == "__main__":
    unittest.main()
