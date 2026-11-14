# Claude Code Instructions

## NAS Access

**You have SSH access to the NAS.** Credentials are in `.claude/config.local.md`.

To run commands on the NAS:
```bash
sshpass -p 'PASSWORD' ssh -o StrictHostKeyChecking=accept-new USER@HOSTNAME 'command here'
```

Read `.claude/config.local.md` first to get the hostname, user, and password.

## Project Structure

This is a Docker media stack for Ugreen NAS devices. Key paths:

- **Local dev repo**: local clone (path varies per developer)
- **NAS deploy path**: `/volume2/docker/arr-stack/`

When editing files that need to go on the NAS (like `pihole/02-local-dns.conf`), edit them **on the NAS**, not in this local repo.

