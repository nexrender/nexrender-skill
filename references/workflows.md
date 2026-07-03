# Nexrender Workflow Patterns

## 1. Template Management

### Two-step upload flow
Templates require two API calls: create record -> upload file.

```bash
# Step 1: create the record
curl -X POST https://api.nexrender.com/api/v2/templates \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@template-create.json"
# returns { "id": "...", "uploadInfo": { "url": "..." } }
# or nested { "template": { "id": "..." }, "uploadInfo": { "url": "..." } }
# or legacy { "id": "...", "uploadUrl": "..." }

# Step 2: PUT the file to the presigned URL
curl -X PUT "<uploadInfo.url-or-uploadUrl>" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@template.zip"
```

The presigned PUT gets no Nexrender auth header. Do not blindly copy `uploadInfo.fields` into headers;
extra unsigned `x-amz-*` metadata can fail with `MalformedSecurityHeader`. The template moves
`awaiting_upload` -> `processing` -> `uploaded` (or `downloading` -> `processing` -> `uploaded` when
`src` is used); poll `GET /v3/templates/{id}` or legacy `GET /templates/{id}` until `uploaded` or
`error`.

### Inspecting a template before rendering
```bash
curl https://api.nexrender.com/api/v3/templates/01JTGM.../compositions
# -> [{ "aeid": "12", "name": "main", "width": 1920, "height": 1080, ... }]

curl https://api.nexrender.com/api/v3/templates/01JTGM.../layers
# -> [{ "composition_id": 12, "name": "title", "layer_type": "TextLayer", ... }]
```
Use composition `name` and layer `name` to validate your job payload before submitting. In jobs, the
layer field is still `layerName`; set it to the exact v3 layer `name` value. V3 layer introspection can
include `layer_type`, `source_type`, timing, and bounds metadata. Legacy `GET /templates/{id}` returns
simple `compositions` and `layers` name arrays.

---

## 2. Batch Jobs

Submit up to 1,000 jobs at once via `POST /batches`. Each job is a standard job payload.

```json
{
  "jobs": [
    {
      "template": { "id": "TMPL_ID", "composition": "main" },
      "assets": [{ "type": "text", "layerName": "name", "value": "Alice" }],
      "webhook": { "url": "https://yourdomain.com/hook" }
    },
    {
      "template": { "id": "TMPL_ID", "composition": "main" },
      "assets": [{ "type": "text", "layerName": "name", "value": "Bob" }],
      "webhook": { "url": "https://yourdomain.com/hook" }
    }
  ]
}
```

Batch supports partial success - some jobs can fail validation while others proceed. Check `status`:
- `"created"` - all succeeded
- `"partial"` - some failed (check `errors` array)
- `"error"` - all failed

Track aggregate progress with `GET /batches/{batchId}`.
Cancel all remaining jobs with `POST /batches/{batchId}/cancel`.

---

## 3. Nested Jobs (compositing)

A nested job renders a child template and automatically injects its output as a video/image layer
in the parent composition. Useful for: lower-thirds, branded intros, chart renders.

```json
{
  "template": { "id": "PARENT_TMPL", "composition": "main" },
  "assets": [
    {
      "type": "job",
      "layerName": "LowerThird",        // layer in the parent where child output is placed
      "template": { "id": "CHILD_TMPL", "composition": "lower-third" },
      "assets": [
        { "type": "text", "layerName": "name", "value": "Jane Smith" },
        { "type": "text", "layerName": "title", "value": "Lead Designer" }
      ]
    }
  ]
}
```

How it works:
1. Nexrender creates and renders the child job
2. Parent waits in `pending` state
3. Child `outputUrl` is injected into the parent's `layerName` layer
4. Parent renders and reaches `finished`

Multiple nested jobs are supported - they render in parallel, and the parent waits for all of them.

---

## 4. Join Jobs (stitching/concatenation)

Join jobs concatenate an ordered list of clips into a single output. Each clip is either a static
video URL or an inline job definition. Use `POST /jobs/join`.

```json
{
  "assets": [
    { "type": "video", "src": "https://cdn.example.com/intro.mp4" },
    {
      "type": "job",
      "template": { "id": "PERSONALIZED_TMPL", "composition": "main" },
      "assets": [
        { "type": "text", "layerName": "name", "value": "Sarah Chen" }
      ]
    },
    { "type": "video", "src": "https://cdn.example.com/outro.mp4" }
  ],
  "settings": { "preset": "mp4" },
  "webhook": { "url": "https://yourdomain.com/hook" }
}
```

Clips are stitched in array order. Job-type assets render first, then the stitch runs.

