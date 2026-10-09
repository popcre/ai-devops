# Issue #1547 — elevated SSH tokens across the Windows pool (read-only probe record)

Probes re-run 2026-10-09, window 21:32–21:36 UTC (5:32–5:36 PM EDT).

## Purpose

This record captures fresh read-only probe evidence for the root-cause diagnosis of
[popcre/ai-devops#1547](https://github.com/popcre/ai-devops/issues/1547) — SSH sessions on the
Windows runners receiving a full elevated administrator token instead of a UAC-filtered token.
It supports the diagnosis comment:
https://github.com/popcre/ai-devops/issues/1547#issuecomment-6088987231
All five pool hosts were probed again on 2026-10-09 to confirm the earlier 2026-10-09 diagnosis
findings had not drifted.

## Method

Every probe ran over SSH using `Get-Content -Raw '<script>.ps1' | ssh <alias> "powershell -NoProfile -Command -"`,
i.e. the script text was piped to the remote PowerShell's stdin. Nothing was written, created,
or changed on any host; probes only read the registry, file metadata, token information, WMI/CIM
instances, and ran `whoami`/`query user`.

Elevation state was measured with `GetTokenInformation` P/Invoke calls against the current SSH
session's token: `TokenElevationType` (class 18: 1=Default/no-split, 2=Full, 3=Limited),
`TokenIsElevated` (class 20), and `TokenLinkedToken` (class 19). Group membership and integrity
level came from `whoami /groups`; enabled privileges from `whoami /priv`. The logon type was
established by taking the token's authentication LUID (`TokenStatistics`, class 10) and matching
it against `Win32_LogonSession` entries (and, in `envy-probe.ps1`, an attempted
`LsaGetLogonSessionData` call). The interactive baseline used the same elevation queries against
the logged-in `explorer.exe` process token.

Scripts in this directory:

| File | Purpose |
|---|---|
| `envy-probe.ps1` | Identity, elevation type, linked token, whoami groups/privileges, UAC registry knobs, OS facts, sshd provenance, hotfixes, sessions |
| `envy-probe2.ps1` | Current-process auth LUID + LSA/CIM logon-session type dump, sshd file timestamps, sshd service state |
| `explorer-probe.ps1` | Interactive explorer token elevation/type, OS build, UTC time |
| `lsa-probe.ps1` | lsasrv/samsrv/samlib/msv1_0/kerberos/wdigest/tspkg/cryptdll/netlogon file versions and timestamps |
| `sshd-binary-check.ps1` | sshd.exe sizes/versions/MD5 for three builds + ASCII/UTF-16 string-set comparison and byte-diff ranges between the Sep-3-era and active binaries (run on envy only) |

Redaction note: in the envy `SSHD_CONFIG_LINES` output below, the values of the two `ListenAddress`
lines were replaced with `<redacted>` because they are private network/tailnet addresses;
everything else is verbatim.

Scope note: the host identifiers recorded here (account names, SIDs, builds, hotfix
dates, session lines) match the class of data this repository's verification records
already carry publicly — the step-7 install proof
(`tests/verification/windows-runner-maintenance-envy-2026-10-09/README.md`) pins the
operator SID in full, and `IML\ahazan2` appears in `docs/windows-openssh-tailscale.md`
and `plan_phase3-config-consolidation.md`. They are host-identity facts, not secrets;
they grant no access, and keeping them verbatim makes this record re-pinnable under
plan §11. No passwords, keys, or key-file contents appear anywhere below.

## Results

### envy-probe.ps1 — five hosts

Run matrix: `envy-probe.ps1` → envy, edge-dev, alien, 916, 4837. All five runs succeeded.

Note: `LOGON_TYPE=lsa-rc=-1` in this probe means the in-probe `LsaGetLogonSessionData` call
returned failure under this execution path; the logon type was instead proven by
`envy-probe2.ps1` (below) by matching the auth LUID to the CIM logon session.

#### envy

```text
USER=edge-runn-envy\ahazan
USER_SID=S-1-5-21-4110623484-3775389421-3704134857-1001
AUTH_PACKAGE_IDENTITY=NTLM
IS_IN_ADMINISTRATORS_ROLE=True
TOKEN_ELEVATION_TYPE=1 (Default(no-split))
TOKEN_IS_ELEVATED=1
LINKED_TOKEN=absent (GetLastError=24)
AUTH_LUID=0:4dffa63
LOGON_TYPE=lsa-rc=-1
WHOAMI_GROUP=BUILTIN\Administrators Alias S-1-5-32-544 Mandatory group, Enabled by default, Enabled group, Group owner
WHOAMI_GROUP=Mandatory Label\High Mandatory Level Label S-1-16-12288
PRIV_ENABLED_COUNT=24
PRIV_SAMPLE=SeTakeOwnershipPrivilege Take ownership of files or other objects Enabled
PRIV_SAMPLE=SeBackupPrivilege Back up files and directories Enabled
PRIV_SAMPLE=SeShutdownPrivilege Shut down the system Enabled
PRIV_SAMPLE=SeDebugPrivilege Debug programs Enabled
POL_EnableLUA=1
POL_ConsentPromptBehaviorAdmin=5
POL_PromptOnSecureDesktop=1
POL_FilterAdministratorToken=ABSENT
POL_LocalAccountTokenFilterPolicy=ABSENT
POL_ValidateAdminCodeSignatures=0
POL_EnableSecureUIAPaths=1
POL2_LocalAccountTokenFilterPolicy=ABSENT
OS_PRODUCT=Windows 10 Pro
OS_DISPLAY=26H2
OS_BUILDTAG=26300.9457
OS_INSTALLDATE=2026-09-01 17:07Z
OS_CAPTION=Microsoft Windows 11 Pro
LAST_BOOT=2026-10-09 19:36Z
AHAZAN_SID=S-1-5-21-4110623484-3775389421-3704134857-1001
AHAZAN_ENABLED=True
ADMIN_GROUP_MEMBERS=edge-runn-envy\Administrator[S-1-5-21-4110623484-3775389421-3704134857-500]; edge-runn-envy\ahazan[S-1-5-21-4110623484-3775389421-3704134857-1001]
SSHD_SVC=Running/Automatic
SSHD_IMAGEPATH=C:\WINDOWS\System32\OpenSSH\sshd.exe
SSHD_FILE=OpenSSH_9.5p2 for Windows filever=9.5.6.2 created=2026-09-09 written=2026-09-09
PORT22_PID=3400
PORT22_PROCEXE=C:\WINDOWS\System32\OpenSSH\sshd.exe
SSHD_CONFIG_LINES=ListenAddress	<redacted> | ListenAddress	<redacted> | AuthorizedKeysFile	.ssh/authorized_keys | Subsystem	sftp	sftp-server.exe | Match Group administrators |        AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
SSHD_CAPABILITY=OpenSSH.Server~~~~0.0.1.0 state=Installed version=
SUDO_FEATURE=unavailable
HOTFIX_LAST=KB5054156@2026-08-09, KB5122035@2026-09-01, KB5124007@2026-09-09, KB5126052@2026-09-09, KB5129195@2026-09-14, KB5121794@2026-10-09
WU_INSTALL_EVENTS=
EXPLORER_OWNER=11912 edge-runn-envy\ahazan
SESSIONS= ahazan                                    2  Disc         1:03  10/9/2026 3:48 PM
PENDING_REBOOT_COMPONENTS=False
PENDING_REBOOT_WU=False
OPENSSH_DEFSHELL=(unset)
SSHD_CONFIG_SHA256=B5C0A8ACE1E64FC30BCBF9EA731CFD3B142241BD4CA6F30D6AA12B4DCE4DC69C
```

#### edge-dev

```text
USER=edge-dev\ahazan
USER_SID=S-1-5-21-3782134917-2737737491-2203520143-1001
AUTH_PACKAGE_IDENTITY=NTLM
IS_IN_ADMINISTRATORS_ROLE=True
TOKEN_ELEVATION_TYPE=1 (Default(no-split))
TOKEN_IS_ELEVATED=1
LINKED_TOKEN=absent (GetLastError=24)
AUTH_LUID=0:14b09ca4
LOGON_TYPE=lsa-rc=-1
WHOAMI_GROUP=BUILTIN\Administrators Alias S-1-5-32-544 Mandatory group, Enabled by default, Enabled group, Group owner
WHOAMI_GROUP=Mandatory Label\High Mandatory Level Label S-1-16-12288
PRIV_ENABLED_COUNT=24
PRIV_SAMPLE=SeTakeOwnershipPrivilege Take ownership of files or other objects Enabled
PRIV_SAMPLE=SeBackupPrivilege Back up files and directories Enabled
PRIV_SAMPLE=SeShutdownPrivilege Shut down the system Enabled
PRIV_SAMPLE=SeDebugPrivilege Debug programs Enabled
POL_EnableLUA=1
POL_ConsentPromptBehaviorAdmin=5
POL_PromptOnSecureDesktop=1
POL_FilterAdministratorToken=1
POL_LocalAccountTokenFilterPolicy=ABSENT
POL_ValidateAdminCodeSignatures=0
POL_EnableSecureUIAPaths=1
POL2_LocalAccountTokenFilterPolicy=ABSENT
OS_PRODUCT=Windows 10 Pro
OS_DISPLAY=26H2
OS_BUILDTAG=26300.9457
OS_INSTALLDATE=2026-08-17 18:43Z
OS_CAPTION=Microsoft Windows 11 Pro
LAST_BOOT=2026-10-09 18:57Z
AHAZAN_SID=S-1-5-21-3782134917-2737737491-2203520143-1001
AHAZAN_ENABLED=True
ADMIN_GROUP_MEMBERS=edge-dev\Administrator[S-1-5-21-3782134917-2737737491-2203520143-500]; edge-dev\ahazan[S-1-5-21-3782134917-2737737491-2203520143-1001]
SSHD_SVC=Running/Automatic
SSHD_IMAGEPATH=C:\Windows\System32\OpenSSH\sshd.exe
SSHD_FILE=OpenSSH_9.5p2 for Windows filever=9.5.6.2 created=2026-09-09 written=2026-09-09
PORT22_PID=4668
PORT22_PROCEXE=C:\Windows\System32\OpenSSH\sshd.exe
SSHD_CONFIG_LINES=AuthorizedKeysFile	.ssh/authorized_keys | Subsystem	sftp	sftp-server.exe | PasswordAuthentication no | PubkeyAuthentication yes | Match Group administrators |        AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
SSHD_CAPABILITY=OpenSSH.Server~~~~0.0.1.0 state=Installed version=
SUDO_FEATURE=unavailable
HOTFIX_LAST=KB5054156@2026-08-17, KB5095189@2026-08-17, KB5124007@2026-09-09, KB5126052@2026-09-09, KB5129195@2026-09-15, KB5121794@2026-10-06
WU_INSTALL_EVENTS=
EXPLORER_OWNER=9816 edge-dev\ahazan
SESSIONS= ahazan                rdp-tcp#0           1  Active          .  10/9/2026 2:57 PM
PENDING_REBOOT_COMPONENTS=False
PENDING_REBOOT_WU=False
OPENSSH_DEFSHELL=(unset)
SSHD_CONFIG_SHA256=2A5DABECA87D3D0B77F415D899EDBB301388EF2175330AD66C2C4F35FDE9BD13
```

#### alien

```text
USER=EDGE-ALIEN\ahazan
USER_SID=S-1-5-21-505309461-3276478039-2092188341-1000
AUTH_PACKAGE_IDENTITY=NTLM
IS_IN_ADMINISTRATORS_ROLE=True
TOKEN_ELEVATION_TYPE=1 (Default(no-split))
TOKEN_IS_ELEVATED=1
LINKED_TOKEN=absent (GetLastError=24)
AUTH_LUID=0:7208f36a
LOGON_TYPE=lsa-rc=-1
WHOAMI_GROUP=BUILTIN\Administrators Alias S-1-5-32-544 Mandatory group, Enabled by default, Enabled group, Group owner
WHOAMI_GROUP=Mandatory Label\High Mandatory Level Label S-1-16-12288
PRIV_ENABLED_COUNT=24
PRIV_SAMPLE=SeTakeOwnershipPrivilege Take ownership of files or other objects Enabled
PRIV_SAMPLE=SeBackupPrivilege Back up files and directories Enabled
PRIV_SAMPLE=SeShutdownPrivilege Shut down the system Enabled
PRIV_SAMPLE=SeDebugPrivilege Debug programs Enabled
POL_EnableLUA=1
POL_ConsentPromptBehaviorAdmin=5
POL_PromptOnSecureDesktop=1
POL_FilterAdministratorToken=ABSENT
POL_LocalAccountTokenFilterPolicy=ABSENT
POL_ValidateAdminCodeSignatures=0
POL_EnableSecureUIAPaths=1
POL2_LocalAccountTokenFilterPolicy=ABSENT
OS_PRODUCT=Windows 10 Pro
OS_DISPLAY=26H2
OS_BUILDTAG=26300.9457
OS_INSTALLDATE=2026-10-05 14:23Z
OS_CAPTION=Microsoft Windows 11 Pro
LAST_BOOT=2026-10-08 00:12Z
AHAZAN_SID=S-1-5-21-505309461-3276478039-2092188341-1000
AHAZAN_ENABLED=True
ADMIN_GROUP_MEMBERS=EDGE-ALIEN\Administrator[S-1-5-21-505309461-3276478039-2092188341-500]; EDGE-ALIEN\ahazan[S-1-5-21-505309461-3276478039-2092188341-1000]
SSHD_SVC=Running/Automatic
SSHD_IMAGEPATH=C:\WINDOWS\System32\OpenSSH\sshd.exe
SSHD_FILE=OpenSSH_9.5p2 for Windows filever=9.5.6.2 created=2026-10-05 written=2026-10-05
PORT22_PID=4748
PORT22_PROCEXE=C:\WINDOWS\System32\OpenSSH\sshd.exe
SSHD_CONFIG_LINES=AuthorizedKeysFile	.ssh/authorized_keys | Subsystem	sftp	sftp-server.exe | Match Group administrators |        AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
SSHD_CAPABILITY=OpenSSH.Server~~~~0.0.1.0 state=Installed version=
SUDO_FEATURE=unavailable
HOTFIX_LAST=KB5124007@2026-09-13, KB5129195@2026-09-13, KB5126052@2026-09-13, KB5121794@2026-09-13, KB5128942@2026-10-05
WU_INSTALL_EVENTS=
EXPLORER_OWNER=9064 EDGE-ALIEN\ahazan
SESSIONS= ahazan                                    1  Disc        23:52  10/7/2026 8:13 PM
PENDING_REBOOT_COMPONENTS=False
PENDING_REBOOT_WU=False
OPENSSH_DEFSHELL=(unset)
SSHD_CONFIG_SHA256=99F373A06DFA706F0A8A98D655C776850305B4B1EA3BF9A33FA926897BB15649
```

#### 916

```text
USER=916-alien\ahazan2
USER_SID=S-1-5-21-1517438468-946630668-2521513353-1001
AUTH_PACKAGE_IDENTITY=NTLM
IS_IN_ADMINISTRATORS_ROLE=True
TOKEN_ELEVATION_TYPE=1 (Default(no-split))
TOKEN_IS_ELEVATED=1
LINKED_TOKEN=absent (GetLastError=24)
AUTH_LUID=1:9142d742
LOGON_TYPE=lsa-rc=-1
WHOAMI_GROUP=BUILTIN\Administrators Alias S-1-5-32-544 Mandatory group, Enabled by default, Enabled group, Group owner
WHOAMI_GROUP=Mandatory Label\High Mandatory Level Label S-1-16-12288
PRIV_ENABLED_COUNT=24
PRIV_SAMPLE=SeTakeOwnershipPrivilege Take ownership of files or other objects Enabled
PRIV_SAMPLE=SeBackupPrivilege Back up files and directories Enabled
PRIV_SAMPLE=SeShutdownPrivilege Shut down the system Enabled
PRIV_SAMPLE=SeDebugPrivilege Debug programs Enabled
POL_EnableLUA=1
POL_ConsentPromptBehaviorAdmin=5
POL_PromptOnSecureDesktop=1
POL_FilterAdministratorToken=ABSENT
POL_LocalAccountTokenFilterPolicy=ABSENT
POL_ValidateAdminCodeSignatures=0
POL_EnableSecureUIAPaths=1
POL2_LocalAccountTokenFilterPolicy=ABSENT
OS_PRODUCT=Windows 10 Pro
OS_DISPLAY=26H2
OS_BUILDTAG=26300.9457
OS_INSTALLDATE=2025-12-12 22:21Z
OS_CAPTION=Microsoft Windows 11 Pro
LAST_BOOT=2026-10-01 00:32Z
AHAZAN=lookup-failed
ADMIN_GROUP_MEMBERS=916-alien\Administrator[S-1-5-21-1517438468-946630668-2521513353-500]; 916-alien\ahazan2[S-1-5-21-1517438468-946630668-2521513353-1001]
SSHD_SVC=Running/Automatic
SSHD_IMAGEPATH=C:\windows\System32\OpenSSH\sshd.exe
SSHD_FILE=OpenSSH_9.5p2 for Windows filever=9.5.6.2 created=2026-09-15 written=2026-09-15
PORT22_PID=5260
PORT22_PROCEXE=C:\windows\System32\OpenSSH\sshd.exe
SSHD_CONFIG_LINES=AuthorizedKeysFile	.ssh/authorized_keys | Subsystem	sftp	sftp-server.exe | PasswordAuthentication no | PubkeyAuthentication yes | Match Group administrators |        AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
SSHD_CAPABILITY=OpenSSH.Server~~~~0.0.1.0 state=Installed version=
SUDO_FEATURE=unavailable
HOTFIX_LAST=KB5050575@2025-12-12, KB5071430@2025-12-12, KB5129195@2026-09-30, KB5124007@2026-09-30, KB5126052@2026-09-30, KB5121794@2026-10-01
WU_INSTALL_EVENTS=
EXPLORER_OWNER=37072 916-alien\ahazan2
SESSIONS= ahazan2               console             2  Active    6+23:08  10/4/2026 7:18 PM
PENDING_REBOOT_COMPONENTS=False
PENDING_REBOOT_WU=False
OPENSSH_DEFSHELL=(unset)
SSHD_CONFIG_SHA256=2850B2EA2D3EF813C4FC5C12596E7196AD37932DCAC4B58D9D22AF3F19C041AF
```

#### 4837

```text
USER=IML\ahazan2
USER_SID=S-1-5-21-1195524518-1464848461-2657271975-2716
AUTH_PACKAGE_IDENTITY=Kerberos
IS_IN_ADMINISTRATORS_ROLE=True
TOKEN_ELEVATION_TYPE=1 (Default(no-split))
TOKEN_IS_ELEVATED=1
LINKED_TOKEN=absent (GetLastError=24)
AUTH_LUID=1:dd36f9da
LOGON_TYPE=lsa-rc=-1
WHOAMI_GROUP=BUILTIN\Administrators Alias S-1-5-32-544 Mandatory group, Enabled by default, Enabled group, Group owner
WHOAMI_GROUP=Mandatory Label\High Mandatory Level Label S-1-16-12288
PRIV_ENABLED_COUNT=24
PRIV_SAMPLE=SeTakeOwnershipPrivilege Take ownership of files or other objects Enabled
PRIV_SAMPLE=SeBackupPrivilege Back up files and directories Enabled
PRIV_SAMPLE=SeShutdownPrivilege Shut down the system Enabled
PRIV_SAMPLE=SeDebugPrivilege Debug programs Enabled
POL_EnableLUA=1
POL_ConsentPromptBehaviorAdmin=5
POL_PromptOnSecureDesktop=1
POL_FilterAdministratorToken=ABSENT
POL_LocalAccountTokenFilterPolicy=ABSENT
POL_ValidateAdminCodeSignatures=0
POL_EnableSecureUIAPaths=1
POL2_LocalAccountTokenFilterPolicy=ABSENT
OS_PRODUCT=Windows 10 Pro
OS_DISPLAY=26H2
OS_BUILDTAG=26300.9457
OS_INSTALLDATE=2024-09-19 18:50Z
OS_CAPTION=Microsoft Windows 11 Pro
LAST_BOOT=2026-09-30 16:35Z
AHAZAN_SID=S-1-5-21-2064491265-700893739-4052456167-1001
AHAZAN_ENABLED=True
ADMIN_GROUP_MEMBERS=al8960ofc\Administrator[S-1-5-21-2064491265-700893739-4052456167-500]; al8960ofc\ahazan[S-1-5-21-2064491265-700893739-4052456167-1001]; IML\ahadmin-grp[S-1-5-21-1195524518-1464848461-2657271975-4802]; IML\ahazan[S-1-5-21-1195524518-1464848461-2657271975-1108]; IML\ahazan2[S-1-5-21-1195524518-1464848461-2657271975-2716]; IML\Domain Admins[S-1-5-21-1195524518-1464848461-2657271975-512]
SSHD_SVC=Running/Automatic
SSHD_IMAGEPATH=C:\Windows\System32\OpenSSH\sshd.exe
SSHD_FILE=OpenSSH_9.5p2 for Windows filever=9.5.6.2 created=2026-09-08 written=2026-09-08
PORT22_PID=6416
PORT22_PROCEXE=C:\Windows\System32\OpenSSH\sshd.exe
SSHD_CONFIG_LINES=AuthorizedKeysFile	.ssh/authorized_keys | Subsystem	sftp	sftp-server.exe | Match Group administrators |        AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys | PasswordAuthentication no | PubkeyAuthentication yes
SSHD_CAPABILITY=OpenSSH.Server~~~~0.0.1.0 state=Installed version=
SUDO_FEATURE=unavailable
HOTFIX_LAST=KB5043939@2024-09-19, KB5054156@2025-10-27, KB5124007@2026-09-08, KB5126052@2026-09-09, KB5129195@2026-09-15, KB5121794@2026-09-30
WU_INSTALL_EVENTS=
EXPLORER_OWNER=15556 IML\ahazan2
SESSIONS= ahazan2                                   1  Disc         1:14  9/30/2026 12:36 PM
PENDING_REBOOT_COMPONENTS=False
PENDING_REBOOT_WU=False
OPENSSH_DEFSHELL=(unset)
SSHD_CONFIG_SHA256=73E8D40E2C574C5450BCDB09C3FDF552A28250A6807C60533AB1EBE631DF45C1
```

### envy-probe2.ps1 — logon type proof (envy, edge-dev)

The `MY_AUTHLUID_LOW_DEC` value matches the `SESS id=` of exactly one session below it, proving
the SSH process token belongs to that LSA logon session.

#### envy

```text
MY_AUTHLUID=0:4e35063
MY_AUTHLUID_LOW_DEC=82006115
SESSION_COUNT=14
SESS=id=82005310 type=5 pkg=Negotiate age=1s
SESS=id=82006115 type=3 pkg=NTLM age=0s
SSHD_CREATED=2026-09-09 03:41:39Z
SSHD_WRITTEN=2026-09-09 03:41:40Z
SSHD_SVC_STARTED=Auto state=Running pid=3400
```

#### edge-dev

```text
MY_AUTHLUID=0:14cc47b8
MY_AUTHLUID_LOW_DEC=348932024
SESSION_COUNT=15
SESS=id=348923491 type=5 pkg=Negotiate age=1s
SESS=id=348932024 type=3 pkg=NTLM age=1s
SESS=id=2323238 type=3 pkg=NTLM age=9280s
SSHD_CREATED=2026-09-09 01:04:28Z
SSHD_WRITTEN=2026-09-09 01:04:28Z
SSHD_SVC_STARTED=Auto state=Running pid=4668
```

### explorer-probe.ps1 — interactive token baseline (envy, edge-dev)

The interactive explorer token is still UAC-filtered (Limited) on both hosts, while the SSH
token in the same machines is Full — isolating the anomaly to the SSH logon path.

#### envy

```text
EXPLORER_TOKEN elevated=0 type=Limited pid=11912
OS now: 26300.9457 display=26H2
date_utc=2026-10-09 21:33Z
```

#### edge-dev

```text
EXPLORER_TOKEN elevated=0 type=Limited pid=9816
OS now: 26300.9457 display=26H2
date_utc=2026-10-09 21:33Z
```

### lsa-probe.ps1 — LSA/SAM stack file timestamps (envy, edge-dev)

Every file in the LSA/SAM/NTLM stack carries a 2026-09-09 creation/write timestamp — the
2026-09-09 cumulative update transaction date.

#### envy

```text
lsasrv.dll ver=10.0.26100.8737 (WinBuild.160101.0800) created=2026-09-09 03:41Z written=2026-09-09 03:41Z
samsrv.dll ver=10.0.26100.8115 (WinBuild.160101.0800) created=2026-09-09 03:41Z written=2026-09-09 03:41Z
samlib.dll ver=10.0.26100.8737 (WinBuild.160101.0800) created=2026-09-09 03:41Z written=2026-09-09 03:41Z
msv1_0.dll ver=10.0.26100.8521 (WinBuild.160101.0800) created=2026-09-09 03:41Z written=2026-09-09 03:41Z
kerberos.dll ver=10.0.26100.8737 (WinBuild.160101.0800) created=2026-09-09 03:41Z written=2026-09-09 03:41Z
wdigest.dll ver=10.0.26100.9278 (WinBuild.160101.0800) created=2026-09-09 03:41Z written=2026-09-09 03:41Z
tspkg.dll ver=10.0.26100.9278 (WinBuild.160101.0800) created=2026-09-09 03:41Z written=2026-09-09 03:41Z
cryptdll.dll ver=10.0.26100.9278 (WinBuild.160101.0800) created=2026-09-09 03:41Z written=2026-09-09 03:41Z
netlogon.dll ver=10.0.26100.8115 (WinBuild.160101.0800) created=2026-09-09 03:41Z written=2026-09-09 03:41Z
```

#### edge-dev

```text
lsasrv.dll ver=10.0.26100.8737 (WinBuild.160101.0800) created=2026-09-09 01:04Z written=2026-09-09 01:04Z
samsrv.dll ver=10.0.26100.8115 (WinBuild.160101.0800) created=2026-09-09 01:03Z written=2026-09-09 01:03Z
samlib.dll ver=10.0.26100.8737 (WinBuild.160101.0800) created=2026-09-09 01:03Z written=2026-09-09 01:03Z
msv1_0.dll ver=10.0.26100.8521 (WinBuild.160101.0800) created=2026-09-09 01:04Z written=2026-09-09 01:04Z
kerberos.dll ver=10.0.26100.8737 (WinBuild.160101.0800) created=2026-09-09 01:04Z written=2026-09-09 01:04Z
wdigest.dll ver=10.0.26100.9278 (WinBuild.160101.0800) created=2026-09-09 01:04Z written=2026-09-09 01:04Z
tspkg.dll ver=10.0.26100.9278 (WinBuild.160101.0800) created=2026-09-09 01:04Z written=2026-09-09 01:04Z
cryptdll.dll ver=10.0.26100.9278 (WinBuild.160101.0800) created=2026-09-09 01:03Z written=2026-09-09 01:03Z
netlogon.dll ver=10.0.26100.8115 (WinBuild.160101.0800) created=2026-09-09 01:04Z written=2026-09-09 01:04Z
```

### sshd-binary-check.ps1 — sshd binary provenance (envy)

Compares the base 9.5.0.1 WinSxS copy, the Sep-3-era 9.5.6.1 WinSxS copy, and the active
9.5.6.2 binary. Observed: the 9.5.6.1 and 9.5.6.2 binaries have EQUAL sizes (1,335,296).
The hypothesized ASCII unique-string count of 1 per side was NOT observed — the ASCII string
sets are identical (0 unique each). The difference is isolated instead by the UTF-16 string
comparison (exactly 1 unique per side: the version resource `9.5.6.1` vs `9.5.6.2`), the
differing PDB GUID, and 11 small byte-diff ranges (40 bytes total) confined to PE-header,
version-resource, PDB-GUID, and checksum regions.

```text
PATH=C:\Windows\WinSxS\amd64_openssh-server-components-onecore_31bf3856ad364e35_10.0.26100.1_none_2414f81d8596f589\sshd.exe
  SIZE=1327616
  FILEVER=9.5.0.1  PRODVER=OpenSSH_9.5p1 for Windows
  MD5=FE2396ACF3CB2143049F303B0E98F032
PATH=C:\Windows\WinSxS\amd64_openssh-server-components-onecore_31bf3856ad364e35_10.0.26100.9168_none_c308f96dccf4131e\sshd.exe
  SIZE=1335296
  FILEVER=9.5.6.1  PRODVER=OpenSSH_9.5p2 for Windows
  MD5=1FA42F1C477CB23B3835BEC82F67644F
PATH=C:\Windows\System32\OpenSSH\sshd.exe
  SIZE=1335296
  FILEVER=9.5.6.2  PRODVER=OpenSSH_9.5p2 for Windows
  MD5=45DD569E73CAE0B1BAD050EEE7F7E009
STRINGS_ASCII_9168_TOTAL=5622
STRINGS_ASCII_ACTIVE_TOTAL=5622
ASCII_ONLY_IN_9168 count=0
ASCII_ONLY_IN_ACTIVE count=0
STRINGS_UTF16_9168_TOTAL=455
STRINGS_UTF16_ACTIVE_TOTAL=455
UTF16_ONLY_IN_9168 count=1
  OLD_ONLY: 9.5.6.1
UTF16_ONLY_IN_ACTIVE count=1
  NEW_ONLY: 9.5.6.2
PDBGUID_9168=C6-54-8F-BA-28-E1-DD-42-BB-A0-1E-4A-E7-DD-14-EA
PDBGUID_ACTIVE=DA-BC-8A-43-BE-90-D5-47-AF-D7-5B-8F-D6-75-8F-5C
DIFF_BYTE_RANGES count=11
  RANGE 288-290
  RANGE 368-370
  RANGE 1225924-1225926
  RANGE 1225952-1225954
  RANGE 1225980-1225982
  RANGE 1226008-1226010
  RANGE 1226036-1226038
  RANGE 1228412-1228427
  RANGE 1329364-1329364
  RANGE 1329372-1329372
  RANGE 1329508-1329508
```

## Conclusions

- **sshd logon path exonerated.** The SSH session's auth LUID matches a type-3 Network logon
  authenticated by NTLM on both envy and edge-dev (envy-probe2), i.e. an ordinary LSA type-3
  logon — no exotic logon path. The bundled sshd bump 9.5.6.1 → 9.5.6.2 is a version-string-only
  rebuild: equal sizes (1,335,296), identical ASCII string sets, and the only content differences
  are the UTF-16 version resource, the PDB GUID, and 40 bytes in PE header/checksum regions.
- **Build 26200 not required.** ENVY exhibited the flip while it was still on build 26200, and
  the 26300 hosts behave the same today (all five report OS_BUILDTAG=26300.9457 now); neither
  26200 nor 26300 is a necessary condition.
- **No undocumented host state.** All five hosts (envy, edge-dev, alien, 916, 4837) show the
  same behavior — TOKEN_ELEVATION_TYPE=1 (Default/no-split), TOKEN_IS_ELEVATED=1, no linked
  token (GetLastError=24), High integrity — and all documented weakening knobs are at secure
  defaults (EnableLUA=1, ConsentPromptBehaviorAdmin=5, PromptOnSecureDesktop=1,
  LocalAccountTokenFilterPolicy=ABSENT everywhere; edge-dev additionally has
  FilterAdministratorToken=1). The interactive explorer token on envy and edge-dev is still
  Limited/elevated=0, so only the SSH logon is anomalous. 4837 is excluded from the fleet
  finding as a domain-admin (IML\Domain Admins) Kerberos logon.
- **Root cause = 2026-09-09 LCU transaction (KB5124007/KB5126052).** Every host's hotfix list
  includes KB5124007 and KB5126052, and the entire LSA/SAM/NTLM stack (lsasrv.dll, samsrv.dll,
  samlib.dll, msv1_0.dll, kerberos.dll, wdigest.dll, tspkg.dll, cryptdll.dll, netlogon.dll)
  carries 2026-09-09 creation/write timestamps on both probed hosts — the servicing transaction
  that rewrote the LSA/SAM/NTLM stack.
- **Decision recorded in issue #1547:** no host-side hardening; the issue tracks the Microsoft
  servicing regression.
