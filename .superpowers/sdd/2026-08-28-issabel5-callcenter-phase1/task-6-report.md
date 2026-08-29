# Task 6 Report

## Implementation summary

- Replaced the legacy best-effort remover with a strict lifecycle-backed script rooted through `CALLCENTER_INSTALL_ROOT` -> `CC_INSTALL_ROOT` for simulation and the real `/` root in production.
- Added exact `--keep-database`, `--delete-database`, and preserved no-argument interactive modes; unknown/multiple arguments and invalid/EOF interactive database input exit `2`.
- Added the required literal 31-module array, four accepted tree roots, and exact systemd/init/logrotate/tool/dashboard/Apache file allowlists. Present targets must disappear; absent targets are idempotent success.
- Made service stop/disable, daemon reload, dashboard edits, menu removal, conditional dialplan reload, database mutation, and postcondition query fail fast.
- Removed the database password from argv and diagnostics. Both valid database actions use `MYSQL_PWD` with `--batch --skip-column-names`; delete runs the required `DROP DATABASE IF EXISTS`, and both modes actively verify `SHOW DATABASES LIKE 'call_center'` before success.
- Added rooted removal contract tests with real fixture removal and external-boundary stubs only for systemd, Issabel menu, Asterisk, and MySQL. Added containment sentinels outside every accepted tree root and beside every exact file target.
- Updated the aggregate runner to skip the sourced helper artifact and updated CC5-005 to `Implemented` / `Simulated verified; destructive staging unverified`.

## Files changed

- `build/5.0/remove-issabel-callcenter.sh`
- `tests/install/test_remove_script.sh` (created)
- `tests/install/run.sh`
- `docs/issue-register.md`
- `.superpowers/sdd/2026-08-28-issabel5-callcenter-phase1/task-6-report.md` (this ignored coordination report)

## Strict TDD RED evidence

- The removal contract test and runner wiring were created before any production edit.
- An initial attempt exited `1` with `tests/install/test_remove_script.sh: line 192: status: unbound variable`. This was a test-helper scoping error, not a valid production RED, so only the helper was corrected before rerunning.
- Valid baseline RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh`.
- Valid baseline RED exit: `1`.
- Valid baseline RED output: `FAIL: module retained: agent_break`.
- Expected reason: the unchanged remover ignored `CALLCENTER_INSTALL_ROOT` and did not remove the rooted module fixtures.
- Focused explicit-argument RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_unknown_argument_exits_two_without_changes`.
- Exit/output: `1`; `FAIL: expected status 2, got 0`.
- Focused menu false-success RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_required_menu_failure_is_fatal`.
- Exit/output: `1`; `FAIL: menu failure returned success`.
- Focused MySQL false-success RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_required_database_failure_is_fatal`.
- Exit/output: `1`; `FAIL: database failure returned success`.
- After the controller appended the active database-query ruling, the test was extended before production edits and run with `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_keep_database_removes_only_allowlisted_targets`.
- Exit/output: `1`; `FAIL: keep mode did not verify database state`.

## GREEN and final verification

