#!/usr/bin/env python3
"""Build paired Linux prototypes from verified official archives; no install."""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import tarfile
import tempfile

HERE = pathlib.Path(__file__).resolve().parent


def verify(path, expected):
    if path.is_symlink() or not path.is_file():
        raise ValueError("invalid archive")
    with path.open("rb") as stream:
        actual = hashlib.file_digest(stream, "sha256").hexdigest()
    if actual != expected:
        raise ValueError("archive checksum mismatch")


def patch(source):
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
    shutil.copyfile(HERE / "httpcounter.go", counter / "httpcounter.go")
    shutil.copyfile(HERE / "httpcounter_test.go", counter / "httpcounter_test.go")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--archives", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    if os.name != "posix" or os.uname().sysname != "Linux":
        raise ValueError("Linux prototype only")
    pins = json.loads((HERE / "pins.json").read_text())
    source_tar, go_tar = args.archives / "gh.tar.gz", args.archives / "go.tar.gz"
    verify(source_tar, pins["source_sha256"])
    verify(go_tar, pins["toolchain_sha256"])
    args.output.mkdir(mode=0o700, parents=True, exist_ok=True)
    if args.output.is_symlink() or args.output.stat().st_uid != os.getuid() or args.output.stat().st_mode & 0o077:
        raise ValueError("private output directory required")
    build_root = pathlib.Path(tempfile.mkdtemp(prefix="build-", dir=args.output))
    toolchain = build_root / "toolchain"
    toolchain.mkdir()
    with tarfile.open(go_tar) as archive:
        archive.extractall(toolchain, filter="data")
    go = toolchain / "go/bin/go"
    env = {key: value for key, value in os.environ.items()
           if key in {"PATH", "HOME", "TMPDIR", "SSL_CERT_FILE", "SSL_CERT_DIR"}}
    env.update(GOTOOLCHAIN="local", CGO_ENABLED="0", GOMODCACHE=str(build_root / "modules"),
               GOCACHE=str(build_root / "gocache"), GOOS="linux", GOARCH="amd64")
    artifacts = {}
    for kind in ("baseline", "instrumented"):
        extracted = build_root / kind
        extracted.mkdir()
        with tarfile.open(source_tar) as archive:
            archive.extractall(extracted, filter="data")
        source = extracted / ("cli-" + pins["upstream_commit"])
        if kind == "instrumented":
            patch(source)
            subprocess.run([str(toolchain / "go/bin/gofmt"), "-w", "api/http_client.go", "cmd/gh/main.go", "internal/httpcounter/httpcounter.go", "internal/httpcounter/httpcounter_test.go"], cwd=source, env=env, check=True)
            race_env = dict(env, CGO_ENABLED="1")
            subprocess.run([str(go), "test", "-race", "./internal/httpcounter"], cwd=source, env=race_env, check=True)
        output = build_root / ("gh-" + kind)
        subprocess.run([str(go), "build", "-trimpath", "-ldflags", "-X github.com/cli/cli/v2/internal/build.Version=" + pins["upstream_version"], "-o", str(output), "./cmd/gh"], cwd=source, env=env, check=True)
        artifacts[kind] = {"path": str(output), "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}
    manifest = {"pins": pins, "artifacts": artifacts, "toolchain": str(go), "build_root": str(build_root),
                "patch_sha256": hashlib.sha256((HERE / "httpcounter.go").read_bytes()).hexdigest(), "installed": False}
    manifest_path = args.output / "build.json"
    descriptor = os.open(manifest_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w") as stream:
        json.dump(manifest, stream, indent=2)
    print("paired Linux build complete; no installation")


if __name__ == "__main__":
    main()
