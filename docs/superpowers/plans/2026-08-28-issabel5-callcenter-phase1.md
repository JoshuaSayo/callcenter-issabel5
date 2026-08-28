# Issabel 5 Call Center Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce an evidence-backed, fail-fast, repeatable install/remove/reinstall lifecycle for the existing Issabel 5 Call Center module on the user's disposable staging clone.

**Architecture:** Preserve the existing Issabel module and dialer layout. Add a small Bash lifecycle-safety library, deterministic command-stub tests, PHP installer result guards, a read-only baseline collector, and durable evidence documents; validate simulated behavior before running the lifecycle on VM 127.

**Tech Stack:** Bash on Rocky Linux 8.8, PHP 7.4, MariaDB/MySQL CLI, systemd, Apache 2.4, Asterisk 18.19, Git/GitHub CLI, and portable shell test scripts without a new production runtime dependency.

**Spec:** `docs/superpowers/specs/2026-08-28-issabel5-callcenter-phase1-design.md`

## Global Constraints

- The media baseline is `issabel5-USB-DVD-x86_64-20240430.iso`.
- The staging target is only Proxmox VM 127, `ISSABEL5CALLCENTERTEST`, at `10.39.188.63`, protected by snapshot `baseline-before-callcenter-work`.
- The verified runtime target is Rocky Linux 8.8, PHP 7.4.33, and Asterisk 18.19.0; exact clone versions remain unverified until Task 8.
- Preserve `install-issabel-callcenter.sh --local`, no-argument GitHub installation, and interactive removal while adding explicit removal flags for automation.
- Do not create trunks, inbound routes, outbound routes, GSM connections, VPN paths, real contacts, or external calls.
- Do not store SSH private keys, passwords, session cookies, database dumps containing records, or private infrastructure screenshots in Git.
- Do not claim a pristine-ISO installation from VM 127; label the final destructive scenario “clean-database removal/reinstallation.”
- Add no production package or service dependency. Test-only Docker use is optional evidence, never a requirement for the PBX.
- Every required failure returns nonzero and suppresses the success banner; optional absence is named explicitly in code and evidence.
- End every task with its listed verification and a small logical commit on `develop`.

---

### Task 1: Establish the fork and durable Phase 1 records

**Files:**
- Create: `docs/project-status.md`
- Create: `docs/issue-register.md`
- Create: `docs/test-evidence.md`
- Create: `docs/compatibility-matrix.md`
- Create: `docs/architecture.md`

**Interfaces:**
- Consumes: approved specification commit `ee5f7c0` on local branch `develop`.
- Produces: fork remote `origin`, upstream remote `upstream`, and five documents consumed by every later task.

- [x] **Step 1: Verify the GitHub identity and fork state**

Run:

```bash
gh api user --jq .login
gh repo view JoshuaSayo/callcenter-issabel5 --json nameWithOwner,defaultBranchRef
```

Expected: login is `JoshuaSayo`. If the second command reports that the repository does not exist, run exactly:

```bash
gh repo fork ISSABELPBX/callcenter-issabel5 --clone=false
gh repo view JoshuaSayo/callcenter-issabel5 --json nameWithOwner,defaultBranchRef
```

Expected: the final command returns `JoshuaSayo/callcenter-issabel5`. Do not create a second repository with another name.

- [x] **Step 2: Configure remotes and publish the design commits**

Run:

```bash
git remote rename origin upstream
git remote add origin https://github.com/JoshuaSayo/callcenter-issabel5.git
git remote -v
git push -u origin develop
```

Expected: `upstream` points to `ISSABELPBX/callcenter-issabel5`, `origin` points to `JoshuaSayo/callcenter-issabel5`, and `develop` tracks `origin/develop`.

- [x] **Step 3: Create the initial records with concrete issue rows**

Use these headings and identifiers:

```markdown
# Project Status

## Current phase
Phase 1 — compatibility, architecture, and lifecycle safety baseline.

## Completed
- Approved design commits: `02a2e05`, `ee5f7c0`.
- Staging VM 127 and snapshot `baseline-before-callcenter-work` confirmed.

## Active
- Installer/remover characterization and fail-fast implementation.

## Blockers
- Key-based SSH access is required before authenticated staging evidence.

## Exact next action
Run the baseline collector tests from Task 2.
```

Create `docs/issue-register.md` with rows `CC5-001` through `CC5-007`: installer false-success, fixed temporary-directory deletion, malformed Asterisk reload, PHP installer swallowed failures, remover false-success/database deletion, exact clone compatibility unverified, and runtime state authority undocumented. Give each row severity, source path and line, observed behavior, intended behavior, implementation state `Open`, and validation state `Unverified`.

Use these exact initial identifiers and severities:

```markdown
| ID | Severity | Component | Initial evidence | Implementation | Validation |
| --- | --- | --- | --- | --- | --- |
| CC5-001 | High | Shell installer | Required commands are unchecked before the completion banner | Open | Unverified |
| CC5-002 | High | Shell installer | Fixed `/usr/src/callcenter` and `/tmp/new_module` trees are recursively removed | Open | Unverified |
| CC5-003 | High | Asterisk reload | `asterisk -rx'core reload'` forms an invalid argument and suppresses failure | Open | Unverified |
| CC5-004 | High | PHP installer | Database and file-operation failures are logged but do not control final exit | Open | Unverified |
| CC5-005 | High | Removal | Required failures are suppressed and database deletion is interactive only | Open | Unverified |
| CC5-006 | High | Compatibility | Exact versions on clone `10.39.188.63` have not been authenticated | Open | Unverified |
| CC5-007 | Medium | Runtime architecture | Authority among memory, database, and Asterisk events is not documented | Open | Unverified |
```

