#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    [[ "$1" == *"$2"* ]] || fail "missing text: $2"
}

assert_not_contains() {
    [[ "$1" != *"$2"* ]] || fail "unexpected text: $2"
}

assert_status() {
    [[ "$1" -eq "$2" ]] || fail "expected status $1, got $2"
}

make_stub() {
    local name="$1"
    local body="$2"
    printf '#!/usr/bin/env bash\n%s\n' "$body" > "$stub_dir/$name"
    chmod +x "$stub_dir/$name"
}
