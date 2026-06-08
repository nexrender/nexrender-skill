# Nexrender Pipeline Guide

End-to-end walkthrough of the typical Nexrender workflow, from first-time setup through tracking results.

For current product details, treat the online docs as source of truth:
`https://docs.nexrender.com/cloud/quickstart`, `https://docs.nexrender.com/cloud/templates/basics`,
`https://docs.nexrender.com/cloud/templates/register_template`, and `https://docs.nexrender.com/api-reference`.

## Step 0 - Authenticate

Before calling Nexrender Cloud, read `NEXRENDER_API_KEY` from the process environment or the current
project's `.env`. If it is missing, ask the user to generate an API token in the Nexrender team
settings/dashboard (`https://app.nexrender.com/team/settings`, or the dashboard API-token page linked
from the current docs) and store it in project `.env`:

```dotenv
NEXRENDER_API_KEY=...
```

Treat `.env` as secret material. In git workspaces, check that `.env` is untracked or ignored before
writing it. Never echo the token value; only report that `NEXRENDER_API_KEY` was found and whether the
API call succeeded.

Use bundled scripts for common tasks:

- PowerShell: `scripts/list-templates.ps1`, `scripts/upload-font.ps1`, `scripts/upload-template.ps1`,
  `scripts/create-preview-job.ps1`, `scripts/poll-job.ps1`
- Bash: `scripts/list-templates.sh`, `scripts/upload-font.sh`, `scripts/upload-template.sh`,
  `scripts/create-preview-job.sh`, `scripts/poll-job.sh`

For raw Cloud calls, use `curl` (`curl.exe` on Windows PowerShell). Avoid PowerShell native HTTP
clients. In PowerShell, write JSON bodies to temp files and send with `--data-binary "@file"`; do not
use inline JSON or `--data-raw`.

---

## Step 1 — Upload fonts (once, reuse forever)

Fonts need to be installed on the render worker before After Effects starts. Upload each `.ttf` file once to your team account and reference it by filename in every job that needs it.

```bash
curl -X POST https://api.nexrender.com/api/v2/fonts \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -F "font=@/path/to/Montserrat-SemiBold.ttf"
```

Response:
```json
{
  "id": "01JTGM9GCR71JV7EJYDF45QAFD",
  "fileName": "Montserrat-SemiBold.ttf",
  "familyName": "Montserrat"
}
```

- Fonts are team-scoped - upload once, use across all jobs
- Only `.ttf` format is supported
- To override the auto-detected family name: add `-F "familyName=My Brand Font"`
- To list all uploaded fonts: `GET /fonts`
- To remove a font: `DELETE /fonts/{id}`
- If job creation returns `missingFonts`, treat it as a visual correctness warning. Values may be
  uploaded file names like `TestFont.ttf` or AE/internal labels like `Soleil (Regular)`. Previews can
  still finish with fallback fonts, so repair fonts before trusting output.

---

## Step 2 — Upload a template (two-step process)

Templates require two API calls: create a record to get a presigned upload URL, then PUT the file directly to that URL.

### 2a. Create the template record

```bash
curl -X POST https://api.nexrender.com/api/v2/templates \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@template-create.json"
```

Where `template-create.json` contains `{ "displayName": "Product Promo", "type": "zip" }`.

Response:
```json
{
  "template": {
    "id": "01JTGM9GCR71JV7EJYDF45QAFD",
    "status": "awaiting_upload"
  },
  "uploadInfo": {
    "url": "https://nx1-assets-eu.cloudflarestorage.com/...?X-Amz-Expires=3600&...",
    "method": "PUT",
    "fields": {
      "Content-Type": "application/octet-stream"
    }
  }
}
```

Older responses may return `id` and `uploadUrl` at the top level instead. Support both shapes.

Supported types: `zip` (`.aep` + assets), `aep`, `mogrt`. Prefer `zip` when the project has external
assets or fonts that need to travel with the After Effects project.

### 2b. Upload the file to the presigned URL

