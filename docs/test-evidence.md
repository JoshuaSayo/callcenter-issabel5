# Phase 1 Test Evidence

## Evidence convention

Each entry records environment, command or observation, result, and limitation. Static, simulated, unauthenticated staging, and authenticated staging evidence are never treated as interchangeable.

## Environment

- Media target: `issabel5-USB-DVD-x86_64-20240430.iso`; official SourceForge Issabel 5 listing was checked on 2026-08-28.
- Disposable target: Proxmox VM 127, `ISSABEL5CALLCENTERTEST`, `10.39.188.63`.
- Rollback: snapshot `baseline-before-callcenter-work`, RAM captured.
- Isolation: no GSM connection or PBX VPN; the remaining synthetic inbound/outbound test routes were backed up and removed through Issabel functions before lifecycle testing, then all five route tables were verified empty.
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

## Campaign workflows

### E-CC5-010-L1 — incoming external URL contract

- Date: 2026-08-31 Asia/Manila. Runtime: standalone Windows PHP 7.4.33 at `.codex-state/runtime/php-7.4.33/php.exe`.
- RED command: `php tests/campaign/test_incoming_campaign.php`; exit `1`. Decisive assertion: create bound URL1 as `11` but bound URL2 and URL3 as `NULL`.
- GREEN command: the same test after the class fix; exit `0`; decisive output: `PASS incoming_campaign`.
- Syntax commands: `php -l modules/campaign_in/libs/paloSantoIncomingCampaign.class.php` and `php -l tests/campaign/test_incoming_campaign.php`; both exited `0` with no syntax errors.
- Review-found boundary reproduction: PHP 7.4 converted raw `12junk` to integer `12`, while `ctype_digit('12junk')` returned false. The controller now preserves raw non-empty values for class validation.
- Verified locally: create and update bind all three URL IDs in order; invalid or partially numeric URL2/URL3 values are rejected before any database read/write; valid update emits no response output.
- Test boundary: the real campaign class runs against a deterministic fake `paloDB`; no live database, UI, queue, Asterisk, or call was used.
- Limitations: PHP 5.4 compatibility is syntax-reviewed but not runtime-tested. This local entry alone is fake-database evidence; matching native staging evidence is recorded in E-CC5-010-S1.

### E-CC5-011-L1 — incoming request owns no migration

- Date: 2026-08-31 Asia/Manila. Runtime: standalone Windows PHP 7.4.33 at `.codex-state/runtime/php-7.4.33/php.exe`.
- Executable boundary: the test loads the real incoming class and real `_moduleContent()`, fails if the legacy helpers remain exported or a migration sentinel is called, and stops at deterministic `paloDB` construction before any external database access.
- Accepted RED: `php tests/campaign/test_incoming_page_contract.php` exited `1` with `FAIL incoming_page_contract: legacy page-load migration helpers remain exported`. A preceding test-only cleanup warning was corrected before RED was accepted; production remained unchanged.
- GREEN: the identical command exited `0` with `PASS incoming_page_contract` after only the incoming bootstrap call and its two privileged helpers were removed.
- Integrated checks: the CC5-010 campaign regression, installer repair regression, canonical schema contract, relevant PHP lints, warning-enabled request test, and Git diff checks passed. A fresh read-only seam reviewer found no blocker.
- Scope: PHP 7.4 executable source evidence. The outgoing module's independent migration copy and campaign monitoring's legacy config parser were not changed.

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
- Authenticated installer-release evidence: `for log in /root/callcenter-phase1/install-1.log /root/callcenter-phase1/install-2.log; do printf "%s exact_completion_count=" "$(basename "$log")"; grep -F -x "Issabel CallCenter 5.0.0-1 installation complete!" "$log" | wc -l; done` returned `install-1.log exact_completion_count=1` and `install-2.log exact_completion_count=1`. This proves the installer release string from source commit `751a62f` completed twice; it is not an independent package or module-registry version query.
- Repeated health: `issabeldialer` enabled/active; Asterisk 18.19.0; `llamada_agendada` present; `/opt/issabel/dialer/dialerd` executable; Agent Console file present; HTTPS `200`; `call_center` table count `24` after each run.
- Schema repeat comparison: raw post-install schema SHA-256 `21110fa6e0c06cf744b9bd1e4f58dd51f445ca87c46e1ead6b99f94a8931b33e`. The only normalized-diff line was mysqldump's generated `Dump completed` timestamp; after removing that volatile footer, both schema-only hashes were `c19896bdb243c76a2511df68ef4b5c4e26d56c89fd3ad8692cfa11ccf2485299`.
- Label: authenticated Rocky Linux staging upgrade/repeat evidence; no external call was placed and no routes, trunks, GSM, or VPN configuration was changed on the PBX.

### E-CC5-010-S1 — authenticated incoming campaign class/database validation

