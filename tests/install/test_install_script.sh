#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source "$script_dir/test_helpers.sh"

fixture_root=''
stub_dir=''

cleanup() {
    [[ -n "$fixture_root" ]] && rm -rf -- "$fixture_root"
}
trap cleanup EXIT

make_fixture() {
    fixture_root="$(mktemp -d)"
    stub_dir="$fixture_root/stubs"
    mkdir -p "$stub_dir" \
        "$fixture_root/var/www/html/modules" \
        "$fixture_root/var/log" \
        "$fixture_root/opt/issabel" \
        "$fixture_root/etc/systemd/system" \
        "$fixture_root/etc/logrotate.d" \
        "$fixture_root/usr/bin" \
        "$fixture_root/usr/share/issabel/module_installer/callcenter" \
        "$fixture_root/usr/src" \
        "$fixture_root/tmp"
    mkdir "$fixture_root/tmp/issabel-callcenter.sentinel"

    make_stub asterisk '
if [[ "${FAIL_COMMAND:-}" == asterisk && "${2:-}" == "core reload" ]]; then exit 44; fi
if [[ -n "${ASTERISK_ARGS_FILE:-}" && "${2:-}" == "core reload" ]]; then printf "%s\\n" "$@" > "$ASTERISK_ARGS_FILE"; fi
printf "%s\\n" "${ASTERISK_OUTPUT:-Asterisk 18.19.0}"
'
    make_stub systemctl '
case "${1:-}" in
    is-active) [[ -f "${SYSTEMCTL_STATE_FILE:?}" ]] && exit 0; exit 1 ;;
    start) [[ "${FAIL_COMMAND:-}" == systemctl ]] && exit 45; touch "${SYSTEMCTL_STATE_FILE:?}"; exit 0 ;;
    restart) touch "${SYSTEMCTL_STATE_FILE:?}"; exit 0 ;;
esac
exit 0
'
    make_stub issabel-menumerge '[[ "${FAIL_COMMAND:-}" == issabel-menumerge ]] && exit 46; exit 0'
    make_stub php '
if [[ "${FAIL_COMMAND:-}" == php ]]; then exit 17; fi
if [[ "${FAIL_COMMAND:-}" == php-interrupt ]]; then kill -TERM "$PPID"; exit 143; fi
exit 0
'
    make_stub git '[[ "${FAIL_COMMAND:-}" == git ]] && exit 47; exit 0'
    make_stub cp '
[[ "${FAIL_COMMAND:-}" == cp ]] && exit 48
[[ "${FAIL_COMMAND:-}" == dashboard-cp && "$*" == *ProcessesStatus/images* ]] && exit 48
exec /bin/cp "$@"
'
    make_stub chown '[[ "${FAIL_COMMAND:-}" == chown ]] && exit 49; exit 0'
    make_stub chmod '[[ "${FAIL_COMMAND:-}" == chmod ]] && exit 50; exec /bin/chmod "$@"'
    make_stub grep '
[[ "${FAIL_COMMAND:-}" == grep ]] && exit 51
[[ "${FAIL_COMMAND:-}" == dashboard-grep && "$*" == *ProcessesStatus* ]] && exit 51
exec /bin/grep "$@"
'
    make_stub sed '[[ "${FAIL_COMMAND:-}" == sed ]] && exit 52; exec /bin/sed "$@"'
    make_stub rpm '[[ "${FAIL_COMMAND:-}" == rpm ]] && exit 53; exit 0'
    make_stub id '[[ "${FAIL_COMMAND:-}" == id ]] && exit 54; exit 0'
    make_stub usermod '[[ "${FAIL_COMMAND:-}" == usermod ]] && exit 55; exit 0'
}

run_installer() {
    local mode="$1"
    shift
    set +e
    output="$(CALLCENTER_INSTALL_ROOT="$fixture_root" SYSTEMCTL_STATE_FILE="$fixture_root/systemctl-active" PATH="$stub_dir:$PATH" "$@" bash "$repo_root/build/5.0/install-issabel-callcenter.sh" "$mode" 2>&1)"
    status=$?
    set -e
}

assert_required_failure() {
    test "$status" -ne 0 || fail "required failure returned success: $1"
    assert_contains "$output" "stage=$1"
    assert_not_contains "$output" 'installation complete'
}

assert_no_temp_dirs() {
    local temp_dirs
    temp_dirs="$(find "$fixture_root/tmp" "$fixture_root/usr/src" -mindepth 1 -maxdepth 1 -name 'issabel-callcenter.*' ! -name 'issabel-callcenter.sentinel' -print)"
    [[ -z "$temp_dirs" ]] || fail "temporary directories were not cleaned: $temp_dirs"
}

assert_cleanup_sentinel_survives() {
    [[ -d "$fixture_root/tmp/issabel-callcenter.sentinel" ]] || fail 'cleanup removed an unrelated temporary directory'
}

