"""Native Windows supervisor integration; no network requests or machine changes."""
import hashlib
import json
import base64
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import shutil


def cleanup_interpreters():
    if sys.platform == "win32":
        return [path for path in [Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe",
                                  Path(os.environ["ProgramFiles"]) / "PowerShell/7/pwsh.exe"] if path.is_file()]
    found = shutil.which("pwsh")
    return [Path(found)] if found else []


@unittest.skipUnless(cleanup_interpreters(), "native PowerShell runtime required")
class OwnedCleanup(unittest.TestCase):
    def test_actual_finalizer_preserves_primary_and_attempts_later_resources(self):
        source = str(Path(__file__).parents[1] / "tools/github-requests/source_generation_windows.ps1").replace("'", "''")
        # Execute the actual production catch/finally/tail, replacing only work
        # and owned resources with in-memory fault fixtures. No ACLs or files.
        template = r'''
$ErrorActionPreference='Stop'
class GenerationCustody {
 static [void] FileAccess([object]$resource,[bool]$writable){$resource.Unseal()}
}
$text=[IO.File]::ReadAllText('__SOURCE__');$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw 'Production parser error'}
foreach($name in @('Invoke-OwnedCleanupStep','Close-OwnedGeneration')){
 $f=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name},$true)
 . ([scriptblock]::Create($f.Extent.Text))
}
$main=$ast.Find({param($n)$n -is [Management.Automation.Language.TryStatementAst] -and $n.Finally -and $n.Finally.Extent.Text.Contains('$cleanupErrors=Close-OwnedGeneration')},$true)
if(-not $main){throw 'Production finalizer missing'}
$global:closed=[Collections.Generic.List[string]]::new()
function Fake-Resource([string]$name,[bool]$fail){
 $r=[pscustomobject]@{name=$name;fail=$fail;HasExited=$true}
 $r|Add-Member ScriptMethod Dispose {$global:closed.Add($this.name);if($this.fail){throw ('dispose-failure-'+$this.name)}}
 return $r
}
$job=Fake-Resource 'job' $false;$child=Fake-Resource 'child' $false
$eventChannel=Fake-Resource 'event' $false;$counterChannel=Fake-Resource 'counter' $false
$captureLocks=@((Fake-Resource 'capture-first' __FAULT__),(Fake-Resource 'capture-last' $false))
$directoryControls=@();$locks=@((Fake-Resource 'lock-first' $false),(Fake-Resource 'lock-last' $false))
$fileControls=@((Fake-Resource 'file-first' $false),(Fake-Resource 'file-last' $false))
foreach($file in $fileControls){
 $file|Add-Member NoteProperty failUnseal (__FAULT__ -and $file.name -eq 'file-first')
 $file|Add-Member ScriptMethod Unseal {$global:closed.Add('unseal-'+$this.name);if($this.failUnseal){throw ('unseal-failure-'+$this.name)}}
}
$receipt=Fake-Resource 'receipt' $false;$ack=Fake-Resource 'ack' $false
$snapshot=$null;$bootstrap=$null;$exitCode=__EXIT__;$primaryFailure=$null;$cancelled=$false
$catches=($main.CatchClauses|ForEach-Object{$_.Extent.Text}) -join "`n"
$execution='try { __WORK__ } '+$catches+' finally '+$main.Finally.Extent.Text+"`n"+$text.Substring($main.Extent.EndOffset)
try{& ([scriptblock]::Create($execution))}finally{
 [Console]::Out.WriteLine('CLEANUP_FIXTURE='+(@{closed=@($global:closed);primary=$(if($primaryFailure){$primaryFailure.Exception.Message}else{$null});exit_code=$exitCode}|ConvertTo-Json -Compress))
}
'''.replace("__SOURCE__", source)
        cases = [(True, True, 0, 1), (False, True, 0, 125), (False, False, 0, 0), (False, False, 17, 17)]
        for interpreter in cleanup_interpreters():
            for primary, fault, original, expected in cases:
                with self.subTest(interpreter=interpreter.name, primary=primary, fault=fault, original=original):
                    script = template.replace("__FAULT__", "$true" if fault else "$false").replace("__EXIT__", str(original))
                    script = script.replace("__WORK__", 'throw "primary-work-failure"' if primary else "$null=$null")
                    encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
                    result = subprocess.run([str(interpreter), "-NoProfile", "-EncodedCommand", encoded], capture_output=True, timeout=30)
                    self.assertEqual(result.returncode, expected, result.stderr.decode(errors="replace"))
                    rows = [line for line in result.stdout.decode(errors="replace").splitlines() if line.startswith("CLEANUP_FIXTURE=")]
                    self.assertEqual(len(rows), 1, result.stderr.decode(errors="replace"))
                    row = json.loads(rows[0].split("=", 1)[1])
                    self.assertEqual(row["closed"], ["job", "child", "event", "counter", "capture-first", "capture-last",
                                                      "unseal-file-first", "unseal-file-last", "file-first", "file-last",
                                                      "lock-last", "lock-first", "receipt", "ack"])
                    if primary:
                        self.assertIn(b"primary-work-failure", result.stderr)
                    if fault:
                        self.assertIn(b"dispose-failure-capture-first", result.stderr)
                        self.assertIn(b"unseal-failure-file-first", result.stderr)


