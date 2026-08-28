#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repo_root/tests/install/test_helpers.sh"

fixture_parent="$(mktemp -d)"
trap 'rm -rf -- "$fixture_parent"' EXIT
fixture_root="$fixture_parent/root"
stub_dir="$fixture_parent/bin"
mkdir -p \
    "$fixture_root/etc/asterisk" \
    "$fixture_root/etc/systemd/system" \
    "$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus" \
    "$stub_dir"

printf '%s\n' \
    'NAME="Rocky Linux"' \
    'VERSION="8.8 (Green Obsidian)"' \
    'PRETTY_NAME="Rocky Linux 8.8 (Green Obsidian)"' \
    > "$fixture_root/etc/os-release"
printf '%s\n' 'mysqlrootpwd=collector-secret' > "$fixture_root/etc/issabel.conf"
printf '%s\n' '[Unit]' > "$fixture_root/etc/systemd/system/issabeldialer.service"
printf '%s\n' '[from-internal]' > "$fixture_root/etc/asterisk/extensions_custom.conf"
printf '%s\n' '[general]' > "$fixture_root/etc/asterisk/agents.conf"
printf '%s\n' '<?php' > "$fixture_root/var/www/html/modules/dashboard/applets/ProcessesStatus/index.php"

make_stub rpm '
case "${1:-}" in
    -q) printf "%s\\n" "rocky-release-8.8-1.8.el8" ;;
    -qa) printf "%s\\n" "issabel-framework-5.0.0-1" "issabel-callcenter-5.0.0-1" ;;
    *) exit 2 ;;
esac'

make_stub uname '[[ "${1:-}" == "-r" ]] || exit 2; printf "%s\\n" "4.18.0-477.27.1.el8_8.x86_64"'

make_stub php '
case "${1:-}" in
    -v) printf "%s\\n" "PHP 7.4.33 (cli)" ;;
    -m) printf "%s\\n" "PDO" "pdo_mysql" "mysqli" ;;
    *) exit 2 ;;
esac'

make_stub mysql '
if [[ " $* " == *" --version "* ]]; then
    printf "%s\\n" "mysql  Ver 15.1 Distrib 10.3.39-MariaDB"
elif [[ " $* " == *"SELECT VERSION()"* ]]; then
    printf "%s\\n" "10.3.39-MariaDB"
elif [[ " $* " == *"information_schema.tables"* ]]; then
    [[ "${MYSQL_PWD:-}" == "collector-secret" ]] || exit 9
    printf "%s\\n" "27"
else
    exit 2
fi'

make_stub asterisk '
if [[ "${ASTERISK_STUB_FAIL:-0}" == "1" ]]; then exit 12; fi
[[ "${1:-}" == "-rx" && "${2:-}" == "core show version" ]] || exit 2
printf "%s\\n" "Asterisk 18.19.0 built by root @ rocky8"'

make_stub httpd '[[ "${1:-}" == "-v" ]] || exit 2; printf "%s\\n" "Server version: Apache/2.4.37 (rocky)"'

make_stub systemctl '
case "${1:-}" in
    --version) printf "%s\\n" "systemd 239 (239-78.el8)" ;;
    is-active) printf "%s\\n" "active" ;;
    is-enabled) printf "%s\\n" "enabled" ;;
    *) exit 2 ;;
esac'

make_stub sha256sum '
last="${!#}"
printf "%s  %s\\n" "feedfacefeedfacefeedfacefeedfacefeedfacefeedfacefeedfacefeedface" "$last"'

run_collector() {
    CALLCENTER_ROOT="$fixture_root" \
    PATH="$stub_dir:$PATH" \
    bash "$repo_root/tools/collect-issabel-baseline.sh" 2>&1
}

test_collects_baseline_without_disclosing_password() {
    local output status
    set +e
    output="$(run_collector)"
    status=$?
    set -e

    assert_status 0 "$status"
    assert_contains "$output" 'OS_RELEASE=Rocky Linux 8.8 (Green Obsidian)'
    assert_contains "$output" 'PHP_VERSION=PHP 7.4.33 (cli)'
    assert_contains "$output" 'ASTERISK_VERSION=Asterisk 18.19.0 built by root @ rocky8'
    assert_contains "$output" 'CALLCENTER_TABLE_COUNT=27'
    assert_not_contains "$output" 'collector-secret'
}

test_required_asterisk_failure_is_reported_as_error() {
    local output status
    set +e
    output="$(ASTERISK_STUB_FAIL=1 run_collector)"
    status=$?
    set -e

    [[ "$status" -ne 0 ]] || fail 'required Asterisk failure returned success'
    assert_contains "$output" 'ASTERISK_VERSION=ERROR'
    assert_not_contains "$output" 'ASTERISK_VERSION=UNAVAILABLE'
}

test_collects_baseline_without_disclosing_password
test_required_asterisk_failure_is_reported_as_error
printf '%s\n' 'PASS test_baseline_collector'