Create `docs/test-evidence.md` with sections `Environment`, `Static`, `Simulated`, `Staging`, `Removal/Reinstallation`, and `Limitations`. Create `docs/compatibility-matrix.md` with separate columns `Documented`, `Observed externally`, and `Verified on clone`. Create `docs/architecture.md` with the process diagram from the specification plus sections for process ownership, persistent state, AMI/AGI boundaries, authoritative state, restart reconciliation, and logs; label every unresolved statement `Hypothesis`.

- [x] **Step 4: Validate the document contract**

Run:

```bash
for file in docs/project-status.md docs/issue-register.md docs/test-evidence.md docs/compatibility-matrix.md docs/architecture.md; do test -s "$file"; done
for id in CC5-001 CC5-002 CC5-003 CC5-004 CC5-005 CC5-006 CC5-007; do grep -q "$id" docs/issue-register.md; done
grep -q 'Exact next action' docs/project-status.md
grep -q 'Hypothesis' docs/architecture.md
```

Expected: exit status `0` from every command.

- [x] **Step 5: Commit**

```bash
git add docs/project-status.md docs/issue-register.md docs/test-evidence.md docs/compatibility-matrix.md docs/architecture.md
git commit -m "docs: establish phase 1 engineering records"
```

### Task 2: Add a secret-safe staging baseline collector

**Files:**
- Create: `tools/collect-issabel-baseline.sh`
- Create: `tests/install/test_helpers.sh`
- Create: `tests/install/test_baseline_collector.sh`
- Create: `tests/install/run.sh`
- Modify: `docs/test-evidence.md`
- Modify: `docs/compatibility-matrix.md`

**Interfaces:**
- Consumes: a root prefix supplied as `CALLCENTER_ROOT` for tests; production default is the real root.
- Produces: newline-delimited `KEY=VALUE` evidence on stdout and nonzero status when a required observation fails.

- [x] **Step 1: Write the failing collector test**

The test helper must export `fail`, `assert_contains`, `assert_not_contains`, `assert_status`, and `make_stub`. The collector test creates a temporary root containing `etc/issabel.conf` with `mysqlrootpwd=collector-secret`, adds deterministic `rpm`, `uname`, `php`, `mysql`, `asterisk`, `httpd`, `systemctl`, and `sha256sum` stubs to `PATH`, and runs:

Implement the helper functions as:

```bash
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "missing text: $2"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || fail "unexpected text: $2"; }
assert_status() { [[ "$1" -eq "$2" ]] || fail "expected status $1, got $2"; }
make_stub() {
    local name="$1" body="$2"
    printf '#!/usr/bin/env bash\n%s\n' "$body" > "$stub_dir/$name"
    chmod +x "$stub_dir/$name"
}
```

```bash
set +e
output="$(CALLCENTER_ROOT="$fixture_root" PATH="$stub_dir:$PATH" bash tools/collect-issabel-baseline.sh 2>&1)"
status=$?
set -e
assert_status 0 "$status"
assert_contains "$output" 'OS_RELEASE=Rocky Linux 8.8 (Green Obsidian)'
assert_contains "$output" 'PHP_VERSION=PHP 7.4.33'
assert_contains "$output" 'ASTERISK_VERSION=Asterisk 18.19.0'
assert_contains "$output" 'CALLCENTER_TABLE_COUNT=27'
assert_not_contains "$output" 'collector-secret'
```

Add a second case whose `asterisk` stub exits `1`; expect nonzero status and `ASTERISK_VERSION=ERROR`, not `UNAVAILABLE`.

- [x] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/install/test_baseline_collector.sh
```

Expected: failure because `tools/collect-issabel-baseline.sh` does not exist.

- [x] **Step 3: Implement the collector with stable keys**

Implement these exact helpers:

```bash
root_path() { printf '%s%s' "${CALLCENTER_ROOT:-}" "$1"; }
one_line() { tr '\r\n' '  ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'; }
required() {
    local key="$1"; shift
    local value
    if value="$("$@" 2>&1)"; then
        printf '%s=%s\n' "$key" "$(printf '%s' "$value" | one_line)"
    else
        printf '%s=ERROR\n' "$key"
        return 1
    fi
}
optional() {
    local key="$1"; shift
    local value
    if value="$("$@" 2>&1)"; then
        printf '%s=%s\n' "$key" "$(printf '%s' "$value" | one_line)"
    else
        printf '%s=UNAVAILABLE\n' "$key"
    fi
}
```

Collect `OS_RELEASE`, `ROCKY_RELEASE_PACKAGE`, `KERNEL`, `PHP_VERSION`, `PHP_MODULES`, `MARIADB_CLIENT_VERSION`, `MARIADB_SERVER_VERSION`, `ASTERISK_VERSION`, `APACHE_VERSION`, `SYSTEMD_VERSION`, `ISSABEL_PACKAGES`, `CALLCENTER_PACKAGES`, `DIALER_ACTIVE`, `DIALER_ENABLED`, `CALLCENTER_TABLE_COUNT`, and SHA-256 checksums for existing service, dialplan, agents, and dashboard files. Require empty `CALLCENTER_ROOT` or an absolute path. Count only `information_schema.tables` rows whose schema is `call_center` and type is `BASE TABLE`. Read `mysqlrootpwd` without printing it, invoke MySQL with `MYSQL_PWD` scoped to that process, then unset the shell variable.

Implement `tests/install/run.sh` as:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for test_file in "$script_dir"/test_*.sh; do bash "$test_file"; done
if [[ -f "$script_dir/test_installer_lib.php" ]]; then
    command -v php >/dev/null || { echo 'ERROR: PHP is required for installer_lib tests' >&2; exit 1; }
    php "$script_dir/test_installer_lib.php"
fi
```