```bash
curl -X PUT "<uploadInfo.url-or-uploadUrl>" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@/path/to/template.aep"
```

The presigned upload is a storage PUT, not a Nexrender API call. Do not send `Authorization: Bearer ...`
to the presigned URL. Do not blindly copy `uploadInfo.fields` into headers; extra unsigned `x-amz-*`
metadata headers can fail with `MalformedSecurityHeader` (observed with `x-amz-meta-custom`). Use the
minimal binary PUT above unless the returned URL explicitly signs and requires an extra header.

The template moves `awaiting_upload` -> `processing` -> `uploaded` (takes a few seconds). Poll
`GET /templates/{id}` until status is `uploaded` or `error`. The presigned URL expires after 1 hour - if
it expires, call `PUT /templates/{id}/upload` for a fresh one.

Typical lifecycle: create the template, upload the file to `uploadInfo.url`, wait for `uploaded`, inspect
`compositions` and `layers`, then submit jobs referencing the template ID.

---

## Step 3 — Introspect the template

Once status is `uploaded`, fetch the template to discover what compositions and layers are available. This is how you know exactly what to reference in your job payload.

```bash
curl https://api.nexrender.com/api/v2/templates/01JTGM9GCR71JV7EJYDF45QAFD \
  -H "Authorization: Bearer YOUR_API_KEY"
```

Response:
```json
{
  "id": "01JTGM9GCR71JV7EJYDF45QAFD",
  "status": "uploaded",
  "compositions": ["main", "intro", "outro"],
  "layers": ["title", "subtitle", "logo", "background", "cta"]
}
```

Use `compositions` to set `template.composition` in jobs. Use `layers` to validate your `layerName`
values before submitting - layer names must match exactly (case-sensitive). Introspection returns
`layerName` and `composition`, but not the actual AE layer type; identifying "text layers" is name-based
unless Nexrender adds richer type metadata.

---

## Step 4 — Configure and submit a job

With fonts uploaded, template ready, and layer names confirmed, submit the render job:

```bash
curl -X POST https://api.nexrender.com/api/v2/jobs \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@job-payload.json"
```

Write the job payload JSON to `job-payload.json` first; this avoids PowerShell quoting failures.

Response:
```json
{
  "id": "01JTRDF7HCR8QAHYW8GPCP4S9Y",
  "status": "queued",
  "outputUrl": "https://nx1-outputs-eu.nexrender.com/.../job.mp4"
}
```

Save the `id` - you'll use it to track the job. The `outputUrl` is pre-generated but only resolves once the job reaches `finished`.

---

## Step 5 — Track results

### Option A: Poll (simple)

```bash
curl https://api.nexrender.com/api/v2/jobs/01JTRDF7HCR8QAHYW8GPCP4S9Y \
  -H "Authorization: Bearer YOUR_API_KEY"
```

Poll every 5-30 seconds until `status` is `finished` or `error`.

```json
// finished
{ "id": "...", "status": "finished", "outputUrl": "https://...", "stats": { "renderDuration": 22.3 } }

// error
{ "id": "...", "status": "error", "stats": { "error": "Layer 'title' not found in composition 'main'" } }
```

### Option B: Webhook (recommended for production)

Add `"webhook": { "url": "..." }` to the job payload. Nexrender POSTs the full job object to your endpoint when it reaches a terminal state. Your endpoint must return `2xx`. Retries up to 3 times with exponential backoff.

---

## Batch variant — 500 personalized videos

When you have many jobs to run from the same template, use `POST /batches` instead of submitting jobs one at a time. Accepts up to 1,000 jobs in a single request.

```bash
curl -X POST https://api.nexrender.com/api/v2/batches \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@batch-payload.json"
```

Track aggregate progress with `GET /batches/{batchId}` - returns `stats.finished`, `stats.pending`, `stats.error`, `stats.total`. Cancel all remaining jobs at once with `POST /batches/{batchId}/cancel`.