add_dashboard() {
    local dashboard_dir
    dashboard_dir="$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus"
    mkdir -p "$dashboard_dir/images"
    printf "'Apache' => 'icon_www.png'\n'Apache' => 'httpd'\n\$arrSERVICES[\"Apache\"][\"name_service\"] = \"Web Server\";\nif (file_exists(\"/usr/lib/systemd/system/{\$ns}.service\"))\n" > "$dashboard_dir/index.php"
}

add_dashboard_without_status_anchor() {
    local dashboard_dir
    dashboard_dir="$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus"
    mkdir -p "$dashboard_dir/images"
    printf "'Apache' => 'icon_www.png'\n'Apache' => 'httpd'\n" > "$dashboard_dir/index.php"
}

# The database installer must return its PHP failure instead of printing success.
make_fixture
run_installer --local env FAIL_COMMAND=php
assert_required_failure database-installer
assert_no_temp_dirs
assert_cleanup_sentinel_survives

# An interrupted database install must also clean only its registered temporary path.
make_fixture
run_installer --local env FAIL_COMMAND=php-interrupt
test "$status" -ne 0 || fail 'interrupted PHP installation returned success'
assert_not_contains "$output" 'installation complete'
assert_no_temp_dirs
assert_cleanup_sentinel_survives

# Service-manager failures are required failures, not warnings.
make_fixture
run_installer --local env FAIL_COMMAND=systemctl
assert_required_failure service-start

# A present dashboard applet that cannot be patched is a required failure.
make_fixture
add_dashboard
run_installer --local env FAIL_COMMAND=dashboard-cp
assert_required_failure dashboard-icon

make_fixture
add_dashboard
run_installer --local env
assert_status 0 "$status"
assert_contains "$output" 'installation complete'
dashboard_index="$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus/index.php"
assert_contains "$(<"$dashboard_index")" "'Dialer'    =>  'icon_headphones.png',"
assert_contains "$(<"$dashboard_index")" "'Dialer'    =>  'issabeldialer',"
assert_contains "$(<"$dashboard_index")" 'Issabel Call Center Service'

# Each dashboard edit requires its upstream anchor instead of silently succeeding without a change.
make_fixture
add_dashboard_without_status_anchor
run_installer --local env
assert_required_failure dashboard-status-anchor

# A dashboard read error is not a missing mapping and must stop the install.
make_fixture
add_dashboard
run_installer --local env FAIL_COMMAND=dashboard-grep
assert_required_failure dashboard-icon-check

# Asterisk reload must receive two arguments and a failure must stop the installer.
make_fixture
ASTERISK_ARGS_FILE="$fixture_root/asterisk-args"
run_installer --local env ASTERISK_ARGS_FILE="$ASTERISK_ARGS_FILE"
assert_status 0 "$status"
mapfile -t asterisk_args < "$ASTERISK_ARGS_FILE"
[[ "${#asterisk_args[@]}" -eq 2 ]] || fail "expected two Asterisk arguments, got ${#asterisk_args[@]}"
[[ "${asterisk_args[0]}" == '-rx' && "${asterisk_args[1]}" == 'core reload' ]] || fail 'Asterisk reload arguments are incorrect'
assert_contains "$output" 'installation complete'

make_fixture
run_installer --local env FAIL_COMMAND=asterisk
assert_required_failure asterisk-reload

# A missing command must fail in preflight rather than continuing installation.
make_fixture
rm -f -- "$stub_dir/asterisk"
run_installer --local env PATH="$stub_dir:/usr/local/bin:/usr/bin:/bin"
assert_required_failure preflight

# Unsupported Asterisk versions must not be installed against accidentally.
make_fixture
run_installer --local env ASTERISK_OUTPUT='Asterisk 20.1.0'
assert_required_failure preflight

# Malformed Asterisk output must not be accepted as a usable version.
make_fixture
run_installer --local env ASTERISK_OUTPUT='not an Asterisk response'
assert_required_failure preflight

# A clone failure must stop GitHub-mode installation and remove its unique checkout.
make_fixture
run_installer '' env FAIL_COMMAND=git
assert_required_failure source-clone
assert_no_temp_dirs

# A missing local source component must stop before installation mutations.
make_fixture
missing_source="$fixture_root/missing-source"
mkdir -p "$missing_source/build/5.0"
/bin/cp "$repo_root/build/5.0/install-issabel-callcenter.sh" "$missing_source/build/5.0/"
/bin/cp -a "$repo_root/build/5.0/lib" "$missing_source/build/5.0/"
set +e
output="$(CALLCENTER_INSTALL_ROOT="$fixture_root" PATH="$stub_dir:$PATH" bash "$missing_source/build/5.0/install-issabel-callcenter.sh" --local 2>&1)"
status=$?
set -e
assert_required_failure source-layout

# A failed module copy must not reach a success banner.
make_fixture
run_installer --local env FAIL_COMMAND=cp
assert_required_failure modules-copy

# Menu merge is a required operation and must propagate failure.
make_fixture
run_installer --local env FAIL_COMMAND=issabel-menumerge
assert_required_failure menu-merge

# Unknown arguments must be rejected with the public usage contract.
make_fixture
run_installer --unsupported env
assert_status 2 "$status"
assert_contains "$output" 'Usage:'

printf 'PASS: installer behavior tests\n'