- [x] **Step 4: Run collector tests**

Run:

```bash
bash tests/install/test_baseline_collector.sh
bash -n tools/collect-issabel-baseline.sh tests/install/test_helpers.sh tests/install/test_baseline_collector.sh tests/install/run.sh
```

Expected: both commands exit `0`; test output contains no fixture password.

- [x] **Step 5: Record simulated evidence and commit**

Add the exact commands, exit statuses, and the label `Simulated command-stub evidence; not staging verification` to `docs/test-evidence.md`. Leave clone columns `Unverified` in the compatibility matrix.

```bash
git add tools/collect-issabel-baseline.sh tests/install docs/test-evidence.md docs/compatibility-matrix.md
git commit -m "test: add secret-safe Issabel baseline collector"
```

### Task 3: Introduce shared lifecycle safety primitives

**Files:**
- Create: `build/5.0/lib/callcenter-lifecycle.sh`
- Create: `tests/install/test_lifecycle_common.sh`
- Modify: `tests/install/run.sh`

**Interfaces:**
- Produces: `cc_root_path`, `cc_die`, `cc_require_root`, `cc_run`, `cc_make_temp`, `cc_register_temp`, and `cc_cleanup` for both lifecycle scripts.
- Enforces: `CC_INSTALL_ROOT` is empty for production or an absolute test root; cleanup accepts only registered directories named `issabel-callcenter.*` below rooted `/tmp` or `/usr/src`.

- [ ] **Step 1: Write failing tests for root mapping and cleanup containment**

Test these assertions in separate subshells so `cc_die` cannot end the runner:

```bash
CC_INSTALL_ROOT="$fixture_root"
source build/5.0/lib/callcenter-lifecycle.sh
assert_contains "$(cc_root_path /var/www/html)" "$fixture_root/var/www/html"
cc_make_temp temp_path /tmp test
test -d "$temp_path" || fail 'registered temp directory was not created'
cc_cleanup
test ! -e "$temp_path" || fail 'registered temp directory survived cleanup'
if (cc_register_temp "$fixture_root/etc"); then
    fail 'cleanup registration accepted a non-temporary target'
fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run `bash tests/install/test_lifecycle_common.sh`.

Expected: failure because the library does not exist.

- [ ] **Step 3: Implement the shared library**

Use `set -Eeuo pipefail`, an indexed `CC_TEMP_DIRS` array, and these contracts:

```bash
cc_die() { printf 'ERROR stage=%s message=%s\n' "${CC_STAGE:-unknown}" "$*" >&2; exit 1; }
cc_root_path() { printf '%s%s' "${CC_INSTALL_ROOT:-}" "$1"; }
cc_require_root() {
    if [[ -z "${CC_INSTALL_ROOT:-}" && ${EUID} -ne 0 ]]; then
        cc_die 'installer must run as root'
    fi
}
cc_run() {
    CC_STAGE="$1"; shift
    "$@" || cc_die "command failed: $*"
}
```

`cc_make_temp OUTPUT_VARIABLE ROOTED_PARENT LABEL` must require `LABEL` to match `[A-Za-z0-9_-]+`, create the rooted parent, call `mktemp -d` with template `issabel-callcenter.${LABEL}.XXXXXX`, validate the resulting absolute path against the two allowed parents and prefix `issabel-callcenter.`, register it in the current shell, and assign it with `printf -v "$output_variable" '%s' "$path"`. Do not call it through command substitution because that would lose the registered array in a subshell. `cc_cleanup` iterates only the registered array and runs `rm -rf -- "$path"` after repeating the same validation. Install `trap cc_cleanup EXIT` in each caller, not inside the library. Reject a nonempty `CC_INSTALL_ROOT` unless it is absolute.

- [ ] **Step 4: Verify success and rejection paths**

Run:

```bash
bash tests/install/test_lifecycle_common.sh
bash -n build/5.0/lib/callcenter-lifecycle.sh tests/install/test_lifecycle_common.sh
```

Expected: exit `0`; the sentinel under rooted `/etc` remains present.

- [ ] **Step 5: Commit**

```bash
git add build/5.0/lib/callcenter-lifecycle.sh tests/install/test_lifecycle_common.sh tests/install/run.sh
git commit -m "refactor: add safe lifecycle shell primitives"
```

### Task 4: Make the shell installer fail fast and clean up safely

**Files:**
- Modify: `build/5.0/install-issabel-callcenter.sh`
- Create: `tests/install/test_install_script.sh`
- Modify: `tests/install/run.sh`
- Modify: `docs/issue-register.md`

**Interfaces:**
- Consumes: lifecycle functions from `build/5.0/lib/callcenter-lifecycle.sh`.
- Produces: `main`, `parse_args`, `detect_asterisk_major`, `resolve_source`, `install_modules`, `patch_dashboard`, `install_dialer`, `install_module_metadata`, `run_database_installer`, `configure_service`, `reload_asterisk`, and `post_install_healthcheck`.
- Preserves: no arguments for GitHub mode and `--local`/`-l` for the checked-out repository.

- [ ] **Step 1: Write failing false-success tests**

Build a rooted fixture and command stubs with `tests/install/test_helpers.sh`. The Asterisk stub returns `Asterisk 18.19.0`; `systemctl`, `issabel-menumerge`, `rpm`, `id`, `usermod`, and `chown` succeed unless `FAIL_COMMAND` matches their name. The PHP stub exits `17` when selected. Assert:

```bash
set +e
output="$(CALLCENTER_INSTALL_ROOT="$fixture_root" PATH="$stub_dir:$PATH" FAIL_COMMAND=php \
    bash build/5.0/install-issabel-callcenter.sh --local 2>&1)"
