#!/usr/bin/env bash
set -Eeuo pipefail

RELEASE='5.0.0-1'
GITHUB_ACCOUNT='ISSABELPBX'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CC_INSTALL_ROOT="${CALLCENTER_INSTALL_ROOT:-}"
source "$SCRIPT_DIR/lib/callcenter-lifecycle.sh"
trap cc_cleanup EXIT

LOCAL_INSTALL=false
WORK_DIR=''
ASTERISK_MAJOR=''

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

preflight() {
    local command
    CC_STAGE=preflight
    cc_require_root
    for command in cp chown chmod grep sed php systemctl issabel-menumerge asterisk; do
        command -v "$command" >/dev/null 2>&1 || cc_die "required command not found: $command"
    done
    if [[ "$LOCAL_INSTALL" == false ]]; then
        command -v git >/dev/null 2>&1 || cc_die 'required command not found: git'
    fi
    detect_asterisk_major
    case "$ASTERISK_MAJOR" in
        11|13|16|18) ;;
        *) cc_die "unsupported Asterisk version: $ASTERISK_MAJOR" ;;
    esac
}

validate_source_layout() {
    CC_STAGE=source-layout
    [[ -f "$WORK_DIR/menu.xml" ]] || cc_die "missing source file: $WORK_DIR/menu.xml"
    [[ -d "$WORK_DIR/modules" ]] || cc_die "missing source directory: $WORK_DIR/modules"
    [[ -f "$WORK_DIR/setup/installer.php" ]] || cc_die "missing source file: $WORK_DIR/setup/installer.php"
    [[ -x "$WORK_DIR/setup/dialer_process/dialer/dialerd" ]] || cc_die "missing executable: $WORK_DIR/setup/dialer_process/dialer/dialerd"
    [[ -f "$WORK_DIR/setup/dialer_process/issabeldialer.service" ]] || cc_die "missing source file: $WORK_DIR/setup/dialer_process/issabeldialer.service"
}

resolve_source() {
    CC_STAGE=source
    if [[ "$LOCAL_INSTALL" == true ]]; then
        WORK_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
    else
        local checkout_dir
        cc_make_temp checkout_dir /usr/src checkout
        cc_run source-clone git clone "https://github.com/${GITHUB_ACCOUNT}/callcenter-issabel5.git" "$checkout_dir"
        WORK_DIR="$checkout_dir"
    fi
    validate_source_layout
}

install_modules() {
    CC_STAGE=modules-copy
    cc_run modules-ownership chown -R asterisk:asterisk "$WORK_DIR/modules"
    cc_run modules-copy cp -a "$WORK_DIR/modules/." "$(cc_root_path /var/www/html/modules)/"
}

patch_dashboard() {
    local dashboard_dir dashboard_index
    CC_STAGE=dashboard
    dashboard_dir="$(cc_root_path /var/www/html/modules/dashboard/applets/ProcessesStatus)"
    dashboard_index="$dashboard_dir/index.php"
    if [[ ! -f "$dashboard_index" ]]; then
        printf 'OPTIONAL stage=dashboard reason=not-installed\n'
        return 0
    fi

    cc_run dashboard-icon cp -f "$WORK_DIR/setup/icon_headphones.png" "$dashboard_dir/images/"
    if ! grep -q "'Dialer'" "$dashboard_index"; then
        cc_run dashboard-icon-map sed -i "/'Apache'.*=>.*'icon_www.png'/a\\            'Dialer'    =>  'icon_headphones.png'," "$dashboard_index"
    fi
    if ! grep -q "'Dialer'.*=>.*'issabeldialer'" "$dashboard_index"; then
        cc_run dashboard-service-map sed -i "/'Apache'.*=>.*'httpd'/a\\            'Dialer'    =>  'issabeldialer'," "$dashboard_index"
    fi
    if ! grep -q 'dialerd.pid' "$dashboard_index"; then
        cc_run dashboard-status-map sed -i '/\$arrSERVICES\["Apache"\]\["name_service"\].*=.*"Web Server"/a\        $arrSERVICES["Dialer"]["status_service"] = $this->_existPID_ByFile("/opt/issabel/dialer/dialerd.pid","issabeldialer");' "$dashboard_index"
        cc_run dashboard-activation-map sed -i '/\$arrSERVICES\["Apache"\]\["name_service"\].*=.*"Web Server"/a\        $arrSERVICES["Dialer"]["activate"] = $this->_isActivate("issabeldialer");' "$dashboard_index"
        cc_run dashboard-name-map sed -i '/\$arrSERVICES\["Apache"\]\["name_service"\].*=.*"Web Server"/a\        $arrSERVICES["Dialer"]["name_service"] = "Issabel Call Center Service";' "$dashboard_index"
    fi
    if ! grep -q 'file_exists("/etc/systemd/system/{$ns}.service")' "$dashboard_index"; then
        cc_run dashboard-service-check sed -i 's|if (file_exists("/usr/lib/systemd/system/{$ns}.service"))|if (file_exists("/etc/systemd/system/{$ns}.service"))\n                return TRUE;\n            if (file_exists("/usr/lib/systemd/system/{$ns}.service"))|' "$dashboard_index"
    fi
}

