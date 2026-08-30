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

### E-P1-009 — authenticated staging upgrade/repeat validation

- Date: 2026-08-30 Asia/Manila. Runtime: verified dedicated root key with a pinned ED25519 host key on VM 127; fresh public `develop` clone at `751a62f49f093381e2fac0b0dcc4c6c99f521fc2` in `/usr/src/callcenter-issabel5-develop-751a62f`. The stopped pre-fix clone remained untouched.
- Pre-mutation test: `bash tests/install/run.sh` passed with `PASS test_baseline_collector`, `PASS: installer behavior tests`, `PASS test_lifecycle_common`, `PASS test_remove_script`, `PASS installer_lib`, and `PASS installer_entry`. The test ran with an isolated temporary command path that excluded the real host `asterisk`, so its declared missing-command case could not leak through the PBX runtime path.
- Syntax: `php -l setup/installer_lib.php` and `php -l setup/installer.php` both reported no syntax errors on clone PHP 7.4.33.
- Baseline: protected `baseline.env` mode `600`, size `2672`, SHA-256 `a59638e5d81a05187d4df3ec0d193f443bbfac2048f0f3d56da82921b0c75e36`; it contained no `mysqlrootpwd` line. Verified values: Rocky Linux 8.8; kernel `4.18.0-477.27.1.el8_8.x86_64`; PHP 7.4.33; MariaDB client/server 10.3.39; Asterisk 18.19.0; Apache 2.4.37; systemd 239; dialer enabled and active; `call_center` has 24 base tables.
- Recovery evidence: schema-only pre-install backup mode `600`, SHA-256 `fe5c36bc7a38c67e37d0309967324f1521818e6383a2467cb617b8d338bc65af`; pre-install file-state SHA-256 `d0552b6e91d4be4b4667dc500d6af72906f475375a077e0c02af807c7876d476`. No database rows or database password were retained in documentation.
- Upgrade/repeat commands: `bash build/5.0/install-issabel-callcenter.sh --local` twice under `pipefail`, with logs at `/root/callcenter-phase1/install-1.log` and `install-2.log`; each exited `0` and contains exactly one completion marker. The database password was compared only remotely and was absent from both logs.
- Repeated health: `issabeldialer` enabled/active; Asterisk 18.19.0; `llamada_agendada` present; `/opt/issabel/dialer/dialerd` executable; Agent Console file present; HTTPS `200`; `call_center` table count `24` after each run.
- Schema repeat comparison: raw post-install schema SHA-256 `21110fa6e0c06cf744b9bd1e4f58dd51f445ca87c46e1ead6b99f94a8931b33e`. The only normalized-diff line was mysqldump's generated `Dump completed` timestamp; after removing that volatile footer, both schema-only hashes were `c19896bdb243c76a2511df68ef4b5c4e26d56c89fd3ad8692cfa11ccf2485299`.
- Label: authenticated Rocky Linux staging upgrade/repeat evidence; no external call was placed and no routes, trunks, GSM, or VPN configuration was changed on the PBX.

## Removal/Reinstallation

No removal command has been run. The final Task 9 destructive scenario is clean-database removal/reinstallation on disposable VM 127; it is unverified and not yet executed. The snapshot must be rechecked before database deletion.

## Retained local-only evidence

Infrastructure screenshots remain outside the public repository under `environment-evidence/`. Their paths and hashes are recorded in the workspace research log; the images are intentionally not committed.

## Limitations

- Exact Issabel media build and FreePBX-derived component versions remain unverified.
- No removal, authenticated UI, dialer, agent, queue, inbound, outbound, or report workflow has passed; Task 9 clean-database removal/reinstallation remains unverified.
- The local portable-PHP suite log timestamp predates the recorded `git update-index --chmod=+x` operation and is not used as post-fix proof; the fresh Rocky Linux clone at `751a62f` is the decisive GREEN evidence.
- No external call will be used as Phase 1 evidence.