status=$?
set -e
test "$status" -ne 0 || fail 'PHP failure returned success'
assert_contains "$output" 'stage=database-installer'
assert_not_contains "$output" 'installation complete'
```

Repeat for `FAIL_COMMAND=systemctl` during service start. Add a success case whose Asterisk stub records each argument on a separate line and assert the final invocation is exactly two arguments: `-rx` and `core reload`. Add an unknown-argument case expecting status `2` and usage output.

- [ ] **Step 2: Run tests to verify existing failures**

Run `bash tests/install/test_install_script.sh`.

Expected: the PHP and systemd cases fail because the current script prints completion; the Asterisk argument case fails because `-rx'core reload'` forms the wrong argument.

- [ ] **Step 3: Refactor the entry point and preflight**

Source the common library relative to `BASH_SOURCE[0]`, install `trap cc_cleanup EXIT`, and use:

```bash
parse_args() {
    case "${1:-}" in
        '') LOCAL_INSTALL=false ;;
        --local|-l) LOCAL_INSTALL=true ;;
        *) printf 'Usage: %s [--local|-l]\n' "$0" >&2; return 2 ;;
    esac
}

detect_asterisk_major() {
    local output
    output="$(asterisk -rx 'core show version')" || cc_die 'cannot query Asterisk'
    [[ "$output" =~ Asterisk[[:space:]]+([0-9]+) ]] || cc_die 'cannot parse Asterisk version'
    ASTERISK_MAJOR="${BASH_REMATCH[1]}"
}
```

`cc_require_root` runs before mutation. Require `cp`, `chown`, `chmod`, `grep`, `sed`, `php`, `systemctl`, `issabel-menumerge`, and `asterisk`; require `git` only in GitHub mode. Validate `menu.xml`, `modules/`, `setup/installer.php`, `setup/dialer_process/dialer/dialerd`, and `setup/dialer_process/issabeldialer.service` before copying.

- [ ] **Step 4: Root every installed path and use unique temporary directories**

Replace absolute destination literals with `cc_root_path`, remove `/bin/cp`, and create GitHub checkout and module staging through:

```bash
cc_make_temp checkout_dir /usr/src checkout
cc_run source-clone git clone "https://github.com/${GITHUB_ACCOUNT}/callcenter-issabel5.git" "$checkout_dir"
WORK_DIR="$checkout_dir"

cc_make_temp module_stage /tmp module
cp -a "$(cc_root_path /usr/share/issabel/module_installer/callcenter)/." "$module_stage/"
cc_run database-installer php "$module_stage/setup/installer.php"
```

Remove fixed `rm -rf callcenter`, `/tmp/new_module`, and `/usr/src/callcenter` cleanup. Permanent replacement targets remain exact Issabel paths, and each is passed through `cc_root_path` during tests.

- [ ] **Step 5: Stage required operations and health checks**

Each named function sets `CC_STAGE` before its first command. Required copy, ownership, permission, menu merge, PHP, daemon reload, enable, start/restart, and Asterisk reload operations use `cc_run` or an explicit checked conditional. A missing dashboard applet prints `OPTIONAL stage=dashboard reason=not-installed`; a present dashboard that cannot be changed fails.

Implement:

```bash
reload_asterisk() {
    cc_run asterisk-reload asterisk -rx 'core reload'
}

post_install_healthcheck() {
    cc_run dialer-active systemctl is-active --quiet issabeldialer
    cc_run asterisk-health asterisk -rx 'core show version'
    test -x "$(cc_root_path /opt/issabel/dialer/dialerd)" || cc_die 'dialerd is not executable'
}
```

Print `Issabel CallCenter ${RELEASE} installation complete!` only after `post_install_healthcheck` returns success.

- [ ] **Step 6: Run installer tests and syntax checks**

```bash
bash tests/install/test_install_script.sh
bash -n build/5.0/install-issabel-callcenter.sh tests/install/test_install_script.sh
! rg -n "rm -rf (callcenter|/tmp/new_module|/usr/src/callcenter)|asterisk -rx'" build/5.0/install-issabel-callcenter.sh
```

Expected: all exit `0`; simulated failures name the stage and omit completion.

- [ ] **Step 7: Update issue states and commit**

Set `CC5-001`, `CC5-002`, and `CC5-003` to `Implemented / Simulated verified`; retain staging as unverified.

```bash
git add build/5.0/install-issabel-callcenter.sh tests/install/test_install_script.sh tests/install/run.sh docs/issue-register.md
git commit -m "fix: make Issabel installer fail fast"
```

### Task 5: Propagate PHP database and configuration failures

**Files:**
- Create: `setup/installer_lib.php`
- Modify: `setup/installer.php`
- Create: `tests/install/test_installer_lib.php`
- Modify: `tests/install/run.sh`
- Modify: `docs/issue-register.md`

**Interfaces:**
- Produces: `CallCenterInstallException`, `cc_db_query`, `cc_db_first_row`, `cc_db_fetch_table`, `cc_write_file`, and `cc_parse_asterisk_major`.
- Requires: PHP 7.4 on staging; helper syntax remains compatible with the repository's documented PHP 5.4–8.0 range by avoiding scalar and return type declarations.

- [ ] **Step 1: Write the failing PHP helper tests**

Create a self-contained test runner with this fake and assertions:

```php
<?php
require_once __DIR__.'/../../setup/installer_lib.php';

class FakeFailingDB {
    public $errMsg = 'forced database failure';
    public function genQuery($sql) { return false; }
    public function getFirstRowQuery($sql, $assoc, $params) { return false; }
    public function fetchTable($sql, $assoc, $params = array()) { return false; }
}

