# Nexrender Cloud API Reference

Base URL: `https://api.nexrender.com/api/v2`
Auth: `Authorization: Bearer $NEXRENDER_API_KEY` on every Nexrender API request.
Credentials: read `NEXRENDER_API_KEY` from the process environment first, then project `.env`. If it
is missing, have the user generate a team token at `https://app.nexrender.com/team/settings` and store
it as `NEXRENDER_API_KEY=...`. Never print the token value.

Use `curl` for Cloud calls (`curl.exe` on Windows PowerShell), with `--fail-with-body` for operations
that should surface response bodies on errors.

For up-to-date endpoint details, check the official docs before relying on stale local copies:
`https://docs.nexrender.com/api-reference`.

---

## Templates

### POST /templates
Creates a template record. Returns a presigned upload URL you must PUT the file to.

**Request body:**
```json
{
  "displayName": "Product Promo",   // optional
  "type": "zip"                     // "zip", "aep", or "mogrt"
}
```

**Response:**
```json
{
  "template": {
    "id": "01JTGM9GCR71JV7EJYDF45QAFD",
    "displayName": "Product Promo",
    "type": "zip",
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

Older responses may return top-level `id`, `displayName`, `type`, `status`, and `uploadUrl` instead.
Support both response shapes.

After receiving `uploadInfo.url` or legacy `uploadUrl`, PUT the file:
```bash
curl -X PUT "<uploadInfo.url-or-uploadUrl>" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@/path/to/template.aep"
```

The presigned upload URL is not a Nexrender API endpoint: do not send `Authorization: Bearer ...`.
Do not blindly copy `uploadInfo.fields` into headers; extra unsigned `x-amz-*` metadata can fail with
`MalformedSecurityHeader` (observed with `x-amz-meta-custom`). Poll `GET /templates/{id}` until
status is `uploaded` or `error`.

---

### GET /templates
List all templates in your team account.

**Response:** Array of template objects.

---

### GET /templates/{id}
Fetch a single template including discovered compositions and layers.
Template introspection returns names and composition association, not actual AE layer types. Use layer
names exactly; "text layer" discovery is name-based unless the official API adds richer typing.

**Response:**
```json
{
  "id": "01JTGM9GCR71JV7EJYDF45QAFD",
  "type": "zip",
  "displayName": "Product Promo",
  "status": "uploaded",
  "createdAt": "2025-05-05T16:25:59.961Z",
  "compositions": ["main", "intro", "outro"],
  "layers": ["title", "subtitle", "background", "logo"],
  "mogrt": {}
}
```

---

### PATCH /templates/{id}
Update display name only.

**Request body:** `{ "displayName": "New Name" }`

---

### DELETE /templates/{id}
Permanently delete a template.

---

### GET /templates/{id}/download
Returns a temporary presigned download URL for the original template file.

**Response:** `{ "url": "https://..." }`

---

### PUT /templates/{id}/upload
Returns a fresh presigned upload URL if you need to re-upload.

---

## Jobs

### POST /jobs
Submit a single render job. See `references/job-payload.md` for the full payload schema.

**Response:**
```json
{
  "id": "01JTRDF7HCR8QAHYW8GPCP4S9Y",
  "status": "queued",
  "progress": 0,
  "outputUrl": "https://nx1-outputs-eu.nexrender.com/.../job.mp4",
  "stats": { "createdAt": "2025-05-14T12:00:00.000Z" }
}
```
If fonts are missing, the response can include diagnostic values such as:
`"missingFonts": ["Roboto-Bold.ttf", "Soleil (Regular)"]`

These values may be uploaded file names or AE/internal font-family labels. Preview jobs can still finish
with fallback fonts, so treat `missingFonts` as a visual correctness warning.

---

### GET /jobs/{id}
Fetch current job state.

**Response (finished):**
```json
{
  "id": "...",
  "status": "finished",
  "progress": 100,
  "outputUrl": "https://...",
  "stats": {
    "createdAt": "...",
    "finishedAt": "...",
    "renderDuration": 22.304
  }
}
```

**Response (error):**
```json
{
  "id": "...",
  "status": "error",
  "stats": {
    "errorAt": "...",
    "error": "Layer 'title' not found in composition 'main'"
  }
}
```

---

### GET /jobs
List jobs with optional filters.

**Query parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `states` | string | Comma-separated statuses: `queued,pending,render:dorender,finished,error,manually_cancelled` |
| `exclude_states` | string | Statuses to exclude |
| `from` | integer | Pagination offset (0-indexed) |
| `limit` | integer | 1-1000 jobs per request |
| `from_date` | string | ISO 8601 created-after filter |
| `to_date` | string | ISO 8601 created-before filter |
| `sort` | string | `oldest_first` (default), `newest_first`, `random`, `priority` |
| `tags` | string | Comma-separated tags |
| `minimal` | boolean | Strip stats and assets for faster responses |

---

### PATCH /jobs/{id}/cancel
Cancel a single job. Returns an array of all cancelled jobs (including cascaded children/parents).

---

### POST /jobs/cancel
Cancel multiple jobs at once.

**Request body:**
```json
{ "jobs": ["01JOB_ID_1", "01JOB_ID_2"] }
```
**Response:** Array of cancelled job objects.

---

### POST /jobs/join
Submit a join (stitch) job. See `references/workflows.md` for join job details.

---

## Batches

### POST /batches
Submit up to 1,000 jobs in one request.

**Request body:**
```json
{
  "jobs": [ /* array of standard job payloads */ ]
}
```

**Response:**
```json
{
  "batchId": "01BATCH_ID",
  "status": "created",   // "created" | "partial" | "error"
  "totalJobs": 2,
  "successCount": 2,
  "jobs": [
    { "index": 0, "id": "...", "status": "queued", "outputUrl": "..." }
  ],
  "errors": []   // only present when status is "partial" or "error"
}
```

---

### GET /batches/{id}
Poll aggregate batch progress.

**Response:**
```json
{
  "batchId": "...",
  "status": "processing",  // "processing" | "finished" | "error"
  "stats": { "total": 100, "finished": 67, "error": 2, "pending": 31 },
  "jobs": [ /* array of job objects */ ]
}
```

---

### POST /batches/{id}/cancel
Cancel all remaining jobs in a batch.

---

## Fonts

### POST /fonts
Upload a `.ttf` font file (multipart/form-data).

**Fields:**
- `font` (file, required): the `.ttf` file
- `familyName` (string, optional): override auto-detected family name

**Response:**
```json
{
  "id": "01JTGM9GCR71JV7EJYDF45QAFD",
  "fileName": "Montserrat-SemiBold.ttf",
  "familyName": "Montserrat",
  "createdAt": "2025-05-05T16:25:59.961Z"
}
```

---

### GET /fonts
List all uploaded fonts.

---

### GET /fonts/{id}
Fetch a single font record.

---

### DELETE /fonts/{id}
Delete a font.

---

## Secrets

### PUT /secrets
Create a secret (upsert by name).

**Request body:**
```json
{ "name": "AWS_ACCESS_KEY_ID", "value": "AKIAIOSFODNN7EXAMPLE" }
```

**Response:** `{ "id": "...", "name": "AWS_ACCESS_KEY_ID", "createdAt": "..." }`

If a secret with the same name already exists, returns error `SECRET_ALREADY_EXISTS`.

---

### GET /secrets
List all secrets (names and IDs only - values are never returned).

---

### DELETE /secrets/{id}
Delete a secret. Returns `200 OK` with no body.
