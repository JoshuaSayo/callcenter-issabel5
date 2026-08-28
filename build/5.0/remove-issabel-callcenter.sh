#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CC_INSTALL_ROOT="${CALLCENTER_INSTALL_ROOT:-}"
source "$SCRIPT_DIR/lib/callcenter-lifecycle.sh"

usage() {
    printf 'Usage: %s [--keep-database|--delete-database]\n' "$0" >&2
}

case "${1:-interactive}" in
    interactive) DATABASE_ACTION=prompt ;;
    --keep-database) DATABASE_ACTION=keep ;;
    --delete-database) DATABASE_ACTION=delete ;;
    *) usage; exit 2 ;;
esac
if [[ "$#" -gt 1 ]]; then
    usage
    exit 2
fi

cc_require_root

MODULE_DIRS=(
    agent_break agent_console agent_journey agents break_administrator callcenter_config
    calls_detail calls_per_agent calls_per_hour campaign_in campaign_monitoring campaign_out
    cb_extensions client dont_call_list eccp_users external_url form_designer form_list
    graphic_calls hold_time ingoings_calls_success login_logout queues
    rep_agent_information rep_agents_monitoring rep_incoming_calls_monitoring
    rep_incoming_campaigns_panel rep_outgoing_campaigns_panel reports_break rep_trunks_used_per_hour
)

REMOVAL_TREE_ROOTS=(
    /var/www/html/modules
    /opt/issabel
    /var/log
    /usr/share/issabel/module_installer
)

SYSTEMD_UNIT="$(cc_root_path /etc/systemd/system/issabeldialer.service)"
INIT_SCRIPT="$(cc_root_path /etc/rc.d/init.d/issabeldialer)"
DIALER_LOGROTATE="$(cc_root_path /etc/logrotate.d/issabeldialer)"
MODULE_LOGROTATE="$(cc_root_path /etc/logrotate.d/callcenter-modules)"
DNC_TOOL="$(cc_root_path /usr/bin/issabel-callcenter-local-dnc)"
DASHBOARD_DIR="$(cc_root_path /var/www/html/modules/dashboard/applets/ProcessesStatus)"
DASHBOARD_INDEX="$DASHBOARD_DIR/index.php"
DASHBOARD_ICON="$DASHBOARD_DIR/images/icon_headphones.png"
APACHE_CONFIG="$(cc_root_path /etc/httpd/conf.d/issabel-sse.conf)"
EXTENSIONS_FILE="$(cc_root_path /etc/asterisk/extensions_custom.conf)"
ISSABEL_CONFIG="$(cc_root_path /etc/issabel.conf)"

REMOVAL_FILES=(
    "$SYSTEMD_UNIT"
    "$INIT_SCRIPT"
    "$DIALER_LOGROTATE"
    "$MODULE_LOGROTATE"
    "$DNC_TOOL"
    "$DASHBOARD_ICON"
    "$APACHE_CONFIG"
)

path_exists() {
    [[ -e "$1" || -L "$1" ]]
}

remove_tree() {
    local path="$1" accepted_root rooted_root safe=0

    [[ "$path" == /* && "$path" != *'/../'* && "$path" != */.. && "$path" != *'/./'* ]] ||
        cc_die "unsafe removal tree: $path"
    for accepted_root in "${REMOVAL_TREE_ROOTS[@]}"; do
        rooted_root="$(cc_root_path "$accepted_root")"
        if [[ "$path" == "$rooted_root/"* ]]; then
            safe=1
            break
        fi
    done
    [[ "$safe" -eq 1 ]] || cc_die "removal tree is outside the allowlist: $path"

    if path_exists "$path"; then
        rm -rf -- "$path" || cc_die "cannot remove tree: $path"
    fi
    ! path_exists "$path" || cc_die "removal tree remains present: $path"
}

remove_file() {
    local path="$1" allowed safe=0

    for allowed in "${REMOVAL_FILES[@]}"; do
        if [[ "$path" == "$allowed" ]]; then
            safe=1
            break
        fi
    done
    [[ "$safe" -eq 1 ]] || cc_die "removal file is outside the allowlist: $path"

    if path_exists "$path"; then
        rm -f -- "$path" || cc_die "cannot remove file: $path"
    fi
    ! path_exists "$path" || cc_die "removal file remains present: $path"
}

service_present=0
if path_exists "$SYSTEMD_UNIT" || path_exists "$INIT_SCRIPT" ||
    systemctl is-active --quiet issabeldialer || systemctl is-enabled --quiet issabeldialer
then
    service_present=1
fi
if [[ "$service_present" -eq 1 ]]; then
    cc_run service-stop systemctl stop issabeldialer
    cc_run service-disable systemctl disable issabeldialer
fi

remove_file "$SYSTEMD_UNIT"
remove_file "$INIT_SCRIPT"
cc_run systemd-daemon-reload systemctl daemon-reload

module_dir=''
for module_dir in "${MODULE_DIRS[@]}"; do
    remove_tree "$(cc_root_path "/var/www/html/modules/$module_dir")"
done
unset module_dir