function expectInstallFailure($callable, $fragment) {
    try { $callable(); }
    catch (CallCenterInstallException $e) {
        if (strpos($e->getMessage(), $fragment) === false) exit(2);
        return;
    }
    exit(3);
}

$db = new FakeFailingDB();
expectInstallFailure(function () use ($db) { cc_db_query($db, 'ALTER TABLE calls ADD x INT'); }, 'forced database failure');
expectInstallFailure(function () { cc_parse_asterisk_major('not a version'); }, 'cannot parse');
if (cc_parse_asterisk_major('Asterisk 18.19.0 built by root') !== 18) exit(4);
echo "PASS installer_lib\n";
```

- [ ] **Step 2: Run to verify the test fails**

Run `php tests/install/test_installer_lib.php` on PHP 7.4 staging or `docker run --rm -v "$PWD:/src" -w /src php:7.4-cli php tests/install/test_installer_lib.php` when Docker is available.

Expected: fatal include error because `setup/installer_lib.php` does not exist.

- [ ] **Step 3: Implement result guards**

Implement each helper so `false` throws `CallCenterInstallException` with operation name plus `$db->errMsg`. `cc_write_file` throws when `file_put_contents` returns `false`. `cc_parse_asterisk_major` accepts only `/Asterisk\s+(\d+)/` and throws for false, empty, or unparsable output.

Required query wrapper shape:

```php
function cc_db_query($db, $sql)
{
    $result = $db->genQuery($sql);
    if ($result === false) {
        throw new CallCenterInstallException('database query failed: '.$db->errMsg);
    }
    return $result;
}
```

- [ ] **Step 4: Make `installer.php` fail as one checked transaction**

Require the library, set `$tmpDir = realpath(dirname(__DIR__))`, and exit nonzero when the source root or `call_center.sql` is missing. Put main execution in `runCallCenterInstaller()` and wrap only the entry call:

```php
try {
    runCallCenterInstaller();
    exit(0);
} catch (Exception $e) {
    fputs(STDERR, "ERROR: Call Center installer failed: ".$e->getMessage()."\n");
    exit(1);
}
```

Replace unchecked direct `genQuery`, `getFirstRowQuery`, `fetchTable`, and `file_put_contents` calls in schema, index, charset, dialplan, and agents configuration paths with the new wrappers. Treat `createNewDatabaseMySQL` return `0` as success and every other value as failure. Remove the default-to-Asterisk-18 behavior: query `core show version`, parse it through `cc_parse_asterisk_major`, and fail if the running version is unavailable.

- [ ] **Step 5: Verify PHP and shell propagation**

Run:

```bash
php -l setup/installer_lib.php
php -l setup/installer.php
php tests/install/test_installer_lib.php
bash tests/install/test_install_script.sh
```

Expected: all exit `0`; the shell test's failing PHP stub still prevents completion.

- [ ] **Step 6: Update evidence and commit**

Set `CC5-004` to `Implemented / PHP 7.4 unit verified` and record the exact PHP version.

```bash
git add setup/installer_lib.php setup/installer.php tests/install/test_installer_lib.php tests/install/run.sh docs/issue-register.md docs/test-evidence.md
git commit -m "fix: propagate Call Center database installer failures"
```

### Task 6: Make removal explicit, testable, and fail fast

**Files:**
- Modify: `build/5.0/remove-issabel-callcenter.sh`
- Create: `tests/install/test_remove_script.sh`
- Modify: `tests/install/run.sh`
- Modify: `docs/issue-register.md`

**Interfaces:**
- Consumes: shared lifecycle library and `CALLCENTER_INSTALL_ROOT` test root.
- Preserves: no-argument interactive prompt.
- Produces: noninteractive `--keep-database` and `--delete-database` modes with verified postconditions.

- [ ] **Step 1: Write failing removal contract tests**

Create rooted module, dialer, systemd, logrotate, tool, module-installer, dashboard, and Asterisk fixture files plus a `call_center` database-state stub. Test:

```bash
output="$(CALLCENTER_INSTALL_ROOT="$fixture_root" PATH="$stub_dir:$PATH" \
    bash build/5.0/remove-issabel-callcenter.sh --keep-database 2>&1)"
assert_contains "$output" 'Call Center Module removed successfully'
test -e "$fixture_root/var/lib/fake-mysql/call_center" || fail 'keep mode deleted database'

CALLCENTER_INSTALL_ROOT="$fixture_root" PATH="$stub_dir:$PATH" \
    bash build/5.0/remove-issabel-callcenter.sh --delete-database
test ! -e "$fixture_root/var/lib/fake-mysql/call_center" || fail 'delete mode retained database'
```

Add `FAIL_COMMAND=issabel-menuremove` and `FAIL_COMMAND=mysql` cases; each must return nonzero and omit the success banner. Add an unknown-argument case expecting status `2`.

- [ ] **Step 2: Run tests to demonstrate false-success behavior**

Run `bash tests/install/test_remove_script.sh`.

Expected: required-command failure cases fail because the current script suppresses errors and prints success; explicit flags are unrecognized.

- [ ] **Step 3: Refactor removal around explicit targets**

Source the lifecycle library, require root, and parse exactly:

```bash
case "${1:-interactive}" in
    interactive) DATABASE_ACTION=prompt ;;
    --keep-database) DATABASE_ACTION=keep ;;
    --delete-database) DATABASE_ACTION=delete ;;
    *) printf 'Usage: %s [--keep-database|--delete-database]\n' "$0" >&2; exit 2 ;;