- Focused GREEN command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh`.
- Focused GREEN result: exit `0`; `PASS test_remove_script`.
- Syntax command: `C:\Program Files\Git\bin\bash.exe -n build/5.0/remove-issabel-callcenter.sh tests/install/test_remove_script.sh`.
- Syntax result: exit `0`; no output.
- Forbidden-pattern command: `! rg -n -- "-p\"\$MYSQL_ROOT_PWD\"|2>/dev/null \|\| true" build/5.0/remove-issabel-callcenter.sh` (executed with equivalent PowerShell exit handling).
- Forbidden-pattern result: exit `0`; no matches and no output.
- Whitespace command: `git diff --check`.
- Whitespace result: exit `0`; only Git's configured LF-to-CRLF working-copy warnings, with no whitespace errors.
- Aggregate command: `$phpDir = (Resolve-Path -LiteralPath '.superpowers/sdd/2026-08-28-issabel5-callcenter-phase1/runtime/php-7.4.33').Path; $env:PATH = "$phpDir;$env:PATH"; & 'C:\Program Files\Git\bin\bash.exe' tests/install/run.sh`.
- Aggregate result: exit `0` with:

```text
PASS test_baseline_collector
PASS: installer behavior tests
PASS test_lifecycle_common
PASS test_remove_script
PASS installer_lib
PASS installer_entry
```

## Test mutation coverage

- Removing or misspelling any of the 31 module targets leaves a real fixture directory and fails the absence assertion.
- Broadening a tree removal to a parent root removes a sentinel outside that accepted root and fails containment; changing an exact file target removes a sibling sentinel and fails containment.
- Omitting service stop/disable, daemon reload, menu removal, dashboard edits, context removal, or the conditional dialplan reload leaves a real fixture/state postcondition and fails.
- Reloading Asterisk without first removing a marked block hits the deliberately failing Asterisk boundary in the no-context test and fails.
- Deleting in keep mode or omitting the delete-mode DROP produces the wrong fake database state; the active `SHOW DATABASES` result check and filesystem assertion fail.
- Omitting the postcondition query fails the `database-state-checked` assertion. Wrong MySQL flags, SQL, or password transport make the strict boundary stub return nonzero; password disclosure fails output assertions.
- Swallowing `issabel-menuremove` or MySQL failures returns zero and/or prints the success banner, which the focused failure cases reject.
- Accepting an unknown argument or invalid/EOF interactive input fails the exact exit-`2`, no-success, no-MySQL, and database-survival assertions.
- Making absent targets fatal fails the second removal in the idempotency test.

## Self-review

- Allowlists: `MODULE_DIRS` is the controller-supplied literal 31-name array. `remove_tree` accepts only descendants of the four rooted tree prefixes and rejects traversal components; `remove_file` accepts only the seven rooted exact file targets. Tests prove ten outside/sibling sentinels survive.
- Database secrets: `mysqlrootpwd` is read with Bash input handling only after a valid database choice. It is never printed or passed via `-p`; `MYSQL_PWD` is scoped to each MySQL process and secret variables are unset before all database failure exits and after the postcondition query.
- Prompt/exit behavior: no argument preserves `read -r -p`; only `y`, `Y`, `n`, and `N` are accepted. Unknown/multiple CLI arguments and invalid/EOF prompt input exit `2`; required operation failures exit nonzero through lifecycle errors; only fully verified runs print success.
- Idempotency: removals check existence, accept absence, and still require daemon/menu/database/service postconditions. The same rooted keep-mode removal passes twice while the database and all containment sentinels survive.
- Scope: `git status --short` before commit showed only the four brief-authorized files. No PBX or staging remover was executed, and no unrelated worktree changes were present or modified.

## Concerns

- Verification is rooted Git Bash simulation with stateful external-boundary stubs plus the repository aggregate suite. No destructive operation was run on the PBX.
- Real Rocky Linux systemd, Issabel menu, Asterisk, MariaDB, filesystem ownership/permissions, and destructive removal remain staging-unverified and are explicitly deferred to Task 9.

## Commit

- `431d8e3` — `fix: make Call Center removal explicit and verifiable`.
- Staged scope was exactly the four brief-authorized files; `git diff --cached --check` exited `0` before commit.
- Post-commit `git status --short`: empty.

## Fix Round 1

### Changes

- Canonical containment now validates the resolved parent of every tree and exact-file target against its lexical rooted parent before deletion. Real intermediate symlink/junction escape attempts through `/opt/issabel` and `/etc/systemd/system` fail before either outside sentinel is removed.
- Dialplan deletion now requires exactly one BEGIN and one END marker with BEGIN on an earlier line. Unmatched, reversed, and duplicate marker states fail before editing or Asterisk reload; unrelated dialplan content remains intact.
- Systemd queries now classify recognized state text together with documented exit status. Active/enabled states are handled, inactive/disabled/not-found states are accepted as non-active/non-enabled, and unexpected operational errors are fatal. Documented status-0 `static`, `indirect`, and `generated` unit-file states remain compatible.
- Dialplan grep status `1` remains normal absence; any other grep failure is fatal at both pre-edit validation and the final marker postcondition.
- Scope is limited to `build/5.0/remove-issabel-callcenter.sh` and `tests/install/test_remove_script.sh`.

### Finding 1 — canonical containment RED → GREEN

- An initial native-link attempt was excluded because Windows returned `ln: failed to create symbolic link ...: Operation not permitted`; production was unchanged. The test harness was corrected to use a real Windows directory junction fallback and detach it safely before cleanup.
- Valid RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_symlink_escape_targets_are_rejected`.
- Valid RED result: exit `1`; `FAIL: tree symlink escape returned success`.
- GREEN command: identical to RED.
- GREEN result: exit `0`; `PASS test_remove_script` after adding canonical-parent validation to both removal helpers.
- Complete focused removal suite after the fix: exit `0`; `PASS test_remove_script`.

### Finding 2 — paired dialplan markers RED → GREEN

- RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_malformed_dialplan_markers_fail_without_editing`.
- RED result: exit `1`; `FAIL: unmatched BEGIN deleted unrelated dialplan content`.
- Initial GREEN result: exit `0`; `PASS test_remove_script` after rejecting unmatched BEGIN/END before `sed`.
- The paired-block self-review then added reversed/duplicate real-file cases before strengthening production. Strengthened RED result: exit `1`; `FAIL: reversed markers deleted unrelated dialplan content`.
- Strengthened GREEN command: the same focused malformed-marker command.
- Strengthened GREEN result: exit `0`; `PASS test_remove_script` after requiring exactly one ordered marker pair; the focused grep-error case also remained exit `0`.
- Complete focused removal suite after the fix: exit `0`; `PASS test_remove_script`.

### Finding 3 — systemd query errors RED → GREEN

- RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_systemd_query_errors_are_fatal`.
- Valid RED result: exit `1`; `FAIL: active-query error changed active service state`.
- A test-stub refinement initially produced an invalid pass because a single-quoted glob terminated the single-quoted stub body, causing a stub syntax error. The quoting was corrected test-only and the same valid RED was reconfirmed before production edits.
- The first production attempt also produced an invalid GREEN because a multiline Bash `case` pattern had a bare trailing `|`; the normal keep case exposed exit `2` and `syntax error near unexpected token 'newline'`. The syntax was corrected before accepting evidence.
- Corrected GREEN commands: the focused query-error test plus `test_keep_database_removes_only_allowlisted_targets`.
- Corrected GREEN results: both exit `0`; each prints `PASS test_remove_script`.
- Compatibility RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_systemd_expected_states_are_accepted`.
- Compatibility RED result: exit `1`; `FAIL: expected status 0, got 1` for documented status-0 `static`.
- Compatibility GREEN result: exit `0`; `PASS test_remove_script`; the query-error case also remained exit `0`.
- Complete focused removal suite after the fix: exit `0`; `PASS test_remove_script`.

### Finding 4 — dialplan query errors RED → GREEN

- Test fault injection delegates all normal grep operations to `/usr/bin/grep` and returns status `2` only for the rooted Asterisk file under explicit `FAIL_COMMAND=grep:dialplan`. Assertions cover the real dialplan file, process exit, reload state, and success banner rather than the wrapper.
- RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_dialplan_query_error_is_fatal_without_editing`.
- RED result: exit `1`; `FAIL: dialplan query error returned success`.
- GREEN command: identical to RED.
- GREEN result: exit `0`; `PASS test_remove_script` after distinguishing grep status `1` from all query errors at pre-edit and postcondition checks.
- Complete focused removal suite after all fixes: exit `0`; `PASS test_remove_script`.

### Final verification

- Syntax command: `C:\Program Files\Git\bin\bash.exe -n build/5.0/remove-issabel-callcenter.sh tests/install/test_remove_script.sh`.
- Syntax result: exit `0`; no output.
- Forbidden-pattern command: `! rg -n -- "-p\"\$MYSQL_ROOT_PWD\"|2>/dev/null \|\| true" build/5.0/remove-issabel-callcenter.sh` (executed with equivalent PowerShell exit handling).
- Forbidden-pattern result: exit `0`; no output.
- Aggregate command: `$phpDir = (Resolve-Path -LiteralPath '.superpowers/sdd/2026-08-28-issabel5-callcenter-phase1/runtime/php-7.4.33').Path; $env:PATH = "$phpDir;$env:PATH"; & 'C:\Program Files\Git\bin\bash.exe' tests/install/run.sh`.
- Aggregate result: exit `0` with pristine output:

```text
PASS test_baseline_collector
PASS: installer behavior tests
PASS test_lifecycle_common
PASS test_remove_script
PASS installer_lib
PASS installer_entry
```

### Fix-round self-review

- Containment: canonical-parent comparison rejects a symlinked `CALLCENTER_INSTALL_ROOT` or any intermediate parent component for both tree and exact-file targets. Tests use real links/junctions, prove nonzero/no success, detach safely, and verify both outside sentinels survive.
- Dialplan safety: validation is read-only until one unique ordered pair is proven. BEGIN-only, END-only, reversed, duplicate, and grep-error fixtures retain unrelated content and never reload Asterisk.
- Systemd safety/compatibility: recognized stdout and status pairs are explicit; status `41` query faults cannot masquerade as inactive/disabled. Rocky-compatible inactive `3`, disabled `1`, not-found `4`, and status-0 static-like states are covered without weakening unexpected-error rejection.
- Mutation coverage: removing canonical validation deletes an outside sentinel; weakening pair count/order deletes or edits malformed fixtures; treating arbitrary nonzero systemd/grep status as absence returns success and/or changes service state; narrowing the documented systemd state whitelist breaks the static compatibility case.
- Scope: only the remover and its existing focused test changed. Database allowlists/secrets, explicit modes, prompt/exit behavior, idempotency, issue state, and unrelated files remain unchanged.

### Fix-round concerns

- Native Unix symlinks are used where available; this Windows host uses real NTFS directory junctions as the equivalent intermediate-resolution escape. Both are verified through `realpath` before the test runs the remover.
- Verification remains rooted simulation. Real Rocky Linux 8.8 systemd/D-Bus, Asterisk, MariaDB, filesystem permissions, and destructive PBX removal remain staging-unverified for Task 9.

