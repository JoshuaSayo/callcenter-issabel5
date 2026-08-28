#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repo_root/tests/install/test_helpers.sh"
remover="$repo_root/build/5.0/remove-issabel-callcenter.sh"

fixture_parent="$(mktemp -d)"
trap 'rm -rf -- "$fixture_parent"' EXIT
stub_dir="$fixture_parent/bin"
mkdir -p "$stub_dir"

MODULE_DIRS=(
    agent_break agent_console agent_journey agents break_administrator callcenter_config
    calls_detail calls_per_agent calls_per_hour campaign_in campaign_monitoring campaign_out
    cb_extensions client dont_call_list eccp_users external_url form_designer form_list
    graphic_calls hold_time ingoings_calls_success login_logout queues
    rep_agent_information rep_agents_monitoring rep_incoming_calls_monitoring
    rep_incoming_campaigns_panel rep_outgoing_campaigns_panel reports_break rep_trunks_used_per_hour
)

make_stub systemctl '
state_dir="${CALLCENTER_TEST_STATE:?}"
if [[ "${FAIL_COMMAND:-}" == "systemctl" || "${FAIL_COMMAND:-}" == "systemctl:${1:-}" ]]; then
    exit 41
fi
case "${1:-}" in
    is-active) [[ -e "$state_dir/service-active" ]] ;;
    is-enabled) [[ -e "$state_dir/service-enabled" ]] ;;
    stop) rm -f -- "$state_dir/service-active" ;;
    disable) rm -f -- "$state_dir/service-enabled" ;;
    daemon-reload) : > "$state_dir/daemon-reloaded" ;;
    *) exit 42 ;;
esac'

make_stub issabel-menuremove '
[[ "${FAIL_COMMAND:-}" != "issabel-menuremove" ]] || exit 51
[[ "$#" -eq 1 && "$1" == "call_center" ]] || exit 52
rm -f -- "${CALLCENTER_TEST_STATE:?}/menu-call-center"'

make_stub asterisk '
[[ "${FAIL_COMMAND:-}" != "asterisk" ]] || exit 61
[[ "$#" -eq 2 && "$1" == "-rx" && "$2" == "dialplan reload" ]] || exit 62
: > "${CALLCENTER_TEST_STATE:?}/dialplan-reloaded"'

make_stub mysql '
state_dir="${CALLCENTER_TEST_STATE:?}"
: > "$state_dir/mysql-called"
[[ "${FAIL_COMMAND:-}" != "mysql" ]] || exit 71
[[ "${MYSQL_PWD:-}" == "fixture-secret" ]] || exit 72
[[ "$#" -eq 4 && "$1" == "--batch" && "$2" == "--skip-column-names" && "$3" == "-e" ]] || exit 73
case "$4" in
    "DROP DATABASE IF EXISTS call_center;")
        rm -f -- "$CALLCENTER_INSTALL_ROOT/var/lib/fake-mysql/call_center"
        ;;
    "SHOW DATABASES LIKE '\''call_center'\'';")
        : > "$state_dir/database-state-checked"
        if [[ -e "$CALLCENTER_INSTALL_ROOT/var/lib/fake-mysql/call_center" ]]; then
            printf "%s\n" call_center
        fi
        ;;
    *) exit 74 ;;
esac'