esac
```

Store the module directory names in this literal Bash array:

```bash
MODULE_DIRS=(
    agent_break agent_console agent_journey agents break_administrator callcenter_config
    calls_detail calls_per_agent calls_per_hour campaign_in campaign_monitoring campaign_out
    cb_extensions client dont_call_list eccp_users external_url form_designer form_list
    graphic_calls hold_time ingoings_calls_success login_logout queues
    rep_agent_information rep_agents_monitoring rep_incoming_calls_monitoring
    rep_incoming_campaigns_panel rep_outgoing_campaigns_panel reports_break rep_trunks_used_per_hour
)
```

The array has 31 exact targets. `remove_tree` accepts only a path produced by `cc_root_path` under `/var/www/html/modules`, `/opt/issabel`, `/var/log`, or `/usr/share/issabel/module_installer`; `remove_file` accepts only the listed systemd, init, logrotate, binary, dashboard icon, and Apache config files. Existing absence is idempotent success; failure to remove a present target is fatal.

- [ ] **Step 4: Check service, menu, dialplan, and database operations**

Stop and disable `issabeldialer` when present, remove its unit, then require `systemctl daemon-reload`. Require dashboard `sed` edits when the file exists, require `issabel-menuremove call_center`, and require Asterisk `dialplan reload` only when the marked context block was removed.

For database deletion, read `mysqlrootpwd` without printing it and run:

```bash
MYSQL_PWD="$mysql_root_password" mysql --batch --skip-column-names \
    -e 'DROP DATABASE IF EXISTS call_center;'