### Fix Round 1 commit

- `e44a183` — `fix: harden Call Center removal safety checks`.
- Staged scope was exactly the remover and its focused test; `git diff --cached --check` exited `0` before commit.
- Post-commit `git status --short`: empty.

## Fix Round 2

### Changes

- Aligned `systemctl is-enabled` handling with target systemd v239: status-0 enabled/enabled-runtime/static/indirect/generated states require service handling; status-1 linked/linked-runtime states still represent a present unit and require disable; disabled/transient/masked states remain absence of enablement.
- Forced `LC_ALL=C` for the `is-enabled` query and accepted only the exact v239 missing-unit diagnostic/status pair as absence. Other systemctl diagnostics and unexpected status/state combinations remain fatal.
- Removed impossible target-version `0:linked`, `0:linked-runtime`, `0:alias`, status-1 static-like, and synthetic `*:not-found` pairs plus the synthetic not-found test.
- Added focused v239 linked-presence and missing-unit second-removal behavior tests. The missing diagnostic is emitted on stderr with exit `1` and the stub requires C locale.

### Strict TDD RED

- Linked-state RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_systemd_v239_linked_state_is_present`.
- Linked-state RED result: exit `1`; `FAIL: expected status 0, got 1`.
- Expected reason: the previous whitelist rejected the real v239 `1:linked` state instead of stopping/disabling the present unit.
- Missing-unit RED command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh test_systemd_v239_missing_unit_keeps_second_removal_idempotent`.
- Missing-unit RED result: exit `1`; `FAIL: expected status 0, got 1` on the second removal.
- The missing-unit boundary was strengthened test-only to require `LC_ALL=C`; rerunning the same command remained RED with exit `1` and `FAIL: expected status 0, got 1` before production edits.
- Expected reason: the previous whitelist accepted only synthetic `*:not-found` stdout and rejected v239's `Failed to get unit file state for issabeldialer.service: No such file or directory` stderr/status pair.

### GREEN and final verification

- Focused GREEN commands: the linked-state test, missing-unit idempotency test, operational-query-error test, and v239 static-state test.
- Focused GREEN results: all four exit `0`; each prints `PASS test_remove_script`.
- Full removal command: `C:\Program Files\Git\bin\bash.exe tests/install/test_remove_script.sh`.
- Full removal result: exit `0`; `PASS test_remove_script`.
- Syntax command: `C:\Program Files\Git\bin\bash.exe -n build/5.0/remove-issabel-callcenter.sh tests/install/test_remove_script.sh`.
- Syntax result: exit `0`; no output.
- Forbidden-pattern command: `! rg -n -- "-p\"\$MYSQL_ROOT_PWD\"|2>/dev/null \|\| true" build/5.0/remove-issabel-callcenter.sh` (executed with equivalent PowerShell exit handling).
- Forbidden-pattern result: exit `0`; no output.
- Aggregate command: `$phpDir = (Resolve-Path -LiteralPath '.superpowers/sdd/2026-08-28-issabel5-callcenter-phase1/runtime/php-7.4.33').Path; $env:PATH = "$phpDir;$env:PATH"; & 'C:\Program Files\Git\bin\bash.exe' tests/install/run.sh`.
- Aggregate result: exit `0` with pristine output:

```text
PASS test_baseline_collector
PASS: installer behavior tests
PASS test_lifecycle_common
PASS test_remove_script
PASS installer_lib
PASS installer_entry
```

### Fix-round self-review

- v239 state model: only states verified as status `0` in v239 are in the first branch. `linked` and `linked-runtime` are accepted only with status `1` and deliberately return “present” so stop/disable runs.
- Missing unit: the exact C-locale `No such file or directory` diagnostic for the mangled `issabeldialer.service` name returns absence. Permission, D-Bus, malformed-unit, unexpected locale/state, and injected status-41 errors do not match and remain fatal.
- Idempotency: the new test completes one real rooted removal, then simulates the v239 missing-unit response on the second run and verifies exit `0`, success, database survival, and containment sentinel survival.
- Mutation coverage: restoring `0:linked` or omitting `1:linked` fails the linked case; removing C locale or the exact missing diagnostic fails second-run idempotency; broadly accepting arbitrary status `1` would be caught by the existing operational-error test.
- Scope: production and tests change only systemd v239 state handling. Removal allowlists, canonical containment, dialplan validation, database secrets, prompt/exit behavior, and unrelated files are unchanged.

### Fix-round concerns

- The state/diagnostic contract is simulated from controller-verified systemd v239 source; real Rocky Linux 8.8 D-Bus/systemctl and destructive PBX removal remain staging-unverified for Task 9.

### Fix Round 2 commit

- Included in the separate code/test/report commit `fix: align removal with systemd 239 states`; the final hash is reported externally because this report is part of that commit.