prepare_fixture() {
    local name="$1" module
    fixture_root="$fixture_parent/$name/root"
    state_dir="$fixture_parent/$name/state"
    mkdir -p \
        "$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus/images" \
        "$fixture_root/opt/issabel/dialer" \
        "$fixture_root/etc/systemd/system" \
        "$fixture_root/etc/rc.d/init.d" \
        "$fixture_root/etc/logrotate.d" \
        "$fixture_root/etc/httpd/conf.d" \
        "$fixture_root/etc/asterisk" \
        "$fixture_root/var/log/callcenter-module" \
        "$fixture_root/var/lib/fake-mysql" \
        "$fixture_root/usr/bin" \
        "$fixture_root/usr/share/issabel/module_installer/callcenter" \
        "$fixture_root/var/www/html/outside-modules-sentinel" \
        "$fixture_root/opt/outside-issabel-sentinel" \
        "$fixture_root/var/outside-log-sentinel" \
        "$fixture_root/usr/share/issabel/outside-module-installer-sentinel" \
        "$state_dir"

    for module in "${MODULE_DIRS[@]}"; do
        mkdir -p "$fixture_root/var/www/html/modules/$module"
        printf '%s\n' "$module" > "$fixture_root/var/www/html/modules/$module/installed"
    done

    printf '%s\n' 'dialer' > "$fixture_root/opt/issabel/dialer/installed"
    printf '%s\n' '[Unit]' > "$fixture_root/etc/systemd/system/issabeldialer.service"
    printf '%s\n' '#!/bin/sh' > "$fixture_root/etc/rc.d/init.d/issabeldialer"
    printf '%s\n' 'dialer rotate' > "$fixture_root/etc/logrotate.d/issabeldialer"
    printf '%s\n' 'module rotate' > "$fixture_root/etc/logrotate.d/callcenter-modules"
    printf '%s\n' 'debug' > "$fixture_root/var/log/callcenter-module/debug.log"
    printf '%s\n' '#!/bin/sh' > "$fixture_root/usr/bin/issabel-callcenter-local-dnc"
    printf '%s\n' 'installer' > "$fixture_root/usr/share/issabel/module_installer/callcenter/installed"
    printf '%s\n' 'icon' > "$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus/images/icon_headphones.png"
    printf '%s\n' 'ProxyPass /sse' > "$fixture_root/etc/httpd/conf.d/issabel-sse.conf"
    printf '%s\n' 'mysqlrootpwd=fixture-secret' > "$fixture_root/etc/issabel.conf"
    printf '%s\n' 'database' > "$fixture_root/var/lib/fake-mysql/call_center"
    printf '%s\n' \
        "'Apache' => 'httpd'," \
        "'Dialer' => 'icon_headphones.png'," \
        "'Dialer' => 'issabeldialer'," \
        '\$arrSERVICES["Dialer"]["name_service"] = "Dialer";' \
        'dashboard-sentinel' \
        > "$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus/index.php"
    printf '%s\n' \
        '[from-internal-custom]' \
        '; BEGIN ISSABEL CALL-CENTER CONTEXTS DO NOT REMOVE THIS LINE' \
        '[call-center-fixture]' \
        'exten => 1,1,NoOp(Call Center)' \
        '; END ISSABEL CALL-CENTER CONTEXTS DO NOT REMOVE THIS LINE' \
        '[fixture-survivor]' \
        > "$fixture_root/etc/asterisk/extensions_custom.conf"

    printf '%s\n' sentinel > "$fixture_root/var/www/html/outside-modules-sentinel/value"
    printf '%s\n' sentinel > "$fixture_root/opt/outside-issabel-sentinel/value"
    printf '%s\n' sentinel > "$fixture_root/var/outside-log-sentinel/value"
    printf '%s\n' sentinel > "$fixture_root/usr/share/issabel/outside-module-installer-sentinel/value"
    printf '%s\n' sentinel > "$fixture_root/etc/systemd/system/not-callcenter.service"
    printf '%s\n' sentinel > "$fixture_root/etc/rc.d/init.d/not-callcenter"
    printf '%s\n' sentinel > "$fixture_root/etc/logrotate.d/not-callcenter"
    printf '%s\n' sentinel > "$fixture_root/usr/bin/not-callcenter"
    printf '%s\n' sentinel > "$fixture_root/etc/httpd/conf.d/not-callcenter.conf"
    printf '%s\n' sentinel > "$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus/images/not-callcenter.png"
    : > "$state_dir/service-active"
    : > "$state_dir/service-enabled"
    : > "$state_dir/menu-call-center"
}

run_remove() {
    CALLCENTER_INSTALL_ROOT="$fixture_root" \
    CALLCENTER_TEST_STATE="$state_dir" \
    PATH="$stub_dir:$PATH" \
        bash "$remover" "$@" 2>&1
}

capture_remove() {
    local output_variable="$1" status_variable="$2"
    shift 2
    local captured_result captured_status
    set +e
    captured_result="$(run_remove "$@")"
    captured_status=$?
    set -e
    printf -v "$output_variable" '%s' "$captured_result"
    printf -v "$status_variable" '%s' "$captured_status"
}