- Date: 2026-08-31 Asia/Manila. Target: snapshot-backed VM 127 at `10.39.188.63`; exact clean clone `/usr/src/callcenter-issabel5-develop-e2e2ba3` at `e2e2ba32088eb52372459aa21a951f9317ab97e8`.
- Native checks: PHP 7.4.33 `tests/campaign/test_incoming_campaign.php` returned `PASS incoming_campaign`; controller, class, test, and staging harness lints reported no syntax errors.
- Protected harness: `/root/callcenter-phase1/cc5010-staging.php`, mode `600`, SHA-256 `7b58cd07c19c3df320c8ae49616759fb9d283a67819077ba0b91a49b3d48d74f`.
- Isolation: the harness used one uncommitted transaction against InnoDB `queue_call_entry`, `campaign_external_url`, and `campaign_entry`; synthetic rows were invisible to the dialer and rolled back. No route, trunk, service, dialplan, or installed module file changed.
- Behavior: partially numeric URL2 was rejected; create/read preserved URL1/URL2/URL3; the campaign was made inactive before any commit; update/read preserved the reordered URLs and emitted no debug output; transactional delete verification passed.
- Direct result: `PASS cc5010_staging ... active_before_after=0 current_before_after=0 persistent_rows=0`.
- Independent verifier: CONFIRMED the pinned host, exact clean source, harness hash, native checks, InnoDB rollback semantics, zero campaign/URL residue, zero active campaigns/current calls/channels, active dialer/Asterisk, Asterisk 18.19.0, and HTTPS `200`.
- Scope: authenticated SSH class/database staging evidence, not browser UI behavior or the separate `delete_campaign()` method. No telephony call was placed.

### E-CC5-011-S1 — exact installed incoming request-bootstrap validation

- Date: 2026-08-31 Asia/Manila. Target: snapshot-backed VM 127 at `10.39.188.63`; exact clean clone `/usr/src/callcenter-issabel5-develop-2d291bb` and installed incoming files at `2d291bb02e00d0a769ed09c72fdbdeaeaeb1857b`.
- Native checks: PHP 7.4.33 request/campaign/installer regressions, canonical schema contract, and four relevant lints passed before installation.
- Install and execution: the normal `--local` installer copied incoming controller/class files whose SHA-256 values match the exact clone. The request-contract test executed against those installed files and returned `PASS incoming_page_contract` without reaching a real database boundary.
- Stable state: URL schema/FK fingerprint remained `82d69e2c909df10ba6be8c511b018a403cf36d984b43ad786853f5a67d8efe5c`; `call_center` grant fingerprint remained `c22583ca2a5a337388ca484f1c876d603c3a3892dce75f24ab81fdad1b922c13`; four URL2/URL3 columns and four foreign keys remained present. Routes, Call Center activity, and Asterisk channels remained `0`; dialer stayed active/enabled as `asterisk`; Asterisk 18.19.0 and HTTPS `200` remained healthy.
- Protected evidence: result mode `600`, SHA-256 `c475c64e89c3cdbe8bbbb5fed8571ddfaf5526df7f37085290069432bcbc1770`; installer log mode `600`, SHA-256 `fb3edd990b27ae165b59ca095cc1d768379dba08ddf1fad2b1e573ea8a5211c8`.
- Evidence correction: the install wrapper's outer SSH process returned `1` after writing its gated success record. It was not treated as standalone proof and the installer was not rerun. A fresh read-only postcheck exited `0`; a separate strict pinned-host verifier then exited `0` and returned `CONFIRMED` for the exact current state and artifact hashes.
- Scope: installed-source request-bootstrap evidence, not an authenticated browser UI request or telephony call. HTTPS used loopback with certificate verification disabled. Outgoing and monitoring paths were not tested.

## Removal/Reinstallation

### E-P1-010 — authenticated staging removal and clean reinstallation

