#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_nx-cloud.sh
. "$script_dir/_nx-cloud.sh"

template_id=""
composition=""
assets_json=""
fonts_json=""
webhook_url=""
dry_run=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template-id|-TemplateId)
      template_id="${2:-}"
      shift 2
      ;;
    --composition|-Composition)
      composition="${2:-}"
      shift 2
      ;;
    --assets-json|-AssetsJson)
      assets_json="${2:-}"
      shift 2
      ;;
    --fonts-json|-FontsJson)
      fonts_json="${2:-}"
      shift 2
      ;;
    --webhook-url|-WebhookUrl)
      webhook_url="${2:-}"
      shift 2
      ;;
    --dry-run|-DryRun)
      dry_run=true
      shift
      ;;
    *)
      nx_die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$template_id" && -n "$composition" ]] || nx_die "Usage: create-preview-job.sh --template-id <id> --composition <name> [--assets-json <path>] [--fonts-json <path>] [--webhook-url <url>] [--dry-run]"
[[ -z "$assets_json" || -f "$assets_json" ]] || nx_die "Assets JSON file not found: $assets_json"
[[ -z "$fonts_json" || -f "$fonts_json" ]] || nx_die "Fonts JSON file not found: $fonts_json"

payload_file="$(nx_temp_json)"
trap 'rm -f "$payload_file"' EXIT
NX_TEMPLATE_ID="$template_id" NX_COMPOSITION="$composition" NX_ASSETS_JSON="$assets_json" NX_FONTS_JSON="$fonts_json" NX_WEBHOOK_URL="$webhook_url" NX_PAYLOAD_FILE="$payload_file" "$(nx_python)" -c '
import json, os
payload = {
    "template": {"id": os.environ["NX_TEMPLATE_ID"], "composition": os.environ["NX_COMPOSITION"]},
    "preview": True,
    "assets": []
}
assets_path = os.environ.get("NX_ASSETS_JSON")
if assets_path:
    with open(assets_path, encoding="utf-8") as f:
        payload["assets"] = json.load(f)
fonts_path = os.environ.get("NX_FONTS_JSON")
if fonts_path:
    with open(fonts_path, encoding="utf-8") as f:
        payload["fonts"] = json.load(f)
webhook_url = os.environ.get("NX_WEBHOOK_URL")
if webhook_url:
    payload["webhook"] = {"url": webhook_url}
with open(os.environ["NX_PAYLOAD_FILE"], "w", encoding="utf-8") as f:
    json.dump(payload, f, separators=(",", ":"))
'

if [[ "$dry_run" == true ]]; then
  NX_PAYLOAD_FILE="$payload_file" "$(nx_python)" -c '
import json, os
with open(os.environ["NX_PAYLOAD_FILE"], encoding="utf-8") as f:
    payload = json.load(f)
print(json.dumps({
  "dryRun": True,
  "method": "POST",
  "path": "/jobs",
  "bodyTransport": "--data-binary @temp-json-file",
  "payload": payload,
  "settingsOmittedBecausePreview": True
}, indent=2))
'
  exit 0
fi

nx_api POST /jobs "$payload_file" | nx_json_pretty
