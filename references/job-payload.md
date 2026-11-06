# Nexrender Job Payload Reference

## Full payload structure

```json
{
  "template": {
    "id": "01JTGM9GCR71JV7EJYDF45QAFD",   // required
    "composition": "main",                  // required (optional for .mogrt)
    "src": "https://..."                    // optional: bypass Nexrender storage (clean room)
  },
  "assets": [],                             // array of asset objects - see below
  "preview": false,                         // true = fast low-res preview (disables settings)
  "fonts": ["Montserrat-SemiBold.ttf"],     // font fileNames to install before rendering
  "settings": { },                          // output settings - see below (mutually exclusive with preview)
  "upload": { },                            // push output to your own storage - see below
  "webhook": { }                            // callback when job completes - see below
}
```

---

## Asset types

Every asset object has:
- `type`: one of `text`, `data`, `image`, `audio`, `video`, `static`, `essential`, `script`, `function`, `job`
- `layerName`: exact After Effects layer name (case-sensitive, required for most types)
- `composition`: optional - targets a layer in a different comp than `template.composition`

### `type: "text"` - simple text shorthand
Replaces the Source Text on a text layer. Shorthand for data + Source Text.

Use `GET /v3/templates/{id}/layers` when you need layer metadata before targeting a text layer. The v3
layer response uses `name` for the After Effects layer name and can include `layer_type`; in the job
payload, set `layerName` to that exact `name` value. Legacy `GET /templates/{id}` only returns simple
composition/layer name arrays.

```json
{
  "type": "text",
  "layerName": "title",
  "value": "Hello World"
}
```

### `type: "data"` - property override
Set any AE layer property by name. More flexible than `text`.

```json
{
  "type": "data",
  "layerName": "title",
  "property": "Source Text",
  "value": "Hello World"
}
```

For color (RGB 0-1 range):
```json
{
  "type": "data",
  "layerName": "BackgroundSolid",
  "property": "Color",
  "value": [0.1, 0.4, 0.9]
}
```

Cross-composition targeting:
```json
{
  "type": "data",
  "layerName": "subtitle",
  "composition": "supporting-comp",
  "property": "Source Text",
  "value": "Different comp"
}
```

### `type: "image"` - replace image layer source
```json
{
  "type": "image",
  "layerName": "logo",
  "src": "https://cdn.example.com/logo.png"
}
```

### `type: "video"` - replace video layer source
```json
{
  "type": "video",
  "layerName": "promo-clip",
  "src": "https://cdn.example.com/clip.mp4"
}
```

### `type: "audio"` - replace audio layer source
```json
{
  "type": "audio",
  "layerName": "voiceover",
  "src": "https://cdn.example.com/narration.mp3"
}
```

### `type: "static"` - inject a file that isn't linked to a specific layer
Used when the project references a file by path (e.g. a texture, data file, or custom script).
```json
{
  "type": "static",
  "src": "https://cdn.example.com/data.json",
  "name": "data.json"
}
```

### `type: "essential"` - .mogrt Essential Graphics property
Target properties exposed in the Essential Graphics panel.
```json
{
  "type": "essential",
  "layerName": "Title Text",
  "value": "Summer Sale"
}
```

### `type: "script"` - run an ExtendScript (.jsx) file
Executes a custom ExtendScript against the project before rendering.
```json
{
  "type": "script",
  "src": "https://cdn.example.com/custom-script.jsx"
}
```

### `type: "function"` - run a built-in Nexrender function
Calls a Nexrender built-in helper. Available functions:

| Function | Purpose | `params` (required in bold) |
|----------|---------|-----------------------------|
| `nx:text-params-set` | Set text content, font, size, colors, stroke, tracking, justification, position, and transform expressions | **`layerName`**, `textValue`, `textExpression`, `font` (PostScript name), `fontSize`, `fillColor`, `strokeColor`, `strokeWidth`, `strokeOverFill`, `applyStroke`, `applyFill`, `justification` (`left`/`center`/`right`), `tracking`, `positionValue` (`[x, y]`), `positionExpression`, `scaleExpression`, `opacityExpression` |
| `nx:solid-color-set` | Change a solid layer's color | **`layerName`**, **`color`** (hex string or 3-number RGB array), `composition` |
| `nx:layer-state-set` | Turn a layer on or off | **`layerName`**, **`visible`** (boolean) |
| `nx:layer-remove` | Remove a layer by its index | **`composition`**, **`layerIndex`** (1 = top layer) |
| `nx:layer-autoscale` | Scale a layer to fill or fit its composition | **`layerName`**, `composition`, `type` (`fill`/`fit`, default `fill`) |
| `nx:layer-start-set` | Set a layer's start time | **`layerName`**, **`value`** (seconds) |
| `nx:layer-duration-set` | Set a layer's duration | **`layerName`**, **`value`** (seconds) |
| `nx:comp-duration-set` | Set a composition's work area to start at 0 and last `value` seconds | **`composition`**, **`value`** (seconds) |
| `nx:genai` | Generate a video, image, or audio file with an AI provider and place it in a footage layer | **`provider`** (`fal`), **`key`**, **`model`**, **`type`** (`video`/`image`/`audio`), **`layerName`**, **`data`** (object passed to the model) |

