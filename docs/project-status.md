# Project Status

## Current phase

Phase 1 complete; CC5-011 incoming page-migration removal staging verified.

## Active work

- CC5-012 is the next bounded issue: remove the independent privileged outgoing-page lazy schema migrator.

## Completed

- Approved design commits: `02a2e05`, `ee5f7c0`.
- Approved implementation plan commit: `9a7c033`.
- Isolated `develop` worktree created at `.worktrees/issabel5-phase1`; main checkout returned to `master`.
- Owner repository configured at `JoshuaSayo/callcenter-issabel5`; all development and releases remain there unless the user explicitly changes the distribution policy.
- `origin/develop` published through reviewed implementation commit `29adf38` before the final evidence update.
- Staging VM 127 and snapshot `baseline-before-callcenter-work` confirmed by user-supplied evidence.
- Task 1 engineering records completed in commit `b61c1c3`.
- Task 2 secret-safe Issabel baseline collector completed in commit `317adff`.
- Task 3 lifecycle shell primitives completed in commit `2b8c094`.
- Task 4 installer hardening completed and review-clean through commits `ad46168` and `f8aa556`.
- Task 5 PHP failure propagation completed and review-clean through commits `0d47dac` and `afc1ad8`.
- Task 6 removal hardening is review-clean through `8630c2c`.
- Task 7 pre-staging evidence checkpoint recorded: aggregate simulated lifecycle tests, Bash syntax, and Git checks pass locally; Docker engine is unavailable.
- Task 8 authenticated staging validation completed on a fresh clone at `751a62f`: secret-safe baseline, schema/file recovery evidence, two successful local installer runs, repeated service/Asterisk/dialplan/HTTPS/database health, and stable normalized schema equality are recorded in E-P1-009.
- Task 9 keep/delete removal and clean reinstallation completed on snapshot-backed VM 127. The first clean install exposed the canonical URL2/URL3 schema defect; fix `29adf38` passed TDD, independent standards/spec review, native PHP 7.4 regression, repeat repair, final delete/reinstall, semantic schema equality, and independent live verification in E-P1-010.
- CC5-010 completed in `e2e2ba3`: incoming create/update preserve and validate URL1/URL2/URL3, raw form values are not lossy-cast before validation, and update no longer emits debug SQL. Local TDD, native staging PHP 7.4 tests, a rollback-isolated class/database cycle, and independent verification passed in E-CC5-010-S1.
- CC5-011 completed in `2d291bb`: the incoming request path no longer calls or exports its lazy schema/privilege migrator. Executable local RED/GREEN, native staging tests, exact installed-file matching, an installed-source bootstrap check, stable schema/grant fingerprints, and independent verification passed in E-CC5-011-S1.
- Final staging state: Call Center installed; `issabeldialer` enabled/active as `asterisk`; 24 tables with all four URL2/URL3 fields/FKs; `llamada_agendada` loaded; Asterisk 18.19.0; HTTPS `200`; zero routes/calls.

## Known limitations

- Local WSL has no installed distribution; Git Bash 5.3 is the verified local shell-test runtime.
- Docker Desktop is unavailable because its inference manager rejects the Windows user path; portable Windows PHP 7.4.33 provides local unit/syntax evidence only.
- The lifecycle target was a cloned disposable PBX, not a pristine ISO install; no authenticated UI or telephony call-flow was exercised.
- Exact installed Issabel media and FreePBX-derived component versions remain unverified.
- CC5-010 has class/database staging evidence but no authenticated browser UI workflow; PHP 5.4 compatibility is syntax-reviewed rather than runtime-tested.
- The outgoing-campaign page retains an independent privileged lazy schema migrator; CC5-012 tracks it separately. Campaign monitoring also retains a separate legacy configuration parser that was not assessed by CC5-011.

## Exact next action

Remove and regression-test the CC5-012 outgoing page-load schema migrator, then repeat the exact-commit staging fingerprint gate.

## Distribution policy

- Do not open or update pull requests against `ISSABELPBX/callcenter-issabel5`.
- Push changes and publish any future release only in `JoshuaSayo/callcenter-issabel5`.
- The online installer now defaults to the owner repository; use `--local` for an authenticated/private checkout.
- The owner repository is currently a public GitHub fork; a truly private repository requires a separate standalone repository.

## Branch and remotes

- Branch: `develop`
- Fork remote: `origin` → `https://github.com/JoshuaSayo/callcenter-issabel5.git`
- Fetch-only reference: `upstream` → `https://github.com/ISSABELPBX/callcenter-issabel5.git`
- Local push default: `origin`; the `upstream` push URL is disabled.
- Latest owner-repository checkpoint: `2d291bb`
- Latest staging source checkpoint: `2d291bb`
