#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_nx-cloud.sh
. "$script_dir/_nx-cloud.sh"

job_id=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-id|-JobId)
      job_id="${2:-}"
      shift 2
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

[[ -n "$job_id" ]] || nx_die "Usage: get-job-logs.sh --job-id <id>"

nx_api GET "/jobs/$job_id/logs"