- Date: 2026-08-30 Asia/Manila. Target: snapshot-backed disposable VM 127. Final source: clean public `develop` clone at `29adf38ed454d5d6fff7170115c1cb6071902fbb` in `/usr/src/callcenter-issabel5-develop-29adf38`.
- Isolation: exact machine/DMI identities matched; zero active calls/channels and zero active campaigns; the synthetic inbound `888 / Test` route and outbound `outside` route were backed up, removed through Issabel-supported functions, and reloaded successfully. All five route tables remained empty. Protected recovery directory: `/root/callcenter-phase1/task9-20260830T090704Z`.
- Keep-database lifecycle: `--keep-database` removal exited `0`; Call Center files/service/context were absent while all 24 `call_center` tables and the logical database hash remained unchanged. Reinstall exited `0`, restored the service/files/context, and preserved the same database and unrelated dialplan state.
- Defect reproduced: the first clean reinstallation from `fa993c9` returned installer status `0` but omitted `campaign.id_url2`, `campaign.id_url3`, `campaign_entry.id_url2`, and `campaign_entry.id_url3`. Direct runtime projections failed with MariaDB error `1054`. Runtime code queries these fields, while campaign pages previously attempted a lazy schema repair.
- Fix: commit `29adf38` adds the four canonical clean-schema columns/foreign keys, a centralized repeat-installer repair, and regressions for exact schema and repair behavior. Pre-fix RED, amended GREEN, native PHP 7.4 execution, and independent standards/spec reviews were retained; both review axes ended with zero actionable findings.
- Repeat repair: exact `29adf38` repaired the incomplete live database. The four fields are nullable `int(10) unsigned`, all four foreign keys reference `campaign_external_url.id`, direct projections pass, and the semantic schema matches the protected pre-delete schema.
- Final clean lifecycle: a fresh full backup passed `gzip -t`; an independent read-only gate returned GO; `--delete-database` exited `0` and removed only the `call_center` schema while performing the remover's expected module/menu/ACL/file/dialplan cleanup. Unrelated database names and unrelated dialplan content were unchanged. Reinstallation from the same exact commit exited `0` and recreated 24 tables, all four fields/FKs, grants, files, service, and `llamada_agendada` context.
- Final health: source clean; semantic schema diff empty with both hashes `4d620f858cf73955b357346d9779fc8b69b6c01fb5cee893a70b5945436a2da8`; routes, Call Center activity, and channels zero; `issabeldialer` enabled/active as `asterisk`; Asterisk 18.19.0; HTTPS `200`; post-clean installer suite and PHP syntax pass.
- Independent final verifier: CONFIRMED the exact source/table hash, four column/FK shapes, runtime projections, semantic schema equality, protected unrelated-state baselines, zero-use state, service/files/context, Asterisk, HTTPS, and final artifact hashes through a separate pinned read-only session.

| Protected artifact | SHA-256 | Result |
| --- | --- | --- |
| `remove-keep-db.log` | `7f551d1d56c01ad02c8d8f9fbadd3661960e1d919a29a8bb00596ff35b1d48fd` | keep-database removal passed |
| `reinstall-keep-db.log` | `1a4caf7905b0b70f73e6ece642ea78a2c3f295ceb7552c6c14ba2ba6c9319d75` | keep-database reinstall passed |
| `remove-delete-db.log` | `7f551d1d56c01ad02c8d8f9fbadd3661960e1d919a29a8bb00596ff35b1d48fd` | initial delete passed |
| `reinstall-clean-db.log` | `1a4caf7905b0b70f73e6ece642ea78a2c3f295ceb7552c6c14ba2ba6c9319d75` | installer passed; schema postcheck exposed the defect |
| `reinstall-repair-29adf38.log` | `b83e748845c1c5c1a56d52d528af3f8ee893dd1b240eb675ee72fc691a14f10a` | repeat repair passed |
| `call_center.before-fixed-delete.sql.gz` | `e2fd390559428ddb7f09ae492f6b1611987e64cdee713028e8d74ebf8ef1370e` | full backup integrity passed |
| `remove-delete-db-29adf38.log` | `7f551d1d56c01ad02c8d8f9fbadd3661960e1d919a29a8bb00596ff35b1d48fd` | fixed-commit delete passed |
| `reinstall-clean-db-29adf38.log` | `d306e6bdb37242ea9d8034232611b6d3304a1170ad2590580eb856fd10ada174` | fixed clean install passed |
| `post-clean-29adf38-tests.log` | `5791af710d4fea37b92ab865495c246aef246b93c57ab8a89091ce739bc8dcc0` | native regression/PHP checks passed |

## Retained local-only evidence

Infrastructure screenshots remain outside the public repository under `environment-evidence/`. Their paths and hashes are recorded in the workspace research log; the images are intentionally not committed.

## Limitations

- Exact Issabel media build and FreePBX-derived component versions remain unverified.
- This was an upgrade/repeat/removal/clean-database exercise on a cloned disposable PBX, not a pristine ISO installation.
- No authenticated browser UI, agent, inbound/outbound call-flow, recording, retry/callback, or report workflow has passed. CC5-010 has a rollback-isolated class/database staging cycle and CC5-011 has installed-source request-bootstrap evidence only; no external call was placed.
- The compressed SQL backup has no `CREATE DATABASE` or `USE` statement and was integrity-checked but not restore-rehearsed. Explicit database creation/selection is required for manual import; the Proxmox snapshot is the primary full rollback.
- HTTPS health used the local endpoint with certificate verification disabled; it proves application reachability, not certificate trust.
- The local portable-PHP suite log timestamp predates the recorded `git update-index --chmod=+x` operation and is not used as post-fix proof; fresh Rocky Linux clones at `751a62f` and `29adf38` provide the decisive staging evidence for their respective scenarios.
- No external call will be used as Phase 1 evidence.
