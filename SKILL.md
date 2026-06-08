---
name: nexrender
description: >
  Expert knowledge of the Nexrender Cloud API for automated After Effects rendering. Use this skill
  whenever anyone asks about: submitting render jobs, building job payloads, asset injection, template
  management, batch rendering, nested/join jobs, output settings, webhooks, secrets, fonts, clean room
  setup, or debugging failed renders. Also use it when a user is writing code that calls the Nexrender
  API, troubleshooting a render error, or designing a video automation workflow with Nexrender. If the
  conversation touches Nexrender at all - even incidentally - load this skill.
---

# Nexrender Cloud API Skill

This skill gives you authoritative knowledge of Nexrender Cloud so you can help users build correct
job payloads, debug render failures, design workflows, and write API integrations without guessing.

## Quick constants (always useful)

- **Base URL**: `https://api.nexrender.com/api/v2`
- **Auth header**: `Authorization: Bearer $NEXRENDER_API_KEY`
- **Standard token variable**: `NEXRENDER_API_KEY`
- **Secret reference syntax**: `${secrets.NAME}` (plural `secrets`, single braces - never `${secret.NAME}`)
- **Default AE engine**: `ae2026` (also available: `ae2025`)
- **Official docs**: `https://docs.nexrender.com`

## Cloud auth bootstrap

Before calling Nexrender Cloud, look for `NEXRENDER_API_KEY` in the process environment, then in the
current project's `.env`. If it is missing, guide the user to generate an API token from the Nexrender
team settings/dashboard (`https://app.nexrender.com/team/settings`, or the dashboard API-token page
linked from the current docs) and store it as:

```dotenv
NEXRENDER_API_KEY=...
```

Treat `.env` as secret material. Before writing or asking the user to write it, check whether the file
is untracked/ignored when the workspace is a git repo. Never print token values; report only whether a
token was found, the variable name used, and the API result.

## Cloud API execution policy

Use `curl` for Nexrender Cloud calls. On Windows PowerShell, prefer `curl.exe` explicitly so PowerShell
does not alias the command. Avoid `Invoke-RestMethod`, `Invoke-WebRequest`, and ad hoc native HTTP
clients for Cloud operations.

Use `--fail-with-body` and explicit headers. In PowerShell, always write JSON request bodies to temp
files and send them with `--data-binary "@file"`; do not use inline JSON or `--data-raw`. Keep binary
uploads as `--data-binary "@path/to/file"`.

## Helper scripts

Prefer the bundled scripts for common Cloud tasks so auth loading, temp JSON, curl, uploads, and
polling stay consistent:

| Task | PowerShell | Bash |
|------|------------|------|
| List templates | `scripts/list-templates.ps1` | `scripts/list-templates.sh` |
| Upload font | `scripts/upload-font.ps1` | `scripts/upload-font.sh` |
| Upload template | `scripts/upload-template.ps1` | `scripts/upload-template.sh` |
| Create preview job | `scripts/create-preview-job.ps1` | `scripts/create-preview-job.sh` |
| Poll job | `scripts/poll-job.ps1` | `scripts/poll-job.sh` |

Use raw `curl` only for endpoints not covered by these scripts. The Bash variants use Bash + curl and
Python's standard JSON library; they do not require `jq`.

## Online docs policy

This skill carries curated operational guidance, not a full local docs mirror. When exact endpoint
shape, dashboard location, status values, codecs, upload fields, or newly added Cloud behavior may have
changed, check the official Nexrender docs before acting or advising:

- Cloud quickstart: `https://docs.nexrender.com/cloud/quickstart`
- Template basics: `https://docs.nexrender.com/cloud/templates/basics`
- Template registration: `https://docs.nexrender.com/cloud/templates/register_template`
- API reference: `https://docs.nexrender.com/api-reference`

Prefer the online docs over any stale local documentation dump. Keep durable lessons learned here in
`SKILL.md` or the curated files under `references/`.

## Job status values

| Status | Meaning |
|--------|---------|
| `queued` | Waiting for a render worker |
| `pending` | Parent job waiting for child jobs (nested/join only) |
| `render:dorender` | Actively rendering |
| `finished` | Done - `outputUrl` is populated |
| `error` | Failed - check `stats.error` for the message |
| `manually_cancelled` | Cancelled via API |

Only `queued` and `pending` can be cancelled.

## Template status values

| Status | Meaning |
|--------|---------|
| `awaiting_upload` | Created but file not yet uploaded |
| `processing` | File received, being introspected |
| `uploaded` | Ready to use in jobs |
| `error` | Processing failed |

## When to read the reference files

Load these when the user needs more than the basics above:

- **`references/pipeline-guide.md`** - End-to-end workflow: fonts → template upload → introspection
  → job submission → tracking. Also covers batch, nested jobs, and functions with when/how guidance.
  Read when: user is getting started, asking how to set up a workflow, asking about the full pipeline,
  or asking about functions and when to use each one.

- **`references/api-reference.md`** - Full endpoint list, request/response shapes, query params.
  Read when: listing jobs, filtering, template management endpoints, fonts/secrets endpoints.

- **`references/job-payload.md`** - Complete job payload schema with every asset type fully documented.
  Read when: constructing any job payload, choosing asset types, using `data` vs `text`, injecting
  audio/video/image assets, using functions, understanding `composition` targeting.

- **`references/workflows.md`** - In-depth patterns: batch jobs, nested jobs, join jobs, clean room
  setup, secrets management, custom upload configs. Read when: user needs deeper detail on any of
  these patterns beyond what the pipeline guide covers.

## Critical correctness rules

These are the most common sources of bugs - always apply them:

1. **Codec identifiers are always fully prefixed** - `video_h264_vbr_15mbps`, `image_png`, `video_prores_422`.
   Never use short forms like `h264` or `png` alone.

2. **`settings` and `preview: true` are mutually exclusive** - if `preview` is set, `settings` is ignored.

3. **`missingFonts` in a job response** is a correctness warning, not just bookkeeping. It can contain
   uploaded-file names (for example `TestFont.ttf`) or AE/internal font-family labels (for example
   `Soleil (Regular)`). Previews may still finish with fallback fonts. Upload/repair the fonts and
   resubmit before trusting visual output.

4. **Two-step template upload** - `POST /templates` creates a record and returns either legacy
   `uploadUrl` or current `uploadInfo.url` plus `template`. Then `PUT` the file directly to that URL
   without Nexrender auth headers. Use a minimal binary PUT with `Content-Type: application/octet-stream`.
   Do not blindly copy `uploadInfo.fields` into headers; extra unsigned `x-amz-*` metadata can fail with
   `MalformedSecurityHeader`. Upload URLs are temporary, usually about 1 hour; call
   `PUT /templates/{id}/upload` if one expires. The template is usable only after polling
   `GET /templates/{id}` until status becomes `uploaded`.

5. **`template.src`** bypasses Nexrender storage entirely (clean room). When used, `template.id` is still
   required as a reference identifier but template introspection (compositions/layers) is not available.

6. **Layer names must match exactly** - Nexrender requires exact `layerName` matches against After Effects
   layer names. Case-sensitive. Template introspection returns `layerName` and `composition`, but not
   the actual AE layer type; "text layer" discovery is name-based unless the official API adds richer
   typing. Typos cause silent render errors.

7. **Webhook endpoints must return `2xx`** - Nexrender retries up to 3 times with exponential backoff.
   Make handlers idempotent and respond immediately.
