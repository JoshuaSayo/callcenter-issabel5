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

### E-P1-004 — baseline collector RED

- Date: 2026-08-28 Asia/Manila.
- Runtime: Git Bash 5.3.15 on Windows.
- Command: `bash tests/install/test_baseline_collector.sh`.
- Exit: `1`.
- Decisive output: `FAIL: expected status 0, got 127`.
- Interpretation: expected failure because `tools/collect-issabel-baseline.sh` did not exist.
- Label: TDD RED; simulated command-stub evidence.

### E-P1-005 — baseline collector GREEN

- Date: 2026-08-28 Asia/Manila.
- Commands: `bash tests/install/test_baseline_collector.sh`; `bash -n tools/collect-issabel-baseline.sh tests/install/test_helpers.sh tests/install/test_baseline_collector.sh tests/install/run.sh`; `bash tests/install/run.sh`.
- Exits: `0`, `0`, `0`.
- Decisive output: `PASS test_baseline_collector`.
- Verified behavior: literal version/schema keys are emitted without the fixture password; required Asterisk failure returns nonzero and emits `ASTERISK_VERSION=ERROR` rather than `UNAVAILABLE`.
- Label: simulated command-stub evidence; not staging verification.
- Limitation: command stubs isolate external RPM, PHP, MariaDB, Asterisk, Apache, and systemd behavior and are not proof that VM 127 supports the collector.

### E-P1-006 — lifecycle safety RED/GREEN

- Date: 2026-08-28 Asia/Manila.
- RED command: `bash tests/install/test_lifecycle_common.sh`.
- RED exit: `1`; decisive output identified missing `build/5.0/lib/callcenter-lifecycle.sh`.
- First GREEN attempt: test harness failed because stderr redirection was attached to a separate shell command; production behavior was not changed for this harness failure.
- Final commands: `bash tests/install/test_lifecycle_common.sh`; `bash tests/install/run.sh`; `bash -n build/5.0/lib/callcenter-lifecycle.sh tests/install/test_lifecycle_common.sh`.
- Final exits: `0`, `0`, `0`.
- Decisive output: `PASS test_lifecycle_common`; aggregate also reports `PASS test_baseline_collector`.
- Verified behavior: registered temporary directories are removed; a sentinel outside allowed roots survives; relative install roots and unsafe cleanup registration are rejected; required command failures retain their stage name.
- Label: local filesystem behavior with isolated temporary directories; no PBX mutation.

### E-P1-007 — PHP installer failure propagation RED/GREEN

- Date: 2026-08-28 Asia/Manila.
- Runtime: official portable PHP `7.4.33 (cli) (NTS Visual C++ 2017 x64)` on Windows; Git Bash `C:\Program Files\Git\bin\bash.exe` for shell propagation and aggregate checks.
- RED command: `.\.superpowers\sdd\2026-08-28-issabel5-callcenter-phase1\runtime\php-7.4.33\php.exe tests/install/test_installer_lib.php`.
- RED exit: `255`; decisive output: `Failed opening required ... setup/installer_lib.php` because the helper library did not yet exist.
- GREEN commands: the same portable-PHP helper command; portable-PHP `tests/install/test_installer_entry.php`; portable-PHP `-l setup/installer_lib.php`; portable-PHP `-l setup/installer.php`; `C:\Program Files\Git\bin\bash.exe tests/install/test_install_script.sh`; and `$env:PATH = "$(Resolve-Path .\.superpowers\sdd\2026-08-28-issabel5-callcenter-phase1\runtime\php-7.4.33);$env:PATH"; & 'C:\Program Files\Git\bin\bash.exe' tests/install/run.sh`.
- GREEN exits: all `0`.
- Decisive output: `PASS installer_lib`; `PASS installer_entry`; `No syntax errors detected` for both PHP files; `PASS: installer behavior tests`; aggregate `PASS test_baseline_collector`, `PASS: installer behavior tests`, `PASS test_lifecycle_common`, `PASS installer_lib`, and `PASS installer_entry`.
- Verified behavior: false database/file results and a missing required `agents.conf` raise installation exceptions; unavailable or malformed Asterisk output is rejected; the real PHP entry wrapper exits `1` and suppresses continuation when database creation returns nonzero; the shell installer propagates its failing PHP stub and suppresses completion; all local install tests pass with the portable PHP runtime on Git Bash `PATH`.
- Label: local PHP 7.4.33 unit/syntax and simulated command-stub evidence only.
- Limitation: this does not replace Rocky Linux staging checks required in Task 8.

