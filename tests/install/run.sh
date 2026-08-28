#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for test_file in "$script_dir"/test_*.sh; do
    bash "$test_file"
done

if [[ -f "$script_dir/test_installer_lib.php" ]]; then
    command -v php >/dev/null || {
        echo 'ERROR: PHP is required for installer_lib tests' >&2
        exit 1
    }
    php "$script_dir/test_installer_lib.php"
fi
