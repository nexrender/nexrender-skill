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

Template mutation endpoints still live under the v2 base URL:
`https://api.nexrender.com/api/v2/templates...`.

Template listing and structure reads should use the v3 endpoints:
`https://api.nexrender.com/api/v3/templates...`. The v3 OpenAPI paths are declared under the
`https://api.nexrender.com/api` server root, so do not join `/v3/...` onto `/api/v2`.

### POST /templates
Creates a template record. Without `src`, the response includes a presigned upload URL you must PUT
the file to. With `src`, Nexrender downloads the project file itself and the template can enter
`downloading` before `processing`.

**Request body:**
```json
{
  "displayName": "Product Promo",
  "type": "zip",
  "src": "https://cdn.example.com/templates/product-promo.zip"
}
```

`type` is required and must be `zip`, `aep`, or `mogrt`. `displayName` is required by the API schema.
`src` is optional; omit it for the standard presigned upload flow.

**OpenAPI upload response shape:**
```json
{
  "id": "01JTGM9GCR71JV7EJYDF45QAFD",
  "displayName": "Product Promo",
  "type": "zip",
  "status": "awaiting_upload",
  "uploadInfo": {
    "url": "https://nx1-assets-eu.cloudflarestorage.com/...?X-Amz-Expires=3600&...",
    "method": "PUT",
    "fields": {
      "Content-Type": "application/octet-stream"
    },
    "expiresIn": 3600,
    "key": "templates/..."
  }
}
```

Some deployments may wrap metadata as `{ "template": { ... }, "uploadInfo": { ... } }`; older
responses may return top-level `id`, `displayName`, `type`, `status`, and `uploadUrl` instead. Support
all known response shapes.

After receiving `uploadInfo.url` or legacy `uploadUrl`, PUT the file:
```bash
curl -X PUT "<uploadInfo.url-or-uploadUrl>" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@/path/to/template.aep"
```

The presigned upload URL is not a Nexrender API endpoint: do not send `Authorization: Bearer ...`.
Do not blindly copy `uploadInfo.fields` into headers; extra unsigned `x-amz-*` metadata can fail with
`MalformedSecurityHeader` (observed with `x-amz-meta-custom`). Poll `GET /v3/templates/{id}` or
legacy `GET /templates/{id}` until status is `uploaded` or `error`.

---

### GET /v3/templates
List lightweight template metadata for all templates available to the authenticated team.

Use this instead of deprecated `GET /templates` when listing templates. V3 list responses do not embed
composition or layer arrays; use the subresources below for parsed structure.

**Response:**
```json
[
  {
    "id": "01JTGM9GCR71JV7EJYDF45QAFD",
    "type": "zip",
    "displayName": "Product Promo",
    "status": "uploaded",
    "createdAt": "2025-05-05T16:25:59.961Z",
    "updatedAt": "2025-05-05T16:26:11.271Z"
  }
]
```

Template v3 statuses: `awaiting_upload`, `downloading`, `processing`, `uploaded`, `error`.

---

### GET /v3/templates/{id}
Fetch lightweight metadata for a single template. Use the v3 compositions and layers subresources to
inspect template structure.

`id` must be a ULID-style template identifier.

**Response:** one `TemplateV3` object with the same shape as the items from `GET /v3/templates`.

---

### GET /v3/templates/{id}/compositions
List paginated After Effects compositions discovered during template processing.

**Query parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `limit` | integer | Number of items to return. Defaults to 300; values above 1000 are capped to 1000. |
| `offset` | integer | Number of items to skip before returning results. Defaults to 0. |

**Response:**
```json
[
  {
    "aeid": "12",
    "name": "main",
    "width": 1920,
    "height": 1080,
    "duration": 8.5,
    "frame_rate": 29.97,
    "data": {}
  }
]
```

Use `name` as the job payload `template.composition`.

---

### GET /v3/templates/{id}/layers
List paginated After Effects layers discovered during template processing.

**Query parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `limit` | integer | Number of items to return. Defaults to 300; values above 1000 are capped to 1000. |
| `offset` | integer | Number of items to skip before returning results. Defaults to 0. |

**Response:**
```json
[
  {
    "composition_id": 12,
    "aeid": 5,
    "name": "headline",
    "top": 120,
    "left": 80,
    "width": 900,
    "height": 140,
    "start_time": 0,
    "in_point": 0,
    "out_point": 8.5,
    "layer_type": "TextLayer",
    "source_type": null,
    "source_comp_id": null,
    "parent_id": null,
    "data": {}
  }
]
```

Use `name` as the render job asset/function `layerName`. Match `composition_id` to the composition
`aeid` when you need to identify which composition owns the layer. `layer_type`, `source_type`,
timing, bounds, and `data` are parser metadata; keep job payload targeting based on exact names.

---

### GET /templates
Deprecated v2 template listing. It returns legacy full template objects, but will be removed in a
future release. Use `GET /v3/templates` for listing, then `GET /v3/templates/{id}/compositions` and
`GET /v3/templates/{id}/layers` for structure.

---

### GET /templates/{id}
Fetch a legacy full template object including discovered composition and layer name arrays.

**Response:**
```json
{
  "id": "01JTGM9GCR71JV7EJYDF45QAFD",
  "type": "zip",
  "displayName": "Product Promo",
  "status": "uploaded",
  "createdAt": "2025-05-05T16:25:59.961Z",
  "updatedAt": "2025-05-05T16:26:11.271Z",
  "compositions": ["main", "intro", "outro"],
  "layers": ["title", "subtitle", "background", "logo"],
  "mogrt": {},
  "error": null
}
```

This legacy endpoint only embeds names. For composition dimensions/duration or layer type/bounds/timing,
use the v3 subresources.

---

### PATCH /templates/{id}
Update display name only.

**Request body:** `{ "displayName": "New Name" }`

---

### DELETE /templates/{id}
Permanently delete a template and its data. The API returns `204 No Content` on success. Deletion can
return `409 Conflict` when the template is currently in use by active jobs.

---

### GET /templates/{id}/download
Returns a temporary presigned download URL for the original template file.

**Response:** `{ "url": "https://..." }`

---

### PUT /templates/{id}/upload
Returns a fresh presigned upload URL if you need to upload or replace the template file after a
previous URL expired.

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
