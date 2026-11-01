#!/usr/bin/env python3
"""Actual BlockerWatch boundaries with isolated fake GitHub/harness processes."""
import copy
import datetime
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
printf '%s\\n' "$*" >> "$FIXTURE/calls"
args=("$@"); q=''; n=''
for ((i=0;i<${#args[@]};i++)); do
  case "${args[$i]}" in --jq|-q) q="${args[$((i+1))]}" ;; esac
  case "${args[$i]}" in -F) value="${args[$((i+1))]}"; case "$value" in n=*) n="${value#n=}" ;; esac ;; esac
done
out(){ if [ -n "$q" ]; then printf '%s' "$1" | jq -r "$q"; else printf '%s\\n' "$1"; fi; }
case "$*" in
 *graphql*states:OPEN*)
   [ ! -f "$FIXTURE/read-fail" ] || exit 7
   out "$(cat "$FIXTURE/snapshot.json")" ;;
 *graphql*)
   if [ -n "$n" ] && [ -f "$FIXTURE/detail-$n.json" ]; then out "$(cat "$FIXTURE/detail-$n.json")"
   else out "$(cat "$FIXTURE/detail.json")"; fi ;;
 *repos/o/r/issues/5*) out "$(cat "$FIXTURE/issue.json")" ;;
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
        (self.root / "issue.json").write_text(json.dumps({"state": "open", "pull_request": None,
                                                        "title": "synthetic title", "closed_at": None}))
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