assert_removal_postconditions() {
    local module
    for module in "${MODULE_DIRS[@]}"; do
        [[ ! -e "$fixture_root/var/www/html/modules/$module" ]] || fail "module retained: $module"
    done
    [[ ! -e "$fixture_root/opt/issabel/dialer" ]] || fail 'dialer tree retained'
    [[ ! -e "$fixture_root/etc/systemd/system/issabeldialer.service" ]] || fail 'systemd unit retained'
    [[ ! -e "$fixture_root/etc/rc.d/init.d/issabeldialer" ]] || fail 'init script retained'
    [[ ! -e "$fixture_root/etc/logrotate.d/issabeldialer" ]] || fail 'dialer logrotate retained'
    [[ ! -e "$fixture_root/etc/logrotate.d/callcenter-modules" ]] || fail 'module logrotate retained'
    [[ ! -e "$fixture_root/var/log/callcenter-module" ]] || fail 'module log retained'
    [[ ! -e "$fixture_root/usr/bin/issabel-callcenter-local-dnc" ]] || fail 'DNC tool retained'
    [[ ! -e "$fixture_root/usr/share/issabel/module_installer/callcenter" ]] || fail 'module installer tree retained'
    [[ ! -e "$fixture_root/etc/httpd/conf.d/issabel-sse.conf" ]] || fail 'Apache config retained'
    [[ ! -e "$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus/images/icon_headphones.png" ]] || fail 'dashboard icon retained'
    [[ ! -e "$state_dir/service-active" ]] || fail 'service remained active'
    [[ ! -e "$state_dir/service-enabled" ]] || fail 'service remained enabled'
    [[ -e "$state_dir/daemon-reloaded" ]] || fail 'systemd daemon was not reloaded'
    [[ ! -e "$state_dir/menu-call-center" ]] || fail 'Call Center menu was retained'
    grep -q 'dashboard-sentinel' "$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus/index.php" || fail 'dashboard survivor content removed'
    ! grep -q 'Dialer' "$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus/index.php" || fail 'dashboard Dialer patch retained'
    grep -q '\[fixture-survivor\]' "$fixture_root/etc/asterisk/extensions_custom.conf" || fail 'dialplan survivor content removed'
    ! grep -q 'ISSABEL CALL-CENTER CONTEXTS' "$fixture_root/etc/asterisk/extensions_custom.conf" || fail 'Call Center context markers retained'
    [[ -e "$state_dir/dialplan-reloaded" ]] || fail 'dialplan was not reloaded after context removal'
}

assert_containment_sentinels_survive() {
    local sentinel
    for sentinel in \
        var/www/html/outside-modules-sentinel/value \
        opt/outside-issabel-sentinel/value \
        var/outside-log-sentinel/value \
        usr/share/issabel/outside-module-installer-sentinel/value \
        etc/systemd/system/not-callcenter.service \
        etc/rc.d/init.d/not-callcenter \
        etc/logrotate.d/not-callcenter \
        usr/bin/not-callcenter \
        etc/httpd/conf.d/not-callcenter.conf \
        var/www/html/modules/dashboard/applets/ProcessesStatus/images/not-callcenter.png
    do
        [[ -e "$fixture_root/$sentinel" ]] || fail "containment sentinel removed: $sentinel"
    done
}

test_keep_database_removes_only_allowlisted_targets() {
    local output status
    prepare_fixture keep
    capture_remove output status --keep-database
    assert_status 0 "$status"
    assert_contains "$output" 'Call Center Module removed successfully'
    assert_not_contains "$output" 'fixture-secret'
    [[ -e "$fixture_root/var/lib/fake-mysql/call_center" ]] || fail 'keep mode deleted database'
    [[ -e "$state_dir/mysql-called" ]] || fail 'keep mode did not verify database state'
    [[ -e "$state_dir/database-state-checked" ]] || fail 'keep mode omitted database postcondition query'
    assert_removal_postconditions
    assert_containment_sentinels_survive
}

test_delete_database_removes_database_without_secret_argv() {
    local output status
    prepare_fixture delete
    capture_remove output status --delete-database
    assert_status 0 "$status"
    assert_contains "$output" 'Call Center Module removed successfully'
    assert_not_contains "$output" 'fixture-secret'
    [[ ! -e "$fixture_root/var/lib/fake-mysql/call_center" ]] || fail 'delete mode retained database'
    [[ -e "$state_dir/mysql-called" ]] || fail 'delete mode did not invoke mysql'
    [[ -e "$state_dir/database-state-checked" ]] || fail 'delete mode omitted database postcondition query'
    assert_removal_postconditions
    assert_containment_sentinels_survive
}

test_required_menu_failure_is_fatal() {
    local output status
    prepare_fixture menu-failure
    FAIL_COMMAND=issabel-menuremove capture_remove output status --keep-database
    [[ "$status" -ne 0 ]] || fail 'menu failure returned success'
    assert_not_contains "$output" 'Call Center Module removed successfully'
}

test_required_database_failure_is_fatal() {
    local output status
    prepare_fixture mysql-failure
    set +e
    output="$(printf 'y\n' | FAIL_COMMAND=mysql CALLCENTER_INSTALL_ROOT="$fixture_root" CALLCENTER_TEST_STATE="$state_dir" PATH="$stub_dir:$PATH" bash "$remover" --delete-database 2>&1)"
    status=$?
    set -e
    [[ "$status" -ne 0 ]] || fail 'database failure returned success'
    assert_not_contains "$output" 'Call Center Module removed successfully'
    [[ -e "$fixture_root/var/lib/fake-mysql/call_center" ]] || fail 'failed mysql call changed database state'
}