install_dialer() {
    local dialer_dir
    CC_STAGE=dialer-install
    dialer_dir="$(cc_root_path /opt/issabel/dialer)"
    cc_run dialer-directory mkdir -p "$dialer_dir"
    cc_run dialer-directory-permissions chmod 755 "$dialer_dir"
    cc_run dialer-copy cp -a "$WORK_DIR/setup/dialer_process/dialer/." "$dialer_dir/"
    cc_run dialer-executable chmod +x "$dialer_dir/dialerd"
    cc_run service-file cp -f "$WORK_DIR/setup/dialer_process/issabeldialer.service" "$(cc_root_path /etc/systemd/system)/"
    cc_run service-daemon-reload systemctl daemon-reload
    cc_run dialer-logrotate-directory mkdir -p "$(cc_root_path /etc/logrotate.d)"
    cc_run dialer-logrotate cp -f "$WORK_DIR/setup/issabeldialer.logrotate" "$(cc_root_path /etc/logrotate.d/issabeldialer)"
    cc_run module-log-directory mkdir -p "$(cc_root_path /var/log/callcenter-module)"
    cc_run module-log-ownership chown asterisk:asterisk "$(cc_root_path /var/log/callcenter-module)"
    cc_run module-log-permissions chmod 750 "$(cc_root_path /var/log/callcenter-module)"
    cc_run module-logrotate cp -f "$WORK_DIR/setup/callcenter-modules.logrotate" "$(cc_root_path /etc/logrotate.d/callcenter-modules)"
    cc_run dnc-script cp -f "$WORK_DIR/setup/usr/bin/issabel-callcenter-local-dnc" "$(cc_root_path /usr/bin/)"
    cc_run dialer-ownership chown -R asterisk:asterisk "$(cc_root_path /opt/issabel)"
}

install_module_metadata() {
    local module_dir
    CC_STAGE=module-metadata
    module_dir="$(cc_root_path /usr/share/issabel/module_installer/callcenter)"
    cc_run module-metadata-remove rm -rf -- "$module_dir"
    cc_run module-metadata-directory mkdir -p "$module_dir"
    cc_run module-metadata-setup cp -a "$WORK_DIR/setup" "$module_dir/"
    cc_run module-metadata-menu cp -f "$WORK_DIR/menu.xml" "$module_dir/menu.xml"
    cc_run module-metadata-changelog cp -f "$WORK_DIR/CHANGELOG" "$module_dir/CHANGELOG"
    cc_run menu-merge issabel-menumerge "$module_dir/menu.xml"
    if [[ -f "$(cc_root_path /etc/rocky-release)" ]]; then
        cc_run sse-config cp -f "$module_dir/setup/issabel-sse.conf" "$(cc_root_path /etc/httpd/conf.d)/"
        cc_run httpd-reload systemctl reload httpd
    fi
}

run_database_installer() {
    local module_stage
    CC_STAGE=database-staging
    cc_make_temp module_stage /tmp module
    cc_run database-stage-copy cp -a "$(cc_root_path /usr/share/issabel/module_installer/callcenter)/." "$module_stage/"
    cc_run database-stage-ownership chown -R asterisk:asterisk "$module_stage"
    cc_run database-installer php "$module_stage/setup/installer.php"
}

configure_service() {
    CC_STAGE=service-configure
    if id asterisk >/dev/null 2>&1; then
        cc_run service-user-shell usermod -s /bin/bash asterisk
    fi
    cc_run service-enable systemctl enable issabeldialer
    if systemctl is-active --quiet issabeldialer; then
        cc_run service-restart systemctl restart issabeldialer
    else
        cc_run service-start systemctl start issabeldialer
    fi
}

reload_asterisk() {
    CC_STAGE=asterisk-reload
    cc_run asterisk-reload asterisk -rx 'core reload'
}

post_install_healthcheck() {
    CC_STAGE=post-install-healthcheck
    cc_run dialer-active systemctl is-active --quiet issabeldialer
    cc_run asterisk-health asterisk -rx 'core show version'
    test -x "$(cc_root_path /opt/issabel/dialer/dialerd)" || cc_die 'dialerd is not executable'
}

main() {
    parse_args "$@" || return $?
    preflight
    resolve_source
    install_modules
    patch_dashboard
    install_dialer
    install_module_metadata
    run_database_installer
    configure_service
    reload_asterisk
    post_install_healthcheck
    printf 'Issabel CallCenter %s installation complete!\n' "$RELEASE"
}

main "$@"