unset mysql_root_password MYSQL_PWD
```

In interactive mode use `read -r -p` and accept only `y`, `Y`, `n`, or `N`; EOF or any other answer returns `2` without touching the database. Postconditions verify service inactivity, listed target absence, context-block absence, and database presence/absence matching the selected action before printing success.

- [ ] **Step 5: Run removal tests and syntax checks**

```bash
bash tests/install/test_remove_script.sh
bash -n build/5.0/remove-issabel-callcenter.sh tests/install/test_remove_script.sh
! rg -n -- "-p\"\$MYSQL_ROOT_PWD\"|2>/dev/null \|\| true" build/5.0/remove-issabel-callcenter.sh
```

Expected: all tests exit `0`; fixture sentinel paths outside the allowlist survive.

- [ ] **Step 6: Update issue state and commit**

Set `CC5-005` to `Implemented / Simulated verified`; retain destructive staging validation as unverified.

```bash
git add build/5.0/remove-issabel-callcenter.sh tests/install/test_remove_script.sh tests/install/run.sh docs/issue-register.md
git commit -m "fix: make Call Center removal explicit and verifiable"
```

### Task 7: Run the complete simulated regression and reconcile documentation

**Files:**
- Modify: `docs/test-evidence.md`
- Modify: `docs/issue-register.md`
- Modify: `docs/project-status.md`
- Modify: `docs/architecture.md`

**Interfaces:**
- Consumes: all shell and PHP tests from Tasks 2–6.
- Produces: one pre-staging evidence checkpoint whose limitations are explicit.

- [ ] **Step 1: Run every locally available check from a clean test state**

```bash
bash tests/install/run.sh
bash -n tools/collect-issabel-baseline.sh build/5.0/lib/callcenter-lifecycle.sh build/5.0/install-issabel-callcenter.sh build/5.0/remove-issabel-callcenter.sh tests/install/*.sh
git diff --check upstream/master...HEAD
git status --short
```

Expected: shell tests and syntax checks exit `0`; only intentional branch changes appear.

- [ ] **Step 2: Run PHP 7.4 checks without changing the PBX**

First run `docker version`. If the engine is available, run:

```bash
docker run --rm -v "$PWD:/src" -w /src php:7.4-cli php -l setup/installer_lib.php
docker run --rm -v "$PWD:/src" -w /src php:7.4-cli php -l setup/installer.php
docker run --rm -v "$PWD:/src" -w /src php:7.4-cli php tests/install/test_installer_lib.php
```

Expected: three successful exits. If the engine or image is unavailable, record exactly `Local PHP 7.4 container check unavailable; Task 8 staging PHP 7.4 checks are required before mutation.` and do not label PHP locally verified.

- [ ] **Step 3: Reconcile architecture and issue evidence**

Add source citations for installer/remover process boundaries, `issabeldialer.service`, `CampaignProcess`, `AMIEventProcess`, `ECCPWorkerProcess`, `SQLWorkerProcess`, and the `call_center` database. Keep authoritative runtime-state conclusions marked `Hypothesis` until later dialer phases. In the issue register, do not mark staging validation complete.

- [ ] **Step 4: Record commands, results, and next action**

In `docs/test-evidence.md`, record command, start time, end time, exit status, decisive output, and evidence label for each check. Set `docs/project-status.md` next action to `Establish key-based SSH access and run the read-only baseline collector on VM 127.`

- [ ] **Step 5: Commit**

```bash
git add docs/test-evidence.md docs/issue-register.md docs/project-status.md docs/architecture.md
git commit -m "docs: record pre-staging lifecycle evidence"
git push origin develop
```

### Task 8: Capture staging baseline and validate upgrade/repeat installation

**Files:**
- Modify: `docs/test-evidence.md`
- Modify: `docs/compatibility-matrix.md`
- Modify: `docs/issue-register.md`
- Modify: `docs/project-status.md`
- Runtime-only, never commit: `C:/Users/Windows 11Pro/Downloads/Issabel 5 - CC/environment-access/issabel-stage*`
- Runtime-only on VM: `/root/callcenter-phase1/`

**Interfaces:**
- Consumes: public `origin/develop`, VM 127, snapshot `baseline-before-callcenter-work`, and a verified root SSH key.
- Produces: exact clone versions, schema-only backup, two successful installer logs, and post-install health evidence.

- [ ] **Step 1: Create a dedicated SSH key outside the repository**

Run in PowerShell:

```powershell
New-Item -ItemType Directory -Force -Path 'C:\Users\Windows 11Pro\Downloads\Issabel 5 - CC\environment-access'
ssh-keygen.exe -t ed25519 -f 'C:\Users\Windows 11Pro\Downloads\Issabel 5 - CC\environment-access\issabel-stage' -N '' -C 'codex-issabel-stage-2026-08-28'
```

Have the user add only `issabel-stage.pub` to root's `authorized_keys` through the Proxmox console. Never request or transmit a password in chat.

- [ ] **Step 2: Verify the host key and noninteractive access**

On the Proxmox console run `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` and compare it to the fingerprint obtained from `ssh-keyscan -t ed25519 10.39.188.63`. After the fingerprints match, run:

```powershell
ssh.exe -i 'C:\Users\Windows 11Pro\Downloads\Issabel 5 - CC\environment-access\issabel-stage' -o BatchMode=yes root@10.39.188.63 'id -u; hostname'
```

Expected: UID `0` and the clone hostname. If root key access is unavailable, stop without trying passwords or other usernames.

- [ ] **Step 3: Fetch the exact reviewed branch into a new staging path**

Run over SSH:

```bash
test ! -e /usr/src/callcenter-issabel5-develop
git clone --branch develop --single-branch https://github.com/JoshuaSayo/callcenter-issabel5.git /usr/src/callcenter-issabel5-develop
cd /usr/src/callcenter-issabel5-develop
git rev-parse HEAD
git status --short
```

Expected: the published `develop` commit and an empty status. Do not remove or reuse an existing path.

- [ ] **Step 4: Run pre-mutation tests and baseline collection**

```bash
cd /usr/src/callcenter-issabel5-develop
bash tests/install/run.sh
php -l setup/installer_lib.php
php -l setup/installer.php
install -d -m 700 /root/callcenter-phase1
bash tools/collect-issabel-baseline.sh > /root/callcenter-phase1/baseline.env
chmod 600 /root/callcenter-phase1/baseline.env
sha256sum /root/callcenter-phase1/baseline.env
```

Expected: all tests and syntax checks pass; the baseline contains all required keys and no `mysqlrootpwd` value.

- [ ] **Step 5: Create schema-only and file-state recovery evidence**

```bash
mysql_root_password="$(awk -F= '$1=="mysqlrootpwd" {print substr($0,index($0,"=")+1); exit}' /etc/issabel.conf)"
test -n "$mysql_root_password"
MYSQL_PWD="$mysql_root_password" mysqldump --no-data --routines --triggers call_center > /root/callcenter-phase1/call_center-schema-before.sql
unset mysql_root_password MYSQL_PWD
chmod 600 /root/callcenter-phase1/call_center-schema-before.sql
sha256sum /root/callcenter-phase1/call_center-schema-before.sql
find /var/www/html/modules /opt/issabel/dialer /usr/share/issabel/module_installer/callcenter -xdev -printf '%p|%u|%g|%m|%s\n' 2>/dev/null | sort > /root/callcenter-phase1/files-before.txt
sha256sum /root/callcenter-phase1/files-before.txt
```

Expected: schema backup is nonempty and contains no table rows; state files remain mode `600` under `/root`.

- [ ] **Step 6: Execute the first upgrade/repeat install**

```bash
cd /usr/src/callcenter-issabel5-develop
set -o pipefail
bash build/5.0/install-issabel-callcenter.sh --local 2>&1 | tee /root/callcenter-phase1/install-1.log
test "${PIPESTATUS[0]}" -eq 0
```

Expected: completion appears once after all health checks; log contains no password.

- [ ] **Step 7: Verify runtime and database health without placing a call**

```bash
systemctl is-enabled --quiet issabeldialer
systemctl is-active --quiet issabeldialer
asterisk -rx 'core show version'
asterisk -rx 'dialplan show llamada_agendada'
test -x /opt/issabel/dialer/dialerd
test -f /var/www/html/modules/agent_console/index.php
curl --insecure --silent --show-error --output /dev/null --write-out '%{http_code}\n' https://127.0.0.1/
mysql_root_password="$(awk -F= '$1=="mysqlrootpwd" {print substr($0,index($0,"=")+1); exit}' /etc/issabel.conf)"
MYSQL_PWD="$mysql_root_password" mysql --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='call_center' AND table_type='BASE TABLE';"
unset mysql_root_password MYSQL_PWD
```

Expected: service enabled and active, Asterisk 18.19.0, dialplan context present, HTTPS `200`, and table count greater than zero.

- [ ] **Step 8: Execute and verify the immediate repeat install**

Repeat Step 6 to `/root/callcenter-phase1/install-2.log`, then repeat Step 7. Compare schema fingerprints before and after with normalized `mysqldump --no-data`; explain any intended idempotent metadata difference.

- [ ] **Step 9: Record evidence and commit**

Back on the local workstation, copy only version lines, checksums, table counts, exit statuses, and health results into the durable documents. Set `CC5-006` to `Staging verified` only for versions actually observed on the clone. Run the following Git commands in the local repository, not the VM clone.

```bash
git add docs/test-evidence.md docs/compatibility-matrix.md docs/issue-register.md docs/project-status.md
git commit -m "docs: record Issabel staging upgrade evidence"
git push origin develop
```

### Task 9: Validate removal, clean-database reinstallation, and Phase 1 closure

**Files:**
- Modify: `docs/test-evidence.md`
- Modify: `docs/issue-register.md`
- Modify: `docs/project-status.md`
- Modify: `docs/compatibility-matrix.md`

**Interfaces:**
- Consumes: successful Task 8 state, the verified snapshot, and the user-authorized removal script.
- Produces: keep-database removal evidence, delete-database removal evidence, final reinstalled service, reviewable commits, and a draft PR.

- [ ] **Step 1: Reconfirm exact destructive target and rollback**

Verify in Proxmox that snapshot `baseline-before-callcenter-work` still exists for VM 127. On the VM run:

```bash
mysql_root_password="$(awk -F= '$1=="mysqlrootpwd" {print substr($0,index($0,"=")+1); exit}' /etc/issabel.conf)"
MYSQL_PWD="$mysql_root_password" mysql --batch --skip-column-names -e "SHOW DATABASES LIKE 'call_center';"
unset mysql_root_password MYSQL_PWD
```

Expected: exactly `call_center`. Do not run a database deletion if the resolved VM, database name, or snapshot differs.

- [ ] **Step 2: Test removal while preserving the database**

```bash
cd /usr/src/callcenter-issabel5-develop
set -o pipefail
bash build/5.0/remove-issabel-callcenter.sh --keep-database 2>&1 | tee /root/callcenter-phase1/remove-keep-db.log
test "${PIPESTATUS[0]}" -eq 0
test ! -e /opt/issabel/dialer/dialerd
test ! -e /var/www/html/modules/agent_console
! systemctl is-active --quiet issabeldialer
mysql_root_password="$(awk -F= '$1=="mysqlrootpwd" {print substr($0,index($0,"=")+1); exit}' /etc/issabel.conf)"
MYSQL_PWD="$mysql_root_password" mysql --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='call_center' AND table_type='BASE TABLE';"
unset mysql_root_password MYSQL_PWD
```

Expected: files and service are absent; database table count remains greater than zero.

- [ ] **Step 3: Reinstall after keep-database removal**

Run the Task 8 installer command to `/root/callcenter-phase1/reinstall-keep-db.log`, require status `0`, and repeat all Task 8 health checks.

- [ ] **Step 4: Test removal including the exact database**

```bash
set -o pipefail
bash build/5.0/remove-issabel-callcenter.sh --delete-database 2>&1 | tee /root/callcenter-phase1/remove-delete-db.log
test "${PIPESTATUS[0]}" -eq 0
mysql_root_password="$(awk -F= '$1=="mysqlrootpwd" {print substr($0,index($0,"=")+1); exit}' /etc/issabel.conf)"
remaining="$(MYSQL_PWD="$mysql_root_password" mysql --batch --skip-column-names -e "SHOW DATABASES LIKE 'call_center';")"
unset mysql_root_password MYSQL_PWD
test -z "$remaining"
```

Expected: only `call_center` is deleted; remover completion follows verified absence.

- [ ] **Step 5: Reinstall into the clean-database state and leave the module running**

Run the installer to `/root/callcenter-phase1/reinstall-clean-db.log` and repeat Task 8 health checks. Compare the database table count with `grep -Ec '^CREATE TABLE ' setup/call_center.sql`; investigate and record any difference before success. Leave `issabeldialer` enabled and active.

- [ ] **Step 6: Run final regression and inspect the branch**

Run the Bash and PHP commands on VM 127. Run the Git diff, status, and log commands in the local repository after applying the evidence-document edits.

```bash
bash tests/install/run.sh
php -l setup/installer_lib.php
php -l setup/installer.php
git diff --check upstream/master...HEAD
git status --short
git log --oneline --decorate upstream/master..HEAD
```

Expected: tests and syntax pass, status contains only the evidence-document edits for this task, and history is ordered into small logical commits.

- [ ] **Step 7: Close Phase 1 records and commit**

Back on the local workstation, record all six lifecycle logs by VM path and SHA-256, not by committing the logs. Mark lifecycle issues staging verified only when their matching commands passed. Set current status to `Phase 1 complete — reviewable`, limitations to include `not a pristine ISO install` and `no call-flow validation`, and exact next action to `Review the Phase 1 draft PR and select the next focused subsystem design.` Run the following Git commands in the local repository.

```bash
git add docs/test-evidence.md docs/issue-register.md docs/project-status.md docs/compatibility-matrix.md
git commit -m "docs: close phase 1 staging validation"
git push origin develop
```

- [ ] **Step 8: Open a draft pull request without merging**

First check for an existing open pull request from the same branch:

```bash
existing_pr="$(gh pr list --repo ISSABELPBX/callcenter-issabel5 --head JoshuaSayo:develop --state open --json url --jq '.[0].url // empty')"
```

If `existing_pr` is empty, run:

```bash
gh pr create --repo ISSABELPBX/callcenter-issabel5 --base master --head JoshuaSayo:develop --draft --title "Phase 1: harden Issabel 5 Call Center lifecycle" --body "Adds fail-fast install/remove behavior, secret-safe baseline evidence, PHP database error propagation, simulated tests, and snapshot-backed Issabel 5 staging validation. This phase does not claim pristine-ISO installation or call-flow validation."
```

If `existing_pr` is nonempty, run:

```bash
gh pr edit "$existing_pr" --title "Phase 1: harden Issabel 5 Call Center lifecycle" --body "Adds fail-fast install/remove behavior, secret-safe baseline evidence, PHP database error propagation, simulated tests, and snapshot-backed Issabel 5 staging validation. This phase does not claim pristine-ISO installation or call-flow validation."
```

Expected: exactly one open draft PR URL for `JoshuaSayo:develop`. Do not mark ready, merge, or publish a release.
