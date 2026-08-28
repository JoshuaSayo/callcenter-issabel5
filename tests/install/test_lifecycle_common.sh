#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repo_root/tests/install/test_helpers.sh"
library="$repo_root/build/5.0/lib/callcenter-lifecycle.sh"

fixture_parent="$(mktemp -d)"
trap 'rm -rf -- "$fixture_parent"' EXIT
fixture_root="$fixture_parent/root"
mkdir -p "$fixture_root/etc"
printf '%s\n' 'sentinel' > "$fixture_root/etc/must-survive"

test_registered_temp_is_removed_without_touching_sentinel() {
    local temp_path
    CC_INSTALL_ROOT="$fixture_root"
    source "$library"

    assert_contains "$(cc_root_path /var/www/html)" "$fixture_root/var/www/html"
    cc_make_temp temp_path /tmp test
    [[ -d "$temp_path" ]] || fail 'registered temp directory was not created'
    printf '%s\n' 'temporary' > "$temp_path/value"

    cc_cleanup

    [[ ! -e "$temp_path" ]] || fail 'registered temp directory survived cleanup'
    [[ -f "$fixture_root/etc/must-survive" ]] || fail 'cleanup removed the sentinel'
}

test_relative_install_root_is_rejected() {
    local output status
    set +e
    output="$( {
        CC_INSTALL_ROOT='relative/root'
        source "$library"
    } 2>&1 )"
    status=$?
    set -e

    [[ "$status" -ne 0 ]] || fail 'relative install root was accepted'
    assert_contains "$output" 'CC_INSTALL_ROOT must be empty or absolute'
}

test_unregistered_cleanup_target_is_rejected() {
    local output status
    set +e
    output="$( {
        CC_INSTALL_ROOT="$fixture_root"
        source "$library"
        cc_register_temp "$fixture_root/etc"
    } 2>&1 )"
    status=$?
    set -e

    [[ "$status" -ne 0 ]] || fail 'non-temporary cleanup target was accepted'
    assert_contains "$output" 'unsafe temporary path'
    [[ -f "$fixture_root/etc/must-survive" ]] || fail 'rejected registration removed the sentinel'
}

test_failed_command_reports_stage() {
    local output status
    set +e
    output="$( {
        CC_INSTALL_ROOT="$fixture_root"
        source "$library"
        cc_run database-installer bash -c 'exit 17'
    } 2>&1 )"
    status=$?
    set -e

    [[ "$status" -ne 0 ]] || fail 'failed staged command returned success'
    assert_contains "$output" 'stage=database-installer'
}

test_registered_temp_is_removed_without_touching_sentinel
test_relative_install_root_is_rejected
test_unregistered_cleanup_target_is_rejected
test_failed_command_reports_stage
printf '%s\n' 'PASS test_lifecycle_common'
