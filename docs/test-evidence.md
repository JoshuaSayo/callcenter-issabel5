# Phase 1 Test Evidence

## Evidence convention

Each entry records environment, command or observation, result, and limitation. Static, simulated, unauthenticated staging, and authenticated staging evidence are never treated as interchangeable.

## Environment

- Media target: `issabel5-USB-DVD-x86_64-20240430.iso`; official SourceForge Issabel 5 listing was checked on 2026-08-28.
- Disposable target: Proxmox VM 127, `ISSABEL5CALLCENTERTEST`, `10.39.188.63`.
- Rollback: snapshot `baseline-before-callcenter-work`, RAM captured.
- User-reported isolation: trunks, inbound routes, and outbound routes removed; no GSM connection or VPN.
- Local branch: `develop` in `.worktrees/issabel5-phase1`.

## Static

### E-P1-001 — checkout and isolation

- Date: 2026-08-28 Asia/Manila.
- Commands: `git rev-parse --git-dir`, `git rev-parse --git-common-dir`, `git status --short --branch`.
- Result: linked worktree detected; branch `develop`; clean status.
- Label: local Git evidence.

### E-P1-002 — original lifecycle script syntax

- Date: 2026-08-28 Asia/Manila.
- Runtime: Git Bash 5.3.15 on Windows.
- Command: `bash -n build/5.0/install-issabel-callcenter.sh build/5.0/remove-issabel-callcenter.sh`.
- Exit: `0`.
- Result: original scripts parse as Bash; this does not validate runtime behavior.
- Limitation: WSL launcher was present but no WSL distribution was installed.

## Simulated

No simulated lifecycle test exists at this checkpoint. Task 2 creates the first deterministic command-stub test.

## Staging

### E-P1-003 — unauthenticated reachability

- Date: 2026-08-28 Asia/Manila.
- Result: ICMP success at 2 ms; TCP 22, 80, and 443 open.
- Result: HTTP `302` redirects to HTTPS; HTTPS `200` advertises Apache 2.4.37 on Rocky, OpenSSL 1.1.1k, and PHP 7.4.33.
- Label: unauthenticated network/web evidence only.
- Limitation: no SSH login, Issabel login, database query, service restart, or call was performed.

## Removal/Reinstallation

No removal command has been run. The user's authorization applies only to disposable VM 127, and the snapshot must be rechecked before database deletion.

## Retained local-only evidence

Infrastructure screenshots remain outside the public repository under `environment-evidence/`. Their paths and hashes are recorded in the workspace research log; the images are intentionally not committed.

## Limitations

- Exact installed Issabel build, MariaDB version, systemd version, CLI PHP modules, and clone Asterisk version remain unverified.
- No clean install, upgrade, removal, schema migration, authenticated UI, dialer, agent, queue, inbound, outbound, or report workflow has passed yet.
- No external call will be used as Phase 1 evidence.