Batches support partial success - failed jobs appear in the `errors` array while successful ones proceed. Check `status`: `"created"` (all ok), `"partial"` (some failed), `"error"` (all failed).

---

## Nested jobs — composite child renders into a parent

Use nested jobs when a child composition needs to render first and its output is then composited as a layer inside the parent. Define it inline as `type: "job"` inside the parent's `assets` array - no separate API call needed.

```json
{
  "template": { "id": "PARENT_TMPL", "composition": "final-scene" },
  "assets": [
    {
      "type": "job",
      "layerName": "LowerThird",
      "template": { "id": "LOWER_THIRD_TMPL", "composition": "name-card" },
      "assets": [
        { "type": "text", "layerName": "name", "value": "Jane Smith" },
        { "type": "text", "layerName": "title", "value": "Lead Designer" }
      ]
    },
    { "type": "image", "layerName": "background", "src": "https://cdn.example.com/bg.jpg" }
  ]
}
```

How it works:
1. Nexrender creates and renders the child job
2. Parent waits in `pending` until child reaches `finished`
3. Child's `outputUrl` is injected into the `LowerThird` layer
4. Parent renders and reaches `finished`

Multiple nested job assets render in parallel - the parent waits for all of them.

**Nested vs. Join:** Use nested when compositing into an AE composition. Use `POST /jobs/join` when concatenating clips end-to-end into a linear video.

---

## Functions — scripted layer manipulation

Functions are built-in helpers that run as ExtendScript inside After Effects before rendering. Add them to the `assets` array as `type: "function"`.

### When to use functions vs. plain assets

| Task | Use |
|------|-----|
| Replace text content | `type: "text"` or `type: "data"` |
| Replace image/video source | `type: "image"` / `type: "video"` |
| Change text font, size, color, tracking | `type: "function"` → `nx-text-params-set` |
| Change a solid layer's fill color | `type: "function"` → `nx-solid-color-set` |
| Show or hide a layer | `type: "function"` → `nx-layer-state-set` |
| Remove a layer entirely | `type: "function"` → `nx-layer-remove` |
| Shrink font to fit a text box | `type: "function"` → `nx-layer-autoscale` |
| Shift a layer's start time | `type: "function"` → `nx-layer-start-set` |
| Change a layer's duration | `type: "function"` → `nx-layer-duration-set` |
| Change a composition's duration | `type: "function"` → `nx-comp-duration-set` |
| Generate an AI image and inject it | `type: "function"` → `nx-gen-ai` |

### Examples

**Hide or show a layer:**
```json
{ "type": "function", "name": "nx-layer-state-set", "layerName": "PromoTag", "params": { "state": "hidden" } }
{ "type": "function", "name": "nx-layer-state-set", "layerName": "PromoTag", "params": { "state": "visible" } }
```

**Set text style (font, size, color, tracking):**
```json
{
  "type": "function",
  "name": "nx-text-params-set",
  "layerName": "headline",
  "params": {
    "fontSize": 72,
    "fillColor": [1.0, 0.5, 0.0],
    "tracking": 50,
    "font": "Montserrat-SemiBold"
  }
}
```

**Change a solid layer's color:**
```json
{
  "type": "function",
  "name": "nx-solid-color-set",
  "layerName": "BackgroundSolid",
  "params": { "color": [0.1, 0.4, 0.9] }
}
```

**Generate an AI image and inject it as a layer source:**
```json
{
  "type": "function",
  "name": "nx-gen-ai",
  "layerName": "hero-image",
  "params": {
    "provider": "openai",
    "model": "gpt-image-1",
    "prompt": "A minimalist product shot on white background",
    "apiKey": "${secrets.OPENAI_API_KEY}"
  }
}
```

**Auto-shrink text to fit bounds:**
```json
{
  "type": "function",
  "name": "nx-layer-autoscale",
  "layerName": "description",
  "params": { "maxFontSize": 48, "minFontSize": 12 }
}
```

Functions and regular asset types can coexist freely in the same `assets` array.
