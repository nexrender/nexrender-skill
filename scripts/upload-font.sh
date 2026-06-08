#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_nx-cloud.sh
. "$script_dir/_nx-cloud.sh"

font_path=""
family_name=""
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path|-Path)
      font_path="${2:-}"
      shift 2
      ;;
    --family-name|-FamilyName)
      family_name="${2:-}"
      shift 2
      ;;
    --dry-run|-DryRun)
      dry_run=true
      shift
      ;;
    *)
      if [[ -z "$font_path" ]]; then
        font_path="$1"
        shift
      else
        nx_die "Unknown argument: $1"
      fi
      ;;
  esac
done

[[ -n "$font_path" ]] || nx_die "Usage: upload-font.sh --path <font.ttf> [--family-name <name>] [--dry-run]"
[[ -f "$font_path" ]] || nx_die "Font file not found: $font_path"
[[ "${font_path##*.}" == "ttf" || "${font_path##*.}" == "TTF" ]] || nx_die "Nexrender Cloud font uploads support .ttf files only."

if [[ "$dry_run" == true ]]; then
  NX_FONT_PATH="$font_path" NX_FAMILY_NAME="$family_name" "$(nx_python)" -c '
import json, os
print(json.dumps({
  "dryRun": True,
  "method": "POST",
  "path": "/fonts",
  "font": os.environ["NX_FONT_PATH"],
  "familyName": os.environ.get("NX_FAMILY_NAME") or None
}, indent=2))
'
  exit 0
fi

token="$(nx_api_key)"
url="$(nx_url /fonts)"
curl_bin="$(nx_curl)"
args=(-sS --fail-with-body -X POST "$url" -H "Authorization: Bearer $token" -F "font=@$font_path")
if [[ -n "$family_name" ]]; then
  args+=(-F "familyName=$family_name")
fi
"$curl_bin" "${args[@]}" | nx_json_pretty
