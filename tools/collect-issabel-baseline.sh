#!/usr/bin/env bash
set -Eeuo pipefail

CALLCENTER_ROOT="${CALLCENTER_ROOT:-}"

if [[ -n "$CALLCENTER_ROOT" && "$CALLCENTER_ROOT" != /* ]]; then
    printf '%s\n' 'CALLCENTER_ROOT=ERROR' >&2
    exit 2
fi

root_path() {
    printf '%s%s' "$CALLCENTER_ROOT" "$1"
}

one_line() {
    tr '\r\n' '  ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'
}

required() {
    local key="$1"
    shift
    local value
    if value="$("$@" 2>&1)"; then
        printf '%s=%s\n' "$key" "$(printf '%s' "$value" | one_line)"
    else
        printf '%s=ERROR\n' "$key"
        return 1
    fi
}

optional() {
    local key="$1"
    shift
    local value
    if value="$("$@" 2>&1)"; then
        printf '%s=%s\n' "$key" "$(printf '%s' "$value" | one_line)"
    else
        printf '%s=UNAVAILABLE\n' "$key"
    fi
}

os_release() {
    awk -F= '
        $1 == "PRETTY_NAME" {
            value = substr($0, index($0, "=") + 1)
            gsub(/^"|"$/, "", value)
            print value
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "$(root_path /etc/os-release)"
}

php_version() {
    php -v | sed -n '1p'
}

php_modules() {
    php -m | sort | paste -sd, -
}

mariadb_server_version() {
    MYSQL_PWD="$mysql_root_password" mysql --batch --skip-column-names \
        -e 'SELECT VERSION();'
}

callcenter_table_count() {
    MYSQL_PWD="$mysql_root_password" mysql --batch --skip-column-names \
        -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='call_center' AND table_type='BASE TABLE';"
}

asterisk_version() {
    asterisk -rx 'core show version'
}

apache_version() {
    httpd -v | sed -n '1p'
}

systemd_version() {
    systemctl --version | sed -n '1p'
}

issabel_packages() {
    rpm -qa | sort | grep '^issabel-'
}

callcenter_packages() {
    rpm -qa | sort | grep -Ei 'callcenter|call-center'
}

checksum_if_present() {
    local path="$1"
    [[ -f "$path" ]] || return 1
    sha256sum "$path"
}

required OS_RELEASE os_release
required ROCKY_RELEASE_PACKAGE rpm -q rocky-release
required KERNEL uname -r
required PHP_VERSION php_version
required PHP_MODULES php_modules
required MARIADB_CLIENT_VERSION mysql --version

issabel_conf="$(root_path /etc/issabel.conf)"
mysql_root_password="$(awk -F= '$1 == "mysqlrootpwd" { print substr($0, index($0, "=") + 1); found = 1; exit } END { if (!found) exit 1 }' "$issabel_conf")" || {
    printf '%s\n' 'MARIADB_SERVER_VERSION=ERROR'
    exit 1
}
if [[ -z "$mysql_root_password" ]]; then
    printf '%s\n' 'MARIADB_SERVER_VERSION=ERROR'
    exit 1
fi

required MARIADB_SERVER_VERSION mariadb_server_version
required ASTERISK_VERSION asterisk_version
required APACHE_VERSION apache_version
required SYSTEMD_VERSION systemd_version
required ISSABEL_PACKAGES issabel_packages
optional CALLCENTER_PACKAGES callcenter_packages
optional DIALER_ACTIVE systemctl is-active issabeldialer
optional DIALER_ENABLED systemctl is-enabled issabeldialer
required CALLCENTER_TABLE_COUNT callcenter_table_count

optional CHECKSUM_DIALER_SERVICE checksum_if_present "$(root_path /etc/systemd/system/issabeldialer.service)"
optional CHECKSUM_EXTENSIONS_CUSTOM checksum_if_present "$(root_path /etc/asterisk/extensions_custom.conf)"
optional CHECKSUM_AGENTS_CONF checksum_if_present "$(root_path /etc/asterisk/agents.conf)"
optional CHECKSUM_DASHBOARD checksum_if_present "$(root_path /var/www/html/modules/dashboard/applets/ProcessesStatus/index.php)"

unset mysql_root_password
