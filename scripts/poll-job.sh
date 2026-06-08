#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_nx-cloud.sh
. "$script_dir/_nx-cloud.sh"

job_id=""
interval_seconds=5
timeout_seconds=900
raw=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-id|-JobId)
      job_id="${2:-}"
      shift 2
      ;;
    --interval-seconds|-IntervalSeconds)
      interval_seconds="${2:-}"
      shift 2
      ;;
    --timeout-seconds|-TimeoutSeconds)
      timeout_seconds="${2:-}"
      shift 2
      ;;
    --raw|-Raw)
      raw=true
      shift
      ;;
    *)
      if [[ -z "$job_id" ]]; then
        job_id="$1"
        shift
      else
        nx_die "Unknown argument: $1"
      fi
      ;;
  esac
done

[[ -n "$job_id" ]] || nx_die "Usage: poll-job.sh --job-id <id> [--interval-seconds 5] [--timeout-seconds 900] [--raw]"

deadline=$(( $(date +%s) + timeout_seconds ))
last_job=""

while true; do
  last_job="$(nx_api GET "/jobs/$job_id")"
  status_progress="$(printf '%s\n' "$last_job" | nx_json_status_progress)"
  status="$(printf '%s\n' "$status_progress" | sed -n '1p')"
  progress="$(printf '%s\n' "$status_progress" | sed -n '2p')"
  nx_status "job $job_id: $status ${progress}%"

  if [[ "$status" == "finished" ]]; then
    if [[ "$raw" == true ]]; then printf '%s\n' "$last_job"; else printf '%s\n' "$last_job" | nx_json_pretty; fi
    exit 0
  fi

  if [[ "$status" == "error" ]]; then
    if [[ "$raw" == true ]]; then printf '%s\n' "$last_job"; else printf '%s\n' "$last_job" | nx_json_pretty; fi
    exit 2
  fi

  if [[ "$(date +%s)" -ge "$deadline" ]]; then
    NX_JOB_ID="$job_id" NX_TIMEOUT_SECONDS="$timeout_seconds" NX_LAST_JOB="$last_job" "$(nx_python)" -c '
import json, os
try:
    last_job = json.loads(os.environ.get("NX_LAST_JOB") or "null")
except Exception:
    last_job = os.environ.get("NX_LAST_JOB")
print(json.dumps({
  "id": os.environ["NX_JOB_ID"],
  "status": "timeout",
  "timeoutSeconds": int(os.environ["NX_TIMEOUT_SECONDS"]),
  "lastJob": last_job
}, indent=2))
'
    exit 3
  fi

  sleep "$interval_seconds"
done
