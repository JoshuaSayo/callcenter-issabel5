# Project Status

## Current phase

Phase 1 complete — reviewable.

## Completed

- Approved design commits: `02a2e05`, `ee5f7c0`.
- Approved implementation plan commit: `9a7c033`.
- Isolated `develop` worktree created at `.worktrees/issabel5-phase1`; main checkout returned to `master`.
- Fork created at `JoshuaSayo/callcenter-issabel5`; `origin` is the fork and `upstream` is `ISSABELPBX/callcenter-issabel5`.
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
- Final staging state: Call Center installed; `issabeldialer` enabled/active as `asterisk`; 24 tables with all four URL2/URL3 fields/FKs; `llamada_agendada` loaded; Asterisk 18.19.0; HTTPS `200`; zero routes/calls.

## Known limitations

- Local WSL has no installed distribution; Git Bash 5.3 is the verified local shell-test runtime.
- Docker Desktop is unavailable because its inference manager rejects the Windows user path; portable Windows PHP 7.4.33 provides local unit/syntax evidence only.
- The lifecycle target was a cloned disposable PBX, not a pristine ISO install; no authenticated UI or telephony call-flow was exercised.
- Exact installed Issabel media and FreePBX-derived component versions remain unverified.
- Incoming campaign URL2/URL3 creation has a separate recorded signature defect for the later campaign phase.

## Exact next action

Review the Phase 1 draft pull request and select the next focused subsystem design.

## Branch and remotes

- Branch: `develop`
- Fork remote: `origin` → `https://github.com/JoshuaSayo/callcenter-issabel5.git`
- Read-only upstream convention: `upstream` → `https://github.com/ISSABELPBX/callcenter-issabel5.git`
- Latest staging source checkpoint: `29adf38`