@unittest.skipUnless(cleanup_interpreters(), "native PowerShell runtime required")
class EffectiveConfiguration(unittest.TestCase):
    def test_existing_ssh_namespace_and_sdk_fallback_without_loader_execution(self):
        source = str(Path(__file__).parents[1] / "tools/github-requests/source_generation_windows.ps1").replace("'", "''")
        cases = [
            dict(env=dict(GH_CONFIG_DIR="C:/explicit-context", SSH_CONNECTION="owned"), probe="C:/wrong", suffix="/explicit-context", calls=0),
            dict(env=dict(SSH_CONNECTION="owned", USERPROFILE="C:/profile", HOME="C:/parent-home"), probe="C:/actual-bash-home/.ai-devops/gh-ssh", suffix="/actual-bash-home/.ai-devops/gh-ssh", calls=1),
            dict(env=dict(XDG_CONFIG_HOME="C:/xdg", USERPROFILE="C:/profile"), probe="C:/private", suffix="/xdg/gh", calls=0),
            dict(env=dict(SSH_CONNECTION="owned", APPDATA="C:/roaming", USERPROFILE="C:/profile"), probe="", suffix="/roaming/GitHub CLI", calls=1),
            dict(env=dict(SSH_CONNECTION="owned", USERPROFILE="C:/profile"), probe="", suffix="/profile/.config/gh", calls=1),
            dict(env=dict(APPDATA="C:/roaming", USERPROFILE="C:/profile"), probe="C:/private", suffix="/roaming/GitHub CLI", calls=0),
            dict(env=dict(SSH_CONNECTION="owned"), probe="C:/private", error=True, bound=False, calls=0),
        ]
        for key in ("BASH_ENV", "ENV", "BASH_FUNC_hostile%%", "SHELLOPTS", "PS4", "PYTHONPATH"):
            cases.append(dict(env={"SSH_CONNECTION": "owned", key: "hostile-loader"}, probe="C:/private", error=True, calls=0))
        payload = base64.b64encode(json.dumps(cases).encode()).decode()
        script = r'''
$ErrorActionPreference='Stop'
$text=[IO.File]::ReadAllText('__SOURCE__');$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Production syntax invalid'}
foreach($name in @('Config-Directory','Assert-BashStartupEnvironment')){
 $f=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq $name},$true)
 . ([scriptblock]::Create($f.Extent.Text))
}
function Local-OnlyProbe([string]$exe,[string[]]$values){
 $script:calls++;if($exe -cne 'identity-bound-bash'){throw 'Unbound interpreter'}
 if($values.Count -ne 4 -or $values[0] -cne '--noprofile' -or $values[1] -cne '--norc' -or $values[2] -cne '-c' -or $values[3] -notmatch 'builtin pwd -W'){throw 'Unexpected helper invocation'}
 return $script:probe
}
$cases=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__CASES__'))|ConvertFrom-Json
$keys=@('GH_CONFIG_DIR','SSH_CONNECTION','XDG_CONFIG_HOME','APPDATA','USERPROFILE','HOME','BASH_ENV','ENV','SHELLOPTS','BASHOPTS','PS4','PROMPT_COMMAND','PYTHONPATH','PYTHONHOME','PYTHONSTARTUP','BASH_FUNC_hostile%%')
$rows=@()
foreach($case in $cases){
 foreach($key in $keys){[Environment]::SetEnvironmentVariable($key,$null,'Process')}
 foreach($property in $case.env.PSObject.Properties){[Environment]::SetEnvironmentVariable($property.Name,[string]$property.Value,'Process')}
 $script:installedBash=if($case.bound -ceq $false){$null}else{'identity-bound-bash'};$script:calls=0;$script:probe=$case.probe;$failure=$false;$value=$null
 try{$value=Config-Directory}catch{$failure=$true}
 $rows+=@{calls=$script:calls;failed=$failure;value=$value}
}
@{rows=$rows}|ConvertTo-Json -Depth 5 -Compress
'''.replace("__SOURCE__", source).replace("__CASES__", payload)
        for interpreter in cleanup_interpreters():
            with self.subTest(interpreter=interpreter.name):
                encoded = base64.b64encode(script.encode("utf-16le")).decode()
                result = subprocess.run([str(interpreter), "-NoProfile", "-EncodedCommand", encoded], capture_output=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
                rows = json.loads(result.stdout)["rows"]
                for case, row in zip(cases, rows, strict=True):
                    self.assertEqual(row["calls"], case["calls"])
                    self.assertEqual(row["failed"], case.get("error", False))
                    if not row["failed"]:
                        self.assertTrue(row["value"].replace("\\", "/").endswith(case["suffix"]))


@unittest.skipUnless(sys.platform == "win32" and os.environ.get("RUN_MANAGED_WINDOWS_SOURCE_INTEGRATION") == "1",
                     "explicit managed native Windows integration required")
class WindowsGeneration(unittest.TestCase):
    def test_installed_generation_custody_and_original_exit(self):
        import msvcrt

        supervisor = Path(os.environ.get("GENERATION_SUPERVISOR", Path(__file__).parents[1] / "tools/github-requests/source_generation_windows.ps1"))
        root = Path(os.environ.get("GENERATION_INSTALLED_ROOT", "C:/repos/ai-devops"))
        for arguments, expected_exit, restricted in [(["--help"], 0, False), (["not-a-pr"], 3, False), (["--help"], 0, True)]:
            with self.subTest(arguments=arguments), tempfile.TemporaryDirectory(prefix="ai-generation-parent-") as temporary:
                argument_payload = base64.b64encode(json.dumps(arguments).encode("utf-8")).decode("ascii")
                read_fd, write_fd = os.pipe()
                ack_read, ack_write = os.pipe()
                write_handle = msvcrt.get_osfhandle(write_fd)
                ack_handle = msvcrt.get_osfhandle(ack_read)
                os.set_handle_inheritable(write_handle, True)
                os.set_handle_inheritable(ack_handle, True)
                startup = subprocess.STARTUPINFO()
                startup.lpAttributeList = {"handle_list": [write_handle, ack_handle]}
                environment = os.environ.copy()
                environment["AI_GH_SOURCE_VERIFIED"] = "forged"
                environment["AI_GH_SOURCE_SHA"] = "0" * 40
                snapshot_parents = [Path(os.environ["LOCALAPPDATA"]) / "Temp", Path(os.environ["ProgramFiles"])]
                before = {path for parent in snapshot_parents for path in parent.glob("ai-gh-generation-*")}
                command = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(supervisor), "-SourceRoot", str(root),
                     "-EntryPoint", "bin/ai-pr-wait", "-ArgumentsBase64", argument_payload,
                     "-ReceiptHandle", str(write_handle), "-ReceiptAckHandle", str(ack_handle)]
                if restricted:
                    command.append("-RestrictedReadProfile")
                child = subprocess.Popen(
                    command,
                    startupinfo=startup, close_fds=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    cwd=temporary, env=environment,
                )
                os.close(write_fd)
                os.close(ack_read)
                try:
                    with os.fdopen(read_fd, "rb") as stream:
                        # The supervisor's ACK deadline bounds abandoned receipt custody.
                        line = stream.readline(65537)
                    if not line:
                        stdout, stderr = child.communicate(timeout=10)
                        self.fail("supervisor did not produce a live source receipt: " + stderr.decode(errors="replace"))
                    self.assertLessEqual(len(line), 65536)
                    record = json.loads(line)
                    self.assertIn(record["source_verified"], ["verified", "unknown"])
                    if restricted:
                        self.assertEqual(record["source_verified"], "verified")
                    elif record["source_verified"] == "unknown":
                        self.assertEqual(record["boundary_detail"], "privileged_original_context")
                    self.assertNotEqual(record["source_sha"], "0" * 40)
                    if record["child_exit"] != expected_exit:
                        os.write(ack_write, b"\x01")
                        stdout, stderr = child.communicate(timeout=40)
                        self.fail(f"child exit {record['child_exit']} != {expected_exit}: {stderr.decode(errors='replace')}")
                    self.assertEqual(record["source_boundary"], "windows_locked_generation")
                    self.assertIsNone(record["clock_error_bound_ms"])
                    launcher = Path.home() / ".local/bin/ai-task-gates.cmd"
                    self.assertEqual(record["install_generation_binding"], hashlib.sha256(launcher.read_bytes()).hexdigest())
                    snapshots = {path for parent in snapshot_parents for path in parent.glob("ai-gh-generation-*")} - before
                    self.assertEqual(len(snapshots), 1)
                    snapshot = snapshots.pop()
                    sealed = snapshot / "bin/ai-pr-wait"
                    with self.assertRaises(OSError):
                        sealed.open("r+b")
                    with self.assertRaises(OSError):
                        snapshot.rename(snapshot.with_name(snapshot.name + "-replaced"))
                    # No canonical source byte is modified; only prove write access remains.
                    with (root / "bin/ai-pr-wait").open("r+b"):
                        pass
                    self.assertIsNone(child.poll(), "custody ended before parent receipt consumption")
                    os.write(ack_write, b"\x01")
                    stdout, stderr = child.communicate(timeout=40)
                    self.assertEqual(child.returncode, expected_exit, stderr.decode(errors="replace"))
                    if expected_exit == 0:
                        self.assertIn(b"ai-pr-wait", stdout)
                    else:
                        self.assertIn(b"give a pull request number", stderr)
                    self.assertFalse(snapshot.exists())
                finally:
                    os.close(ack_write)
                    if child.poll() is None:
                        try:
                            child.communicate(timeout=10)
                        except subprocess.TimeoutExpired:
                            child.kill()
                            child.communicate(timeout=10)


if __name__ == "__main__":
    unittest.main()
