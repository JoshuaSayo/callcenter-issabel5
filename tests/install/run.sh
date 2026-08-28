#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_files=("$script_dir"/test_*.sh)
for test_file in "${test_files[@]}"; do
    bash "$test_file"
done

command -v php >/dev/null || {
    echo 'ERROR: PHP is required for installer_lib tests' >&2
    exit 1
}
php "$script_dir/test_installer_lib.php"
php "$script_dir/test_installer_entry.php"