class BlockerEventFacts(unittest.TestCase):
    # Reuse the original actual-caller fixture, without inheriting/repeating
    # its stage-one tests when selecting this producer packet natively.
    setUp = ActiveReceipts.setUp
    write_detail = ActiveReceipts.write_detail
    cost = ActiveReceipts.cost
    snapshot = ActiveReceipts.snapshot
    links = ActiveReceipts.links
    alarm = ActiveReceipts.alarm
    run_command = ActiveReceipts.run_command
    rows = ActiveReceipts.rows
    active = ActiveReceipts.active
    make_wait = ActiveReceipts.make_wait

    def fact(self, workflow):
        row = [r for r in self.rows() if r.get("schema") == 4 and r.get("workflow") == "blocker_watch_" + workflow][-1]
        self.assertEqual(set(row), report.EVIDENCE_KEYS)
        self.assertTrue(report.unqualified_blocker_event(row))
        self.assertFalse(report.unqualified_event(row))
        self.assertEqual((row["source_verified"], row["clock_quality"]), ("unknown", "unknown"))
        for name in ("source_fingerprint_start", "source_fingerprint_end", "install_generation_binding",
                     "clock_error_bound_ms", "latency_ms", "cohort_id", "target_ordinal"):
            self.assertIsNone(row[name])
        self.assertEqual(row["workflow_id"], self.active(workflow)["workflow_id"])
        return row

    def update_wait(self, **changes):
        path = self.root / "watch/waits/synthetic.json"
        row = json.loads(path.read_text()); row.update(state="waiting", attempts=0); row.update(changes)
        path.write_text(json.dumps(row))

    def issue(self, **changes):
        row = dict(state="closed", pull_request=None, title="public-title-sentinel", closed_at="2001-01-01T00:00:00Z")
        row.update(changes)
        (self.root / "issue.json").write_text(json.dumps(row))

    def epoch_ms(self, value):
        return int(datetime.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() * 1000)

    def test_closed_response_preserves_title_and_uses_no_additional_request(self):
        self.make_wait(); self.update_wait(blocker="o/r#5")
        self.issue()
        result = self.run_command("tick")
        self.assertEqual(result.returncode, 0, result.stderr)
        row = self.fact("wake")
        self.assertEqual(row["event_kind"], "blocker_closed")
        self.assertEqual(row["eligible_utc_ms"], self.epoch_ms("2001-01-01T00:00:00Z"))
        self.assertEqual(row["delivery_boundary"], "wake_command_returned")
        self.assertGreaterEqual(row["delivered_utc_ms"], row["observed_utc_ms"])
        self.assertIn("public-title-sentinel", result.stderr)
        calls = (self.root / "calls").read_text().splitlines()
        self.assertEqual(sum(line.startswith("api repos/o/r/issues/5 ") for line in calls), 1)
        self.assertEqual(result.stdout, "")

    def test_closed_missing_invalid_and_out_of_domain_times_remain_null(self):
        self.make_wait()
        for value in (None, "", "not-a-date", "2026-02-30T00:00:00Z", "2400-01-01T00:00:00Z", 123):
            with self.subTest(value=value):
                self.update_wait(blocker="o/r#5")
                self.issue(closed_at=value)
                self.assertEqual(self.run_command("tick").returncode, 0)
                row = self.fact("wake")
                self.assertEqual(row["event_kind"], "blocker_closed")
                self.assertIsNone(row["eligible_utc_ms"])
                self.assertIsNotNone(row["observed_utc_ms"])

    def test_future_genuine_server_time_is_retained_as_clock_uncertainty(self):
        self.make_wait(); self.update_wait(blocker="o/r#5")
        self.issue(closed_at="2099-01-01T00:00:00Z")
        self.assertEqual(self.run_command("tick").returncode, 0)
        row = self.fact("wake")
        self.assertEqual(row["eligible_utc_ms"], self.epoch_ms("2099-01-01T00:00:00Z"))
        self.assertGreater(row["eligible_utc_ms"], row["observed_utc_ms"])
        self.assertEqual(row["unknown_reason"], "clock_unknown")
        self.assertIsNone(row["latency_ms"])

    def test_timer_uses_existing_due_value_and_closed_blocker_takes_precedence(self):
        self.make_wait()
        self.assertEqual(self.run_command("tick").returncode, 0)
        row = self.fact("wake")
        self.assertEqual((row["event_kind"], row["eligible_utc_ms"]),
                         ("timer_due", self.epoch_ms("2000-01-01T00:00:00Z")))
        self.update_wait(blocker="o/r#5"); self.issue()
        self.assertEqual(self.run_command("tick").returncode, 0)
        self.assertEqual(self.fact("wake")["event_kind"], "blocker_closed")
        self.update_wait(blocker="o/r#5"); self.issue(state="open", closed_at=None)
        self.assertEqual(self.run_command("tick").returncode, 0)
        self.assertEqual(self.fact("wake")["event_kind"], "timer_due")

    def test_future_invalid_timer_and_dry_run_never_claim_delivery(self):
        self.make_wait()
        for value in ("2099-01-01T00:00:00Z", "not-a-date", "2026-02-30T00:00:00Z"):
            self.update_wait(until=value)
            self.assertEqual(self.run_command("tick").returncode, 0)
            row = self.fact("wake")
            self.assertEqual((row["event_kind"], row["delivery_boundary"]), ("unknown", "unknown"))
            self.assertIsNone(row["observed_utc_ms"])
        self.update_wait(until="2000-01-01T00:00:00Z")
        self.assertEqual(self.run_command("tick", "--dry-run").returncode, 0)
        self.assertIsNone(self.fact("wake")["delivered_utc_ms"])

    def test_failed_process_has_return_fact_but_refused_process_has_no_delivery(self):
        self.make_wait()
        self.environment["HARNESS_MODE"] = "fail"
        self.assertEqual(self.run_command("tick").returncode, 1)
        self.assertEqual(self.fact("wake")["delivery_boundary"], "wake_command_returned")
        self.update_wait(); self.environment["HARNESS_MODE"] = "active"
        self.assertEqual(self.run_command("tick").returncode, 0)
        row = self.fact("wake")
        self.assertEqual(row["delivery_boundary"], "unknown")
        self.assertIsNone(row["delivered_utc_ms"])
        result = report.summarize(self.state / "measurements")
        self.assertEqual(result["qualified_latency_ms"]["count"], 0)

    def test_snapshot_open_hit_keeps_empty_title_and_state_in_their_fields(self):
        self.make_wait(); self.update_wait(blocker="o/r#5", until="2099-01-01T00:00:00Z")
        self.config.update(repos=["o/r"], links_enabled=True)
        self.config.pop("propagate_on_host", None)
        self.snapshot([{"number": 5, "databaseId": 205, "title": "", "body": "", "blockedBy": {"nodes": []}}])
        self.assertEqual(self.run_command("tick").returncode, 0)
        self.assertEqual(self.active("wake")["outcome"], "skipped")
        self.assertIsNone(self.fact("wake")["observed_utc_ms"])
        calls = (self.root / "calls").read_text().splitlines()
        self.assertEqual(sum(line.startswith("api repos/o/r/issues/5 ") for line in calls), 0)

    def test_links_have_observation_and_ack_but_never_invent_eligibility(self):
        self.links()
        snapshot = json.loads((self.root / "snapshot.json").read_text())
        snapshot["data"]["repository"]["issues"]["nodes"][0]["updatedAt"] = "2000-01-01T00:00:00Z"
        (self.root / "snapshot.json").write_text(json.dumps(snapshot))
        self.assertEqual(self.run_command("links").returncode, 0)
        row = self.fact("links")
        self.assertEqual((row["event_kind"], row["delivery_boundary"]), ("unknown", "links_batch_acknowledged"))
        self.assertIsNone(row["eligible_utc_ms"])
        self.assertIsNotNone(row["observed_utc_ms"])
        self.assertGreaterEqual(row["delivered_utc_ms"], row["observed_utc_ms"])

    def test_partial_dry_and_idle_links_have_no_completed_batch_ack(self):
        self.links("7,8"); (self.root / "fail-second").touch()
        self.assertEqual(self.run_command("links").returncode, 1)
        self.assertIsNone(self.fact("links")["delivered_utc_ms"])
        (self.root / "fail-second").unlink()
        self.assertEqual(self.run_command("links", "--dry-run").returncode, 0)
        self.assertIsNone(self.fact("links")["delivered_utc_ms"])
        self.links(present=True)
        self.assertEqual(self.run_command("links").returncode, 0)
        self.assertIsNone(self.fact("links")["observed_utc_ms"])

    def test_alarm_uses_actual_activity_threshold_and_completed_final_ack(self):
        self.alarm()
        self.assertEqual(self.run_command("alarm").returncode, 0)
        row = self.fact("alarm")
        self.assertEqual(row["event_kind"], "alarm_stale")
        self.assertEqual(row["eligible_utc_ms"], self.epoch_ms("2000-01-02T00:00:00Z"))
        self.assertEqual(row["delivery_boundary"], "alarm_batch_acknowledged")
        self.assertGreaterEqual(row["delivered_utc_ms"], row["observed_utc_ms"])

    def two_alarm_targets(self, second_time):
        self.alarm()
        snapshot = json.loads((self.root / "snapshot.json").read_text())
        extra = copy.deepcopy(snapshot["data"]["repository"]["issues"]["nodes"][0]["blockedBy"]["nodes"][0])
        extra["number"] = 8
        snapshot["data"]["repository"]["issues"]["nodes"][0]["blockedBy"]["nodes"].append(extra)
        (self.root / "snapshot.json").write_text(json.dumps(snapshot))
        detail = copy.deepcopy(self.detail); detail["updatedAt"] = second_time
        (self.root / "detail-8.json").write_text(json.dumps({"data": {"rateLimit": self.cost(), "repository": {"issue": detail}}}))

    def test_multiple_alarm_times_require_every_raw_activity_to_be_known(self):
        self.two_alarm_targets("1999-01-01T00:00:00Z")
        self.assertEqual(self.run_command("alarm").returncode, 0)
        self.assertEqual(self.fact("alarm")["eligible_utc_ms"], self.epoch_ms("1999-01-02T00:00:00Z"))
        detail = copy.deepcopy(self.detail); detail["updatedAt"] = "0000-00-00T00:00:00Z"
        (self.root / "detail-8.json").write_text(json.dumps({"data": {"rateLimit": self.cost(), "repository": {"issue": detail}}}))
        self.assertEqual(self.run_command("alarm").returncode, 0)
        row = self.fact("alarm")
        self.assertEqual(row["event_kind"], "unknown")
        self.assertIsNone(row["eligible_utc_ms"])
        self.assertEqual(row["delivery_boundary"], "alarm_batch_acknowledged")
        self.assertIsNotNone(row["delivered_utc_ms"])

    def test_digest_only_partial_and_idle_alarm_never_claim_delivery(self):
        self.alarm()
        self.detail["comments"]["nodes"] = [{"body": "<!-- ai-blocker-watch:unowned:o/r#7 -->", "createdAt": "2000-01-02T00:00:00Z"}]
        self.write_detail()
        self.assertEqual(self.run_command("alarm").returncode, 0)
        self.assertIsNone(self.fact("alarm")["delivered_utc_ms"])
        self.detail["comments"]["nodes"] = []; self.write_detail()
        (self.root / "create-fail").touch()
        self.assertEqual(self.run_command("alarm").returncode, 1)
        row = self.fact("alarm")
        self.assertEqual((row["event_kind"], row["delivery_boundary"]), ("unknown", "unknown"))
        self.snapshot([])
        for path in (self.root / "watch").glob("digest-*"): path.unlink()
        self.assertEqual(self.run_command("alarm").returncode, 0)
        self.assertIsNone(self.fact("alarm")["observed_utc_ms"])

    def sample_fact(self):
        return dict(schema=4, utc="2026-11-01T12:00:00Z", measurement="workflow_evidence", caller="ai-blocker-watch",
                    workflow="blocker_watch_links", workflow_id="a" * 32, cohort_id=None, target_ordinal=None,
                    source_verified="unknown", source_fingerprint_start=None, source_fingerprint_end=None,
                    install_generation_binding=None, event_kind="unknown", eligible_utc_ms=None,
                    observed_utc_ms=1000, delivered_utc_ms=2000, delivery_boundary="links_batch_acknowledged",
                    clock_quality="unknown", clock_error_bound_ms=None, latency_ms=None, unknown_reason="source_unknown")

    def test_strict_shape_timestamp_authority_and_pr_confusion_rejection(self):
        row = self.sample_fact()
        self.assertTrue(report.unqualified_blocker_event(row))
        for name, value in (("workflow", []), ("event_kind", "pr_merged"), ("delivery_boundary", "terminal_report"),
                            ("eligible_utc_ms", "private-response"), ("observed_utc_ms", True),
                            ("delivered_utc_ms", -1), ("clock_quality", "verified_bound"),
                            ("source_verified", "verified"), ("cohort_id", "b" * 32),
                            ("latency_ms", 1000), ("private_response", "no")):
            changed = dict(row); changed[name] = value
            self.assertFalse(report.unqualified_blocker_event(changed), (name, value))
        self.assertFalse(report.unqualified_event(row))
        self.assertEqual(report.qualify_event(row, None, None, True)["unknown_reason"], "event_unknown")
        for changes in (dict(caller="ai-pr-wait"), dict(workflow="pr_wait"), dict(caller="ai-pr-wait", workflow="pr_wait")):
            self.assertFalse(report.unqualified_event(dict(row, **changes)))

    def test_report_duplicate_fields_and_outcome_confusion_fail_closed(self):
        directory = self.root / "report"
        directory.mkdir(); path = directory / "2026-11-01.jsonl"
        row = self.sample_fact()
        path.write_text(json.dumps(row) + "\n")
        result = report.summarize(directory)
        self.assertEqual(result["unqualified_blocker_events"][0]["outcome"], "unmatched_unknown")
        self.assertEqual(result["qualified_latency_ms"]["count"], 0)
        path.write_text(json.dumps(row).replace('"observed_utc_ms": 1000', '"observed_utc_ms": 9, "observed_utc_ms": 1000') + "\n")
        with self.assertRaises(ValueError): report.summarize(directory)
        path.write_text(json.dumps(row) + "\n" + json.dumps(row) + "\n")
        with self.assertRaises(ValueError): report.summarize(directory)
        receipt = ActiveReceipts.receipt(self, outcome="partial", attempted_count=2, succeeded_count=1, failed_count=1)
        path.write_text(json.dumps(row) + "\n" + json.dumps(receipt) + "\n")
        with self.assertRaises(ValueError): report.summarize(directory)

    def test_fact_emitter_is_durable_only_and_payload_is_private(self):
        script = 'source "$1"; shift; gh_measure_active_channel(){ printf visited > "$FIXTURE/channel-visited"; }; gh_measure_blocker_evidence "$@"'
        env = dict(self.environment, AI_GH_QUALIFICATION_EVENT_HANDLE="123", AI_GH_ACTIVE_EVENT_HANDLE="123")
        result = subprocess.run([bash_path(), "-c", script, "fixture", (ROOT / "tools/github-requests/telemetry.sh").as_posix(),
                                 "blocker_watch_links", "a" * 32, "unknown", "", "1000", "2000", "links_batch_acknowledged"],
                                env=env, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0)
        self.assertFalse((self.root / "channel-visited").exists())
        row = self.rows()[0]
        self.assertEqual(set(row), report.EVIDENCE_KEYS)
        self.assertTrue(report.unqualified_blocker_event(row))
        raw = json.dumps(row)
        for text in ("private-session-sentinel", "private-prompt-sentinel", self.root.as_posix()):
            self.assertNotIn(text, raw)


if __name__ == "__main__":
    unittest.main()