**Nested vs. Join:**
- Use **nested** when child output is composited as a layer inside a parent AE composition
- Use **join** when you want to concatenate clips end-to-end into a linear video

---

## 5. Secrets Management

Secrets are encrypted, team-scoped key-value pairs. Reference them with `${secrets.NAME}`.

```bash
# Create a secret
curl -X PUT https://api.nexrender.com/api/v2/secrets \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@secret-payload.json"

# Reference in a job payload
"accessKeyId": "${secrets.S3_KEY_ID}"
```

Secrets can be referenced in:
- `upload.params.accessKeyId` and `upload.params.accessKeySecret`
- Any asset `src` or `value` field
- `webhook.headers` values

Secrets are never returned in plaintext from the API - list endpoint only returns name and ID.

---

## 6. Fonts Management

Upload `.ttf` files once, then reference them by `fileName` in the job's `fonts` array.
Nexrender installs them on the render worker before After Effects starts.

```bash
# Upload a font
curl -X POST https://api.nexrender.com/api/v2/fonts \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -F "font=@/path/to/Montserrat-SemiBold.ttf"
# → { "id": "...", "fileName": "Montserrat-SemiBold.ttf", "familyName": "Montserrat" }

# Reference in a job
{
  "template": { "id": "TMPL_ID", "composition": "main" },
  "fonts": ["Montserrat-SemiBold.ttf", "Roboto-Bold.ttf"],
  "assets": []
}
```

If fonts listed in `fonts` aren't in your account, or After Effects reports a missing internal font,
the job creation response can flag them:
```json
{ "id": "...", "status": "queued", "missingFonts": ["Roboto-Bold.ttf", "Soleil (Regular)"] }
```
The job or preview may still finish with fallback fonts. Resolve missing fonts before trusting visual
output; the warning value can be an uploaded file name or an AE/internal family label.

---

## 7. Clean Room Setup

For zero data retention on Nexrender's side, combine:
- `template.src` - deliver template from your storage at render time (bypasses Nexrender storage)
- `upload` - push rendered output to your storage (no copy retained by Nexrender)

```json
{
  "template": {
    "id": "PLACEHOLDER",
    "src": "https://your-storage.example.com/templates/promo-v3.zip",
    "composition": "main"
  },
  "assets": [
    { "type": "text", "layerName": "title", "value": "Hello World" }
  ],
  "upload": {
    "provider": "s3",
    "prefix": "renders/",
    "params": {
      "region": "us-east-1",
      "bucket": "your-render-outputs",
      "accessKeyId": "${secrets.S3_KEY_ID}",
      "accessKeySecret": "${secrets.S3_KEY_SECRET}"
    }
  }
}
```

`template.src` requirements:
- Must be a publicly accessible or presigned `https://` URL
- Supported formats: `.aep`, `.zip`, `.mogrt`
- Max file size: 2 GiB
- URL must stay accessible for the duration of the render
- Template introspection (compositions/layers) is not available - reference names directly

---

## 8. Job Cancellation

Cancel a single job:
```bash
curl -X PATCH https://api.nexrender.com/api/v2/jobs/{id}/cancel \
  -H "Authorization: Bearer YOUR_API_KEY"
```

Cancel multiple jobs at once:
```bash
curl -X POST https://api.nexrender.com/api/v2/jobs/cancel \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary "@cancel-payload.json"
```

Cancellation cascades automatically:
- Cancelling a parent also cancels its pending/queued children
- Cancelling a child also cancels the parent (now unresolvable) and waiting siblings

Only `queued` and `pending` jobs can be cancelled. Jobs in `render:dorender`, `finished`, `error`,
or `manually_cancelled` are not affected.

---

## 9. Custom Upload Configurations (non-clean-room)

Even without using clean room, you can push every job's output to your own bucket by including
the `upload` object. This is useful for CDN integration, data residency, or organizing outputs
by campaign/customer.

Common provider configs:

```json
// Cloudflare R2
"upload": {
  "provider": "s3",
  "params": {
    "endpoint": "https://<ACCOUNT_ID>.r2.cloudflarestorage.com",
    "region": "auto",
    "bucket": "your-bucket",
    "accessKeyId": "${secrets.R2_ACCESS_KEY_ID}",
    "accessKeySecret": "${secrets.R2_ACCESS_KEY_SECRET}"
  }
}

// Google Cloud Storage (via interoperability)
"upload": {
  "provider": "s3",
  "params": {
    "endpoint": "https://storage.googleapis.com",
    "region": "auto",
    "bucket": "your-gcs-bucket",
    "accessKeyId": "${secrets.GCS_ACCESS_KEY_ID}",
    "accessKeySecret": "${secrets.GCS_ACCESS_KEY_SECRET}"
  }
}
```
