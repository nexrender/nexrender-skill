#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_nx-cloud.sh
. "$script_dir/_nx-cloud.sh"

raw=false
legacy=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --raw|-Raw)
      raw=true
      ;;
    --legacy|-Legacy)
      legacy=true
      ;;
    *)
      nx_die "Usage: list-templates.sh [--raw] [--legacy]"
      ;;
  esac
  shift
done

path="/v3/templates"
if [[ "$legacy" == true ]]; then
  path="/templates"
fi

response="$(nx_api GET "$path")"
if [[ "$raw" == true ]]; then
  printf '%s\n' "$response"
else
  printf '%s\n' "$response" | nx_json_pretty
fi