### E-P1-008 — pre-staging lifecycle regression checkpoint

- Date: 2026-08-29 Asia/Manila.
- Aggregate command: `$phpDir=(Resolve-Path -LiteralPath '.superpowers\\sdd\\2026-08-28-issabel5-callcenter-phase1\\runtime\\php-7.4.33').Path; $env:PATH="$phpDir;$env:PATH"; & 'C:\\Program Files\\Git\\bin\\bash.exe' tests/install/run.sh`.
- Result: controller-recorded direct execution exited `0` with `PASS test_baseline_collector`, `PASS: installer behavior tests`, `PASS test_lifecycle_common`, `PASS test_remove_script`, `PASS installer_lib`, and `PASS installer_entry`.
- Runtime: portable Windows PHP `7.4.33` on `PATH`; Git Bash `C:\\Program Files\\Git\\bin\\bash.exe`.
- Start: `2026-08-29T22:10:29.3893252+08:00`; end: `2026-08-29T22:13:26.6266954+08:00`; exit: `0`.
- Label: portable Windows PHP 7.4 unit/syntax and simulated command-stub evidence only; not Rocky staging evidence.
- Syntax command: `bash -n tools/collect-issabel-baseline.sh build/5.0/lib/callcenter-lifecycle.sh build/5.0/install-issabel-callcenter.sh build/5.0/remove-issabel-callcenter.sh tests/install/*.sh`.
- Start: `2026-08-29T22:00:29.3651442+08:00`; end: `2026-08-29T22:00:29.4500541+08:00`; exit: `0`; decisive output: no syntax diagnostics.
- Label: portable Windows Git Bash syntax evidence only.
- Diff command: `git diff --check upstream/master...HEAD`.
- Start: `2026-08-29T22:00:44.2262495+08:00`; end: `2026-08-29T22:00:44.3391201+08:00`; exit: `0`; decisive output: no whitespace diagnostics.
- Label: local Git static evidence.
- Status command: `git status --short`.
- Start: `2026-08-29T22:00:53.5348498+08:00`; end: `2026-08-29T22:00:53.6173624+08:00`; exit: `0`; decisive output: empty (clean worktree before documentation edits).
- Label: local Git static evidence.
- Docker command: `docker version`.
- Start: `2026-08-29T22:01:02.0117546+08:00`; end: `2026-08-29T22:01:02.2801565+08:00`; exit: `1`; decisive output: `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine`.
- Label: local container-engine availability evidence.
- Local PHP 7.4 container check unavailable; Task 8 staging PHP 7.4 checks are required before mutation.
- Final scenario-label commit check: `git diff --check upstream/master...HEAD`.
- Start: `2026-08-29T22:20:34.5085530+08:00`; end: `2026-08-29T22:20:34.5629078+08:00`; exit: `0`; decisive output: no whitespace diagnostics.
- Label: final committed-document static evidence, covering the clean-database removal/reinstallation scenario label.
- Final scenario-label worktree check: `git status --short`.
- Start: `2026-08-29T22:20:34.5642830+08:00`; end: `2026-08-29T22:20:34.6126785+08:00`; exit: `0`; decisive output: empty.
- Label: final committed-document static evidence, before the evidence-only update below.

## Staging

### E-P1-003 — unauthenticated reachability

- Date: 2026-08-28 Asia/Manila.
- Result: ICMP success at 2 ms; TCP 22, 80, and 443 open.
- Result: HTTP `302` redirects to HTTPS; HTTPS `200` advertises Apache 2.4.37 on Rocky, OpenSSL 1.1.1k, and PHP 7.4.33.
- Label: unauthenticated network/web evidence only.
- Limitation: no SSH login, Issabel login, database query, service restart, or call was performed.

## Removal/Reinstallation

No removal command has been run. The final Task 9 destructive scenario is clean-database removal/reinstallation on disposable VM 127; it is unverified and not yet executed. The snapshot must be rechecked before database deletion.

## Retained local-only evidence

Infrastructure screenshots remain outside the public repository under `environment-evidence/`. Their paths and hashes are recorded in the workspace research log; the images are intentionally not committed.

## Limitations

- Exact installed Issabel build, MariaDB version, systemd version, CLI PHP modules, and clone Asterisk version remain unverified.
- No clean install, upgrade, removal, schema migration, authenticated UI, dialer, agent, queue, inbound, outbound, or report workflow has passed yet.
- Local PHP evidence remains simulated/unit/syntax evidence; Task 8 must perform staging checks before mutation.
- No external call will be used as Phase 1 evidence.