remove_tree "$(cc_root_path /opt/issabel/dialer)"
remove_tree "$(cc_root_path /var/log/callcenter-module)"
remove_tree "$(cc_root_path /usr/share/issabel/module_installer/callcenter)"
remove_file "$DIALER_LOGROTATE"
remove_file "$MODULE_LOGROTATE"
remove_file "$DNC_TOOL"
remove_file "$APACHE_CONFIG"

if [[ -f "$DASHBOARD_INDEX" ]]; then
    cc_run dashboard-icon-map sed -i "/'Dialer'.*=>.*'icon_headphones.png'/d" "$DASHBOARD_INDEX"
    cc_run dashboard-service-map sed -i "/'Dialer'.*=>.*'issabeldialer'/d" "$DASHBOARD_INDEX"
    cc_run dashboard-status-map sed -i '/\$arrSERVICES\["Dialer"\]/d' "$DASHBOARD_INDEX"
fi
remove_file "$DASHBOARD_ICON"

cc_run menu-removal issabel-menuremove call_center

context_removed=0
if [[ -f "$EXTENSIONS_FILE" ]] &&
    grep -q '^; BEGIN ISSABEL CALL-CENTER CONTEXTS DO NOT REMOVE THIS LINE$' "$EXTENSIONS_FILE"
then
    cc_run dialplan-context-removal sed -i \
        '/^; BEGIN ISSABEL CALL-CENTER CONTEXTS DO NOT REMOVE THIS LINE$/,/^; END ISSABEL CALL-CENTER CONTEXTS DO NOT REMOVE THIS LINE$/d' \
        "$EXTENSIONS_FILE"
    context_removed=1
fi
if [[ "$context_removed" -eq 1 ]]; then
    cc_run dialplan-reload asterisk -rx 'dialplan reload'
fi

if [[ "$DATABASE_ACTION" == prompt ]]; then
    database_answer=''
    if ! read -r -p 'Do you want to delete the call_center database? (y/n): ' database_answer; then
        printf '%s\n' 'Database selection required; database was not touched.' >&2
        exit 2
    fi
    case "$database_answer" in
        y|Y) DATABASE_ACTION=delete ;;
        n|N) DATABASE_ACTION=keep ;;
        *)
            printf '%s\n' 'Database selection must be y, Y, n, or N; database was not touched.' >&2
            exit 2
            ;;
    esac
fi

[[ -r "$ISSABEL_CONFIG" ]] || cc_die "cannot read database credentials: $ISSABEL_CONFIG"
mysql_root_password=''
while IFS='=' read -r config_key config_value; do
    if [[ "$config_key" == mysqlrootpwd ]]; then
        mysql_root_password="$config_value"
        break
    fi
done < "$ISSABEL_CONFIG"
unset config_key config_value
[[ -n "$mysql_root_password" ]] || cc_die 'mysqlrootpwd is missing or empty'

if [[ "$DATABASE_ACTION" == delete ]]; then
    if ! MYSQL_PWD="$mysql_root_password" mysql --batch --skip-column-names \
        -e 'DROP DATABASE IF EXISTS call_center;'
    then
        unset mysql_root_password MYSQL_PWD
        cc_die 'database deletion failed'
    fi
fi

database_state=''
if ! database_state="$(MYSQL_PWD="$mysql_root_password" mysql --batch --skip-column-names \
    -e "SHOW DATABASES LIKE 'call_center';")"
then
    unset mysql_root_password MYSQL_PWD
    cc_die 'database postcondition query failed'
fi
unset mysql_root_password MYSQL_PWD

case "$DATABASE_ACTION" in
    keep)
        [[ "$database_state" == call_center ]] || cc_die 'database postcondition failed: call_center is absent'
        ;;
    delete)
        [[ -z "$database_state" ]] || cc_die 'database postcondition failed: call_center remains present'
        ;;
esac
unset database_state

if systemctl is-active --quiet issabeldialer; then
    cc_die 'service postcondition failed: issabeldialer is active'
fi

for module_dir in "${MODULE_DIRS[@]}"; do
    ! path_exists "$(cc_root_path "/var/www/html/modules/$module_dir")" ||
        cc_die "module postcondition failed: $module_dir remains present"
done
unset module_dir

for removed_tree in \
    "$(cc_root_path /opt/issabel/dialer)" \
    "$(cc_root_path /var/log/callcenter-module)" \
    "$(cc_root_path /usr/share/issabel/module_installer/callcenter)"
do
    ! path_exists "$removed_tree" || cc_die "tree postcondition failed: $removed_tree remains present"
done
unset removed_tree

for removed_file in "${REMOVAL_FILES[@]}"; do
    ! path_exists "$removed_file" || cc_die "file postcondition failed: $removed_file remains present"
done
unset removed_file

if [[ -f "$EXTENSIONS_FILE" ]] &&
    grep -q '^; \(BEGIN\|END\) ISSABEL CALL-CENTER CONTEXTS DO NOT REMOVE THIS LINE$' "$EXTENSIONS_FILE"
then
    cc_die 'dialplan postcondition failed: Call Center context marker remains present'
fi

printf '%s\n' 'Call Center Module removed successfully'