test_unknown_argument_exits_two_without_changes() {
    local output status
    prepare_fixture unknown
    capture_remove output status --unexpected
    assert_status 2 "$status"
    assert_contains "$output" 'Usage:'
    assert_not_contains "$output" 'Call Center Module removed successfully'
    [[ -e "$fixture_root/var/www/html/modules/agents/installed" ]] || fail 'unknown argument started removal'
    [[ -e "$fixture_root/var/lib/fake-mysql/call_center" ]] || fail 'unknown argument touched database'
}

test_interactive_answers_are_explicit() {
    local output status
    prepare_fixture interactive-no
    set +e
    output="$(printf 'n\n' | CALLCENTER_INSTALL_ROOT="$fixture_root" CALLCENTER_TEST_STATE="$state_dir" PATH="$stub_dir:$PATH" bash "$remover" 2>&1)"
    status=$?
    set -e
    assert_status 0 "$status"
    [[ -e "$fixture_root/var/lib/fake-mysql/call_center" ]] || fail 'interactive n deleted database'
    [[ -e "$state_dir/database-state-checked" ]] || fail 'interactive n omitted database postcondition query'

    prepare_fixture interactive-yes
    set +e
    output="$(printf 'Y\n' | CALLCENTER_INSTALL_ROOT="$fixture_root" CALLCENTER_TEST_STATE="$state_dir" PATH="$stub_dir:$PATH" bash "$remover" 2>&1)"
    status=$?
    set -e
    assert_status 0 "$status"
    [[ ! -e "$fixture_root/var/lib/fake-mysql/call_center" ]] || fail 'interactive Y retained database'

    prepare_fixture interactive-invalid
    set +e
    output="$(printf 'yes\n' | CALLCENTER_INSTALL_ROOT="$fixture_root" CALLCENTER_TEST_STATE="$state_dir" PATH="$stub_dir:$PATH" bash "$remover" 2>&1)"
    status=$?
    set -e
    assert_status 2 "$status"
    assert_not_contains "$output" 'Call Center Module removed successfully'
    [[ -e "$fixture_root/var/lib/fake-mysql/call_center" ]] || fail 'invalid answer touched database'
    [[ ! -e "$state_dir/mysql-called" ]] || fail 'invalid answer invoked mysql'

    prepare_fixture interactive-eof
    set +e
    output="$(CALLCENTER_INSTALL_ROOT="$fixture_root" CALLCENTER_TEST_STATE="$state_dir" PATH="$stub_dir:$PATH" bash "$remover" </dev/null 2>&1)"
    status=$?
    set -e
    assert_status 2 "$status"
    assert_not_contains "$output" 'Call Center Module removed successfully'
    [[ -e "$fixture_root/var/lib/fake-mysql/call_center" ]] || fail 'EOF touched database'
    [[ ! -e "$state_dir/mysql-called" ]] || fail 'EOF invoked mysql'
}

test_dialplan_reload_only_follows_context_removal() {
    local output status
    prepare_fixture no-context
    printf '%s\n' '[fixture-survivor]' > "$fixture_root/etc/asterisk/extensions_custom.conf"
    FAIL_COMMAND=asterisk capture_remove output status --keep-database
    assert_status 0 "$status"
    assert_contains "$output" 'Call Center Module removed successfully'
    [[ ! -e "$state_dir/dialplan-reloaded" ]] || fail 'dialplan reloaded without removing a context block'
}

test_idempotent_second_removal_succeeds() {
    local output status
    prepare_fixture idempotent
    capture_remove output status --keep-database
    assert_status 0 "$status"
    capture_remove output status --keep-database
    assert_status 0 "$status"
    assert_contains "$output" 'Call Center Module removed successfully'
    [[ -e "$fixture_root/var/lib/fake-mysql/call_center" ]] || fail 'idempotent keep removal deleted database'
    assert_containment_sentinels_survive
}

tests=(
    test_keep_database_removes_only_allowlisted_targets
    test_delete_database_removes_database_without_secret_argv
    test_required_menu_failure_is_fatal
    test_required_database_failure_is_fatal
    test_unknown_argument_exits_two_without_changes
    test_interactive_answers_are_explicit
    test_dialplan_reload_only_follows_context_removal
    test_idempotent_second_removal_succeeds
)
if [[ "$#" -gt 0 ]]; then
    tests=("$@")
fi
for test_name in "${tests[@]}"; do
    "$test_name"
done
printf '%s\n' 'PASS test_remove_script'
