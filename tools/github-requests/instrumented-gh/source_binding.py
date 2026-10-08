"""Finite package closure; reject additions as well as omissions and mutations."""
import hashlib
import pathlib

FILES = ("httpcounter.go", "httpcounter_test.go", "channel.go", "channel_linux.go",
         "channel_windows.go", "channel_unsupported.go", "channel_windows_test.go",
         "windows_cli_fixture_test.go", "native_fixture.ps1")


def source_binding(directory):
    directory = pathlib.Path(directory)
    actual = {item.name for pattern in ("*.go", "*.ps1") for item in directory.glob(pattern)}
    if actual != set(FILES):
        raise ValueError("counter source closure mismatch")
    return {"schema": 1, "files": {
        name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
        for name in FILES}}


def validate_source_binding(binding, directory):
    if (type(binding) is not dict or set(binding) != {"schema", "files"}
            or type(binding["schema"]) is not int or binding["schema"] != 1
            or type(binding["files"]) is not dict or binding != source_binding(directory)):
        raise ValueError("counter source binding mismatch")
