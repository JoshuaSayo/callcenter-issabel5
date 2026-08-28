#!/usr/bin/env bash
set -Eeuo pipefail

CC_INSTALL_ROOT="${CC_INSTALL_ROOT:-}"
CC_STAGE="${CC_STAGE:-preflight}"
CC_TEMP_DIRS=()

cc_die() {
    printf 'ERROR stage=%s message=%s\n' "${CC_STAGE:-unknown}" "$*" >&2
    exit 1
}

if [[ -n "$CC_INSTALL_ROOT" && "$CC_INSTALL_ROOT" != /* ]]; then
    cc_die 'CC_INSTALL_ROOT must be empty or absolute'
fi

cc_root_path() {
    local path="$1"
    [[ "$path" == /* ]] || cc_die "rooted path must be absolute: $path"
    printf '%s%s' "${CC_INSTALL_ROOT%/}" "$path"
}

cc_require_root() {
    if [[ -z "$CC_INSTALL_ROOT" && ${EUID} -ne 0 ]]; then
        cc_die 'installer must run as root'
    fi
}

cc_run() {
    CC_STAGE="$1"
    shift
    local status
    if "$@"; then
        return 0
    else
        status=$?
        cc_die "command failed with status $status: $*"
    fi
}

cc_resolve_path() {
    realpath -m -- "$1" 2>/dev/null || cc_die "cannot resolve path: $1"
}

cc_is_safe_temp() {
    local path="$1"
    local resolved parent base tmp_parent source_parent
    resolved="$(cc_resolve_path "$path")"
    parent="$(dirname -- "$resolved")"
    base="$(basename -- "$resolved")"
    tmp_parent="$(cc_resolve_path "$(cc_root_path /tmp)")"
    source_parent="$(cc_resolve_path "$(cc_root_path /usr/src)")"

    [[ "$parent" == "$tmp_parent" || "$parent" == "$source_parent" ]] || return 1
    [[ "$base" == issabel-callcenter.* ]] || return 1
}

cc_register_temp() {
    local path="$1"
    local resolved registered
    resolved="$(cc_resolve_path "$path")"
    [[ -d "$resolved" ]] || cc_die "temporary path is not a directory: $resolved"
    cc_is_safe_temp "$resolved" || cc_die "unsafe temporary path: $resolved"

    for registered in "${CC_TEMP_DIRS[@]}"; do
        [[ "$registered" == "$resolved" ]] && return 0
    done
    CC_TEMP_DIRS+=("$resolved")
}

cc_make_temp() {
    local output_variable="$1"
    local rooted_parent="$2"
    local label="$3"
    local parent path

    [[ "$output_variable" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || cc_die 'invalid output variable for temporary path'
    [[ "$rooted_parent" == /tmp || "$rooted_parent" == /usr/src ]] || cc_die "unsafe temporary parent: $rooted_parent"
    [[ "$label" =~ ^[A-Za-z0-9_-]+$ ]] || cc_die "unsafe temporary label: $label"

    parent="$(cc_root_path "$rooted_parent")"
    mkdir -p -- "$parent" || cc_die "cannot create temporary parent: $parent"
    path="$(mktemp -d "$parent/issabel-callcenter.${label}.XXXXXX")" || cc_die 'mktemp failed'
    cc_register_temp "$path"
    printf -v "$output_variable" '%s' "$(cc_resolve_path "$path")"
}

cc_cleanup() {
    local path status=0
    for path in "${CC_TEMP_DIRS[@]}"; do
        if ! cc_is_safe_temp "$path"; then
            printf 'ERROR stage=cleanup message=unsafe temporary path: %s\n' "$path" >&2
            status=1
            continue
        fi
        if [[ -e "$path" ]] && ! rm -rf -- "$path"; then
            printf 'ERROR stage=cleanup message=cannot remove temporary path: %s\n' "$path" >&2
            status=1
        fi
    done
    CC_TEMP_DIRS=()
    return "$status"
}
