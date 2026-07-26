---
name: Root access on edgesynology2
description: How to get root/docker access on edgesynology2 when ahazan SSH can't reach docker socket
type: feedback
originSessionId: f0a73e05-8924-44b9-a9df-5850bbb70717
---
To run docker or docker-compose commands on edgesynology2, SSH in as `popdam` (not `ahazan`) and use `sudo`:

```bash
ssh -i ~/.ssh/916-alien -p 1904 popdam@192.168.3.101
echo 'D@Mp0p123' | sudo -S bash -c '<command>'
```

**Why:** The docker socket is `root:root srw-rw----`. The `ahazan` user can SSH but has no docker socket access. Root SSH and `su` are blocked. However, `popdam` (also in `administrators`) can SSH with the 916-alien key AND has passworded `sudo` access.

**How to apply:** Any time docker-compose or docker CLI is needed on edgesynology2, use the popdam SSH path with sudo. The compose project lives at `/volume1/docker/synology-monitor-agent/`. Docker binary is at `/var/packages/ContainerManager/target/usr/bin/docker-compose`.
