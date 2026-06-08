#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_nx-cloud.sh
. "$script_dir/_nx-cloud.sh"

template_path=""
display_name=""
template_type=""
timeout_seconds=180
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path|-Path)
      template_path="${2:-}"
      shift 2
      ;;
    --display-name|-DisplayName)
      display_name="${2:-}"
      shift 2
      ;;
    --type|-Type)
      template_type="${2:-}"
      shift 2
      ;;
    --timeout-seconds|-TimeoutSeconds)
      timeout_seconds="${2:-}"
      shift 2
      ;;
    --dry-run|-DryRun)
      dry_run=true
      shift
      ;;
    *)
      if [[ -z "$template_path" ]]; then
        template_path="$1"
        shift
      else
        nx_die "Unknown argument: $1"
      fi
      ;;
  esac
done

[[ -n "$template_path" ]] || nx_die "Usage: upload-template.sh --path <template.aep|zip|mogrt> [--display-name <name>] [--type <aep|zip|mogrt>] [--timeout-seconds 180] [--dry-run]"
[[ -f "$template_path" ]] || nx_die "Template file not found: $template_path"
if [[ -z "$template_type" ]]; then
  template_type="$(nx_template_type "$template_path")"
fi
case "$template_type" in
  aep|zip|mogrt) ;;
  *) nx_die "Unsupported template type '$template_type'. Expected aep, zip, or mogrt." ;;
esac
if [[ -z "$display_name" ]]; then
  base="$(basename "$template_path")"
  display_name="${base%.*}"
fi

payload_file="$(nx_temp_json)"
trap 'rm -f "$payload_file"' EXIT
NX_PAYLOAD_FILE="$payload_file" NX_DISPLAY_NAME="$display_name" NX_TEMPLATE_TYPE="$template_type" "$(nx_python)" -c '
import json, os
with open(os.environ["NX_PAYLOAD_FILE"], "w", encoding="utf-8") as f:
    json.dump({"displayName": os.environ["NX_DISPLAY_NAME"], "type": os.environ["NX_TEMPLATE_TYPE"]}, f, separators=(",", ":"))
'

if [[ "$dry_run" == true ]]; then
  NX_PAYLOAD_FILE="$payload_file" NX_TEMPLATE_PATH="$template_path" NX_TIMEOUT_SECONDS="$timeout_seconds" "$(nx_python)" -c '
import json, os
with open(os.environ["NX_PAYLOAD_FILE"], encoding="utf-8") as f:
    payload = json.load(f)
print(json.dumps({
  "dryRun": True,
  "create": {"method": "POST", "path": "/templates", "payload": payload, "bodyTransport": "--data-binary @temp-json-file"},
  "upload": {"file": os.environ["NX_TEMPLATE_PATH"], "contentType": "application/octet-stream", "authHeader": False, "copyUploadInfoFields": False},
  "poll": {"path": "/templates/{id}", "timeoutSeconds": int(os.environ["NX_TIMEOUT_SECONDS"])}
}, indent=2))
'
  exit 0
fi

nx_status "creating template '$display_name'"
created="$(nx_api POST /templates "$payload_file")"
normalized="$(printf '%s\n' "$created" | nx_normalize_template_upload_response)"
template_id="$(printf '%s\n' "$normalized" | sed -n '1p')"
upload_url="$(printf '%s\n' "$normalized" | sed -n '2p')"

nx_status "uploading template file to presigned storage URL for $template_id"
nx_storage_put "$upload_url" "$template_path" "application/octet-stream"

deadline=$(( $(date +%s) + timeout_seconds ))
while true; do
  template="$(nx_api GET "/templates/$template_id")"
  status="$(printf '%s\n' "$template" | "$(nx_python)" -c 'import json,sys; print(json.load(sys.stdin).get("status",""))')"
  nx_status "template $template_id: $status"
  if [[ "$status" == "uploaded" || "$status" == "error" ]]; then
    printf '%s\n' "$template" | nx_json_pretty
    exit 0
  fi
  if [[ "$(date +%s)" -ge "$deadline" ]]; then
    nx_die "Timed out waiting for template $template_id to become uploaded."
  fi
  sleep 2
done
