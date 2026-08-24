# Step 7 full archive rollback proof

Date: 2026-08-24 02:26:52 UTC

An isolated WSL Ubuntu fixture installed managed configuration, repository
state, and command symlinks, created the full uninstall archive, changed the
live state, and restored from that archive. The verification compared the
restored state to the pre-uninstall hashes rather than relying only on command
exit codes.

Result: PASS.

```text
PASS full archive rollback restored config_hash=bbe67759527a31d945df91975bf569554902b1eefafeb8c78decb985fec064b3 repo_commit=11730cd3a4c463be00354409103437294ba362a5 symlink_hash=478384049e2860a12177e9772ae330541d2431cd79350d9b6ec7b3311924fe15
```

This proves the Step 7 gate that archive-based rollback restores all managed
state represented by the fixture: configuration bytes, exact repository
revision, and installed symlink targets.
