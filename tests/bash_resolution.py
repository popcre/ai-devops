"""Resolve a usable bash for tests on every platform.

On Windows, ``shutil.which("bash")`` may return the WindowsApps WSL stub or
the ``Git\\bin\\bash.exe`` wrapper that bootstraps ``/mingw64/bin:/usr/bin``
ahead of the inherited PATH.  Tests that shadow tools on PATH (e.g. a fake
``cygpath``) need the raw MSYS bash at ``Git\\usr\\bin\\bash.exe`` which
preserves inherited PATH order.  Set ``AI_TEST_BASH`` to override.

Returns ``(bash_path, msys_bin_dir)`` where *msys_bin_dir* is the directory
containing coreutils (``readlink``, ``dirname``, ...) that must appear on
PATH **after** any test shadow directory.  On non-Windows it is ``None``.
"""

import os
import shutil
import sys
from pathlib import Path


def resolve_bash():
    """Return ``(bash_path, msys_bin_dir_or_None)``."""
    override = os.environ.get("AI_TEST_BASH")
    if override:
        return override, None
    if sys.platform == "win32":
        git = shutil.which("git")
        if git:
            git_root = Path(git).parents[1]
            candidate = git_root / "usr" / "bin" / "bash.exe"
            if candidate.exists():
                return str(candidate), str(git_root / "usr" / "bin")
    return shutil.which("bash"), None