Rules the API enforces:
- Function names use a colon: `nx:layer-state-set`, not `nx-layer-state-set`.
- Every option, including `layerName`, goes inside `params`. Top-level fields such as `layerName` or `src` on a function asset are rejected.
- Unknown params, missing required params, and wrong types are rejected with a 400 error.
- `layerName` may be an array of names for every function above except `nx:layer-remove`, `nx:comp-duration-set`, and `nx:genai`.
- Functions without a `composition` param change matching layers in every composition.
- `nx:text-params-set` skips values of `0`, `false`, or `""`, so `applyFill: false` does not turn the fill off.

Example - hide a layer:
```json
{
  "type": "function",
  "name": "nx:layer-state-set",
  "params": { "layerName": "CtaButton", "visible": false }
}
```

Example - set text style:
```json
{
  "type": "function",
  "name": "nx:text-params-set",
  "params": {
    "layerName": "headline",
    "fontSize": 72,
    "fillColor": [1, 0.5, 0],
    "tracking": 50
  }
}
```

Example - AI image generation:
```json
{
  "type": "function",
  "name": "nx:genai",
  "params": {
    "provider": "fal",
    "key": "${secrets.FAL_KEY}",
    "model": "fal-ai/flux/schnell",
    "type": "image",
    "layerName": "hero-image",
    "data": { "prompt": "A serene mountain lake at sunset" }
  }
}
```

`nx:genai` runs as a separate child job before the render. The create response has status `pending` and a `children` entry with `"function": "nx:genai"`. The generation job is not retried; if it fails, the render job fails. Nexrender does not measure a generated video. To control its length, ask the model for a length in `data`, then set the same length with `nx:layer-duration-set` and/or `nx:comp-duration-set` (`value` in seconds).

### `type: "job"` - nested child job
Renders a child composition first, injects the output as a layer in the parent. See `workflows.md`.

---

## settings object

Mutually exclusive with `preview: true`.

```json
{
  "settings": {
    "type": "video",              // "video" | "image" | "aep"
    "quality": "full",            // "full" | "draft"
    "codec": "video_h264_vbr_15mbps",
    "frames": 125,                // integer or [start, end] - required when type is "image"
    "engine": "ae2026"            // "ae2025" | "ae2026"
  }
}
```

### All codec identifiers

**Video:**
```
video_h264_vbr_1mbps   video_h264_cbr_1mbps
video_h264_vbr_5mbps   video_h264_cbr_5mbps
video_h264_vbr_15mbps  video_h264_cbr_15mbps
video_h264_vbr_40mbps  video_h264_cbr_40mbps
video_prores_422
video_prores_4444       (with alpha channel)
video_vp8               (WebM, 1 Mbps)
video_vp9               (WebM, 1 Mbps)
video_vp8_alpha         (WebM with alpha channel)
video_vp9_alpha         (WebM with alpha channel)
```

**Image** (requires `type: "image"`):
```
image_png    (lossless, supports transparency)
image_jpeg   (lossy, smaller files)
image_gif    (animated GIF from a frame range, 480 px wide, 12 fps)
```

After Effects can't write WebM or GIF, so these render to a source format first (H.264, ProRes 4444
for the `_alpha` codecs, PNG frames for GIF) and the render node converts the result with ffmpeg.
The output URL ends in `.webm` or `.gif`. A GIF needs `frames` as a range, e.g. `[0, 90]`, and
uploads one `.gif` file rather than a ZIP of frames.

Nested jobs (`type: "job"` assets) can't use `image_gif` (an image child must be one PNG or JPEG
frame) or the `_alpha` WebM codecs (the parent converts WebM to H.264, which drops alpha; use
`video_prores_4444`).

---

## upload object

Push rendered output to your own S3-compatible bucket instead of Nexrender's storage.

```json
{
  "upload": {
    "provider": "s3",
    "prefix": "renders/campaign-42/",
    "outputUrl": "https://cdn.yourcompany.com/media",
    "params": {
      "endpoint": "https://s3.amazonaws.com",  // defaults to AWS; set for R2, GCS, MinIO, etc.
      "region": "us-east-1",
      "bucket": "your-render-outputs",
      "acl": "public-read",                     // optional
      "accessKeyId": "${secrets.S3_KEY_ID}",
      "accessKeySecret": "${secrets.S3_KEY_SECRET}"
    }
  }
}
```

`outputUrl` is the base URL used to construct the link returned in the job response. Nexrender appends prefix + filename:
```
"https://cdn.yourcompany.com/media" + "renders/campaign-42/" + "job-id.mp4"
→ "https://cdn.yourcompany.com/media/renders/campaign-42/job-id.mp4"
```

Provider-specific endpoints:
- AWS S3: omit `endpoint` (defaults to `https://s3.amazonaws.com`)
- Cloudflare R2: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`
- Google Cloud Storage: `https://storage.googleapis.com`

**Always** use `${secrets.NAME}` for credentials. Never embed raw keys.

---

## webhook object

```json
{
  "webhook": {
    "url": "https://yourdomain.com/webhooks/render-complete",
    "method": "POST",              // default
    "headers": { "X-Secret": "abc" },
    "data": { "customField": "val" },
    "custom": false                // if true, sends only "data" (no system metadata)
  }
}
```

Nexrender POSTs the full job object to `url` when the job reaches a terminal state (`finished`, `error`, `manually_cancelled`). Your endpoint must return `2xx`. Retries up to 3 times with exponential backoff.

Webhook payload examples:
```json
// finished
{ "id": "...", "status": "finished", "outputUrl": "...", "stats": { "renderDuration": 22.3 } }

// error
{ "id": "...", "status": "error", "stats": { "error": "Layer 'title' not found..." } }
```
