# load-manifest.jq — validation and assembly for tools/ci-suites/load-manifest.
# Reads $e (per-suite entries: [{file, body}]) and $g ([global manifest]).
# Emits the legacy reader shape, or fails with `error(...)` naming the file.

# Canonical suite name: the file's basename without its .json suffix.
def suite_name($file):
  $file | sub("^.*/"; "") | sub("\\.json$"; "");

def fail($file; $msg): error("load-manifest: \($file): \($msg)");

# ---- validate the global manifest ----
(($g[0] // {}) | .windows_offline_section_count) as $ncount_raw
| (if $ncount_raw == null then 0 else $ncount_raw end) as $ncount
| (if ($ncount | type) != "number" or ($ncount != ($ncount | floor)) or $ncount < 0 then
    fail("global manifest"; "windows_offline_section_count must be a non-negative integer, got \($ncount_raw)")
  else . end)
| (if $ncount > 0 then
    ($g[0].windows_offline_powershell_shard // null) as $psh
    | (if $psh == null or ($psh | type) != "number" or $psh != ($psh | floor) or $psh < 1 or $psh > $ncount then
        fail("global manifest"; "windows_offline_powershell_shard must be an integer in 1..\($ncount)")
      else . end)
  else . end)

# ---- validate every per-suite file ----
| [ $e[] |
    .file as $file
    | suite_name($file) as $suite
    | .body as $b
    | (if ($b | type) != "object" then fail($file; "suite file must be a JSON object") else . end)
    | (if ($b.kind // null) == null then fail($file; "missing required key: kind")
       elif ($b.kind != "bash" and $b.kind != "powershell") then
         fail($file; "kind must be \"bash\" or \"powershell\", got \($b.kind | tojson)")
       else . end)
    | (if ($b.windows // []) | type != "array" then fail($file; "windows must be an array of tags") else . end)
    | ([$b.windows[]? | select(. != "offline" and . != "reviewer-safety")] as $bad
       | if ($bad | length) > 0 then fail($file; "unknown windows tag(s): \($bad | join(", "))") else . end)
    | (if (($b.windows // []) | length) != (($b.windows // []) | unique | length) then
        fail($file; "duplicate windows tag: \($b.windows | join(", "))")
      else . end)
    | (if (($b.windows // []) | index("reviewer-safety")) and (($b.windows // []) | index("offline") | not) then
        fail($file; "reviewer-safety membership requires offline membership")
      else . end)
    | (if ($b.linux_seconds // null) != null then
        (if $b.kind == "powershell" then fail($file; "linux_seconds is only valid for bash suites")
         elif ($b.linux_seconds | type) != "number" or $b.linux_seconds != ($b.linux_seconds | floor) or $b.linux_seconds < 0 then
           fail($file; "linux_seconds must be a non-negative integer, got \($b.linux_seconds | tojson)")
         else . end)
      else . end)
    | ($b.windows_section // null) as $sec
    | (if $sec != null then
        (if (($b.windows // []) | index("offline") | not) then
           fail($file; "windows_section requires offline membership")
         elif ($sec | type) != "number" or $sec != ($sec | floor) or $sec < 1 or $sec > $ncount then
           fail($file; "windows_section must be an integer in 1..\($ncount), got \($sec | tojson)")
         else . end)
      elif (($b.windows // []) | index("offline")) and (($b.windows // []) | index("reviewer-safety") | not) then
        fail($file; "an offline suite in no hosted section would run nowhere: add windows_section or reviewer-safety")
      else . end)
    | {file: $file, suite: $suite, kind: $b.kind,
       linux_seconds: ($b.linux_seconds // null),
       windows: ($b.windows // []),
       windows_section: ($b.windows_section // null)}
  ] as $suites

# ---- assembled-list invariants ----
| (if ($suites | map(.suite) | length) != ($suites | map(.suite) | unique | length) then
    error("load-manifest: a suite is declared by more than one file")
  else . end)
| (if $ncount > 0 then
    ($g[0].windows_offline_powershell_shard // 0) as $psh
    | [ range(1; $ncount + 1) as $i
      | select($i != $psh)
      | select([$suites[] | select(.windows_section == $i)] | length == 0)
      | "section \($i)" ] as $empty
    | if ($empty | length) > 0 then
        error("load-manifest: every declared section must carry work; empty: \($empty | join(", "))")
      else . end
  else . end)

# ---- assemble the legacy reader shape ----
| {
    schema_version: 2,
    linux_offline_suite_seconds: ([$suites[] | select(.kind == "bash" and .linux_seconds != null) | {(.suite): .linux_seconds}] | add // {}),
    bash: [$suites[] | select(.kind == "bash") | .suite] | sort,
    powershell: [$suites[] | select(.kind == "powershell") | .suite] | sort,
    windows_sensitive_bash: [$suites[] | select(.windows | index("offline")) | .suite] | sort,
    windows_reviewer_safety_bash: [$suites[] | select(.windows | index("reviewer-safety")) | .suite] | sort,
    windows_offline_bash: [$suites[] | select(.windows | index("offline")) | .suite] | sort,
    windows_offline_shards: [ range(1; $ncount + 1) as $i
                              | [$suites[] | select(.windows_section == $i) | .suite] | sort ]
  }
+ ($g[0] | {
    windows_offline_powershell_shard,
    suspended_bash, suspended_powershell, _comment_suspended, affected_suite_rules
  } | with_entries(select(.value != null)))
