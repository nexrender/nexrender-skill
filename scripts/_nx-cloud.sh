#!/usr/bin/env bash
set -euo pipefail

nx_status() {
  printf '%s\n' "$*" >&2
}

nx_die() {
  nx_status "$*"
  exit 1
}

nx_curl() {
  command -v curl >/dev/null 2>&1 || nx_die "curl is required for Nexrender Cloud calls but was not found on PATH."
  command -v curl
}

nx_python() {
  local candidate
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import json' >/dev/null 2>&1; then
      command -v "$candidate"
      return
    fi
  done
  nx_die "python3 or python is required by the Bash helper scripts for JSON parsing."
}

nx_api_key() {
  if [[ -n "${NEXRENDER_API_KEY:-}" ]]; then
    printf '%s\n' "$NEXRENDER_API_KEY"
    return
  fi

  if [[ -f ".env" ]]; then
    local py value
    py="$(nx_python)"
    value="$("$py" -c '
import re, sys
path = ".env"
raw = open(path, "rb").read()
for enc in ("utf-8-sig", "utf-16", "utf-8"):
    try:
        text = raw.decode(enc)
        break
    except UnicodeError:
        text = ""
else:
    text = raw.decode("utf-8", "ignore")
for line in text.splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    m = re.match(r"^(?:export\s+)?NEXRENDER_API_KEY\s*=\s*(.*)\s*$", line)
    if m:
        value = m.group(1).strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'\''":
            value = value[1:-1]
        if value:
            print(value)
            sys.exit(0)
sys.exit(1)
' 2>/dev/null || true)"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return
    fi
  fi

  nx_die "NEXRENDER_API_KEY was not found in the process environment or current project .env. Generate a team token from https://app.nexrender.com/team/settings and store it as NEXRENDER_API_KEY=... without committing .env."
}

nx_base_url() {
  local base="${NEXRENDER_BASE_URL:-https://api.nexrender.com/api/v2}"
  printf '%s\n' "${base%/}"
}

nx_url() {
  local path="$1"
  local base
  base="$(nx_base_url)"
  if [[ "$path" == /* ]]; then
    printf '%s%s\n' "$base" "$path"
  else
    printf '%s/%s\n' "$base" "$path"
  fi
}

nx_temp_json() {
  mktemp "${TMPDIR:-/tmp}/nx-cloud.XXXXXX.json"
}

nx_api() {
  local method="$1"
  local path="$2"
  local body_file="${3:-}"
  local token url curl_bin
  token="$(nx_api_key)"
  url="$(nx_url "$path")"
  curl_bin="$(nx_curl)"

  if [[ -n "$body_file" ]]; then
    "$curl_bin" -sS --fail-with-body -X "$method" "$url" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      --data-binary "@$body_file"
  else
    "$curl_bin" -sS --fail-with-body -X "$method" "$url" \
      -H "Authorization: Bearer $token"
  fi
}

nx_storage_put() {
  local upload_url="$1"
  local file_path="$2"
  local content_type="${3:-application/octet-stream}"
  local curl_bin
  curl_bin="$(nx_curl)"
  "$curl_bin" -sS --fail-with-body -X PUT "$upload_url" \
    -H "Content-Type: $content_type" \
    --data-binary "@$file_path" >/dev/null
}

nx_template_type() {
  local file_path="$1"
  local ext="${file_path##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    aep|zip|mogrt) printf '%s\n' "$ext" ;;
    *) nx_die "Unsupported template extension '$ext'. Expected .aep, .zip, or .mogrt." ;;
  esac
}

nx_normalize_template_upload_response() {
  "$(nx_python)" -c '
import json, sys
d = json.load(sys.stdin)
t = d.get("template") or d
u = d.get("uploadInfo") or {}
url = u.get("url") or d.get("uploadUrl") or d.get("url")
tid = t.get("id")
if not tid:
    raise SystemExit("Template response did not include a template id.")
if not url:
    raise SystemExit("Template response did not include uploadInfo.url or uploadUrl.")
print(tid)
print(url)
'
}

nx_json_status_progress() {
  "$(nx_python)" -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("status", ""))
print(d.get("progress", ""))
'
}

nx_json_pretty() {
  "$(nx_python)" -m json.tool
}
