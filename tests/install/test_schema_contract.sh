#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
schema_file="$script_dir/../../setup/call_center.sql"

fail() {
    printf 'FAIL schema_contract: %s\n' "$1" >&2
    exit 1
}

table_definition() {
    local table="$1"
    awk -v quoted_header="CREATE TABLE IF NOT EXISTS \`$table\` (" \
        -v plain_header="CREATE TABLE IF NOT EXISTS $table" '
        $0 == quoted_header || $0 == plain_header { found = 1 }
        found { print }
        found && /^\)[[:space:]]+ENGINE=/ { exit }
    ' "$schema_file"
}

require_column() {
    local definition="$1" table="$2" column="$3"
    tr -d '\`' <<< "$definition" |
        grep -Eq "(^|[[:space:]])$column[[:space:]]+int([[:space:]]*[(][0-9]+[)])?[[:space:]]+unsigned" ||
        fail "$table.$column is missing from the clean-install schema"
}

require_foreign_key() {
    local definition="$1" table="$2" column="$3"
    tr -d '\`' <<< "$definition" |
        grep -Eq "FOREIGN KEY[[:space:]]*[(][[:space:]]*$column[[:space:]]*[)][[:space:]]+REFERENCES[[:space:]]+campaign_external_url[[:space:]]*[(][[:space:]]*id[[:space:]]*[)]" ||
        fail "$table.$column foreign key is missing from the clean-install schema"
}

campaign_definition="$(table_definition campaign)"
campaign_entry_definition="$(table_definition campaign_entry)"

[[ -n "$campaign_definition" ]] || fail 'campaign table definition is missing'
[[ -n "$campaign_entry_definition" ]] || fail 'campaign_entry table definition is missing'

require_column "$campaign_definition" campaign id_url2
require_column "$campaign_definition" campaign id_url3
require_column "$campaign_entry_definition" campaign_entry id_url2
require_column "$campaign_entry_definition" campaign_entry id_url3
require_foreign_key "$campaign_definition" campaign id_url2
require_foreign_key "$campaign_definition" campaign id_url3
require_foreign_key "$campaign_entry_definition" campaign_entry id_url2
require_foreign_key "$campaign_entry_definition" campaign_entry id_url3

echo 'PASS: clean install schema satisfies campaign external URL contract'
