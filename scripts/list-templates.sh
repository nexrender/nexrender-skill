#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_nx-cloud.sh
. "$script_dir/_nx-cloud.sh"

raw=false
if [[ "${1:-}" == "--raw" || "${1:-}" == "-Raw" ]]; then
  raw=true
fi

response="$(nx_api GET /templates)"
if [[ "$raw" == true ]]; then
  printf '%s\n' "$response"
else
  printf '%s\n' "$response" | nx_json_pretty
fi
