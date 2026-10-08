#!/usr/bin/env python3
"""Build paired Linux prototypes from verified official archives; no install."""
import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import tarfile
import tempfile
from contextlib import ExitStack
from sealed import verified_snapshot, private_directory
from source_binding import FILES, source_binding

HERE = pathlib.Path(__file__).resolve().parent


def build_environment(build_root, toolchain):
    env = {key: value for key, value in os.environ.items()
           if key in {"SSL_CERT_FILE", "SSL_CERT_DIR"}}
    home = build_root / "home"
    home.mkdir()
    env.update(PATH="/usr/bin:/bin", HOME=str(home), TMPDIR=str(build_root), GOENV="off",
               GOROOT=str(toolchain / "go"), GOTOOLCHAIN="local", CGO_ENABLED="0",
               GOMODCACHE=str(build_root / "modules"), GOCACHE=str(build_root / "gocache"),
               GOOS="linux", GOARCH="amd64")
    return env


def patch(source, package_bytes=None):
    path = source / "api/http_client.go"
    text = path.read_text()
    if text.count("\treturn client, nil\n") != 2:
        raise ValueError("upstream patch boundary changed")
    text = text.replace('"github.com/cli/cli/v2/internal/gh/ghtelemetry"',
                        '"github.com/cli/cli/v2/internal/gh/ghtelemetry"\n'
                        '\t"github.com/cli/cli/v2/internal/httpcounter"')
    text = text.replace("\treturn client, nil\n", "\tclient.Transport = httpcounter.Wrap(client.Transport)\n\treturn client, nil\n")
    path.write_text(text)
    path = source / "cmd/gh/main.go"
    text = path.read_text()
    text = text.replace('"github.com/cli/cli/v2/internal/ghcmd"',
                        '"github.com/cli/cli/v2/internal/ghcmd"\n\t"github.com/cli/cli/v2/internal/httpcounter"')
    if text.count("\tcode := ghcmd.Main()\n") != 1:
        raise ValueError("upstream finalize boundary changed")
    path.write_text(text.replace("\tcode := ghcmd.Main()\n", "\tcode := ghcmd.Main()\n\thttpcounter.Finish()\n"))
    counter = source / "internal/httpcounter"
    counter.mkdir()
    for name in FILES:
        (counter / name).write_bytes(package_bytes[name] if package_bytes is not None else (HERE / name).read_bytes())


def main():
    with ExitStack() as snapshots:
        build(snapshots)


def build(snapshots):
    parser = argparse.ArgumentParser()
    parser.add_argument("--archives", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--target", choices=("linux-amd64", "windows-amd64"), default="linux-amd64")
    parser.add_argument("--compile-native-fixture", action="store_true")
    parser.add_argument("--qualify-updater", action="store_true",
                        help="local fixture variant using upstream updateable build tag")
    args = parser.parse_args()
    if args.compile_native_fixture and args.target != "windows-amd64":
        raise ValueError("native fixture requires Windows target")
    binding = source_binding(HERE)
    package_bytes = {name: (HERE / name).read_bytes() for name in FILES}
    if binding["files"] != {name: hashlib.sha256(value).hexdigest() for name, value in package_bytes.items()}:
        raise ValueError("counter source changed while capturing inputs")
    if os.name != "posix" or os.uname().sysname != "Linux":
        raise ValueError("Linux prototype only")
    pins = json.loads((HERE / "pins.json").read_text())
    source_tar, go_tar = args.archives / "gh.tar.gz", args.archives / "go.tar.gz"
    source_snapshot = snapshots.enter_context(verified_snapshot(source_tar, pins["source_sha256"]))
    go_snapshot = snapshots.enter_context(verified_snapshot(go_tar, pins["toolchain_sha256"]))
    # The caller creates its output directory. Never traverse an unvalidated
    # writable parent to create it, and retain its inode throughout the build.
    output_fd = private_directory(args.output)
    snapshots.callback(os.close, output_fd)
    anchored_output = pathlib.Path(f"/proc/{os.getpid()}/fd/{output_fd}")
    build_root = pathlib.Path(tempfile.mkdtemp(prefix="build-", dir=anchored_output))
    toolchain = build_root / "toolchain"
    toolchain.mkdir()
    with tarfile.open(fileobj=go_snapshot) as archive:
        archive.extractall(toolchain, filter="data")
    go = toolchain / "go/bin/go"
    env = build_environment(build_root, toolchain)
    env["GOOS"] = args.target.split("-")[0]
    artifacts = {}
    for kind in ("baseline", "instrumented"):
        extracted = build_root / kind
        extracted.mkdir()
        source_snapshot.seek(0)
        with tarfile.open(fileobj=source_snapshot) as archive:
            archive.extractall(extracted, filter="data")
        source = extracted / ("cli-" + pins["upstream_commit"])
        if kind == "instrumented":
            patch(source, package_bytes)
            subprocess.run([str(toolchain / "go/bin/gofmt"), "-w", "api/http_client.go", "cmd/gh/main.go", *["internal/httpcounter/" + name for name in FILES if name.endswith(".go")]], cwd=source, env=env, check=True)
            compiled_binding = source_binding(source / "internal/httpcounter")
            race_env = dict(env, CGO_ENABLED="1", GOOS="linux")
            subprocess.run([str(go), "test", "-race", "./internal/httpcounter"], cwd=source, env=race_env, check=True)
        output = build_root / ("gh-" + kind + (".exe" if env["GOOS"] == "windows" else ""))
        tags = ["-tags", "updateable"] if args.qualify_updater else []
        flags = "-X github.com/cli/cli/v2/internal/build.Version=" + pins["upstream_version"]
        if env["GOOS"] == "windows":
            flags += " -s -w -X github.com/cli/cli/v2/internal/build.Date=2026-10-07"
        subprocess.run([str(go), "build", *tags, "-trimpath", "-ldflags", flags, "-o", str(output), "./cmd/gh"], cwd=source, env=env, check=True)
        artifacts[kind] = {"path": str(args.output.absolute() / build_root.name / output.name), "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}
        if kind == "instrumented" and args.compile_native_fixture:
            fixture = build_root / "httpcounter-windows-fixture.exe"
            subprocess.run([str(go), "test", "-c", "-trimpath", "-o", str(fixture), "./internal/httpcounter"], cwd=source, env=env, check=True)
            artifacts["native_fixture"] = {"path": str(args.output.absolute() / build_root.name / fixture.name), "sha256": hashlib.sha256(fixture.read_bytes()).hexdigest()}
    durable_root = args.output.absolute() / build_root.name
    manifest = {"pins": pins, "artifacts": artifacts, "toolchain": str(durable_root / "toolchain/go/bin/go"), "build_root": str(durable_root),
                "patch_sha256": binding["files"]["httpcounter.go"], "installed": False,
                "counter_source_binding": binding, "compiled_counter_source_binding": compiled_binding, "target": args.target,
                "qualification_build_tags": ["updateable"] if args.qualify_updater else []}
    manifest_path = anchored_output / "build.json"
    descriptor = os.open(manifest_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as stream:
        json.dump(manifest, stream, indent=2)
    print("paired qualification build complete; no installation")


if __name__ == "__main__":
    main()
