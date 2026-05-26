# Loveable Prompt: Blog Publishing Integration with VersionLab

## Context

Our main product app (VersionLab) has a blog system powered by the helios-press Rails engine. It exposes a JSON API for external content ingestion. Your app is the **publishing tool** — it creates blog post content (text + images) and pushes it to VersionLab's API.

When you push HTML containing `<img>` tags, VersionLab automatically downloads every image, stores it in S3 via ActiveStorage, and rewrites the `<img src>` attributes to point at its own hosted URLs. You do **not** need to upload images separately — just include them as normal `<img>` tags in the HTML body and the server handles the rest.

---

## API Endpoint

```
POST https://versionlab.io/api/press/posts
```

### Authentication

Every request must include an API key in the `X-API-Key` header:

```
X-API-Key: <your-api-key>
```

The key is provided via the `BLOG_INGEST_API_KEY` environment variable on VersionLab's side. You will need to store this key in your app's environment as well (e.g., `VERSIONLAB_BLOG_API_KEY`).

### Content-Type

```
Content-Type: application/json
```

---

## Request Payload

```json
{
  "external_id": "loveable-post-draft-4821",
  "title": "How to Build Better Email Templates",
  "slug": "how-to-build-better-email-templates",
  "description": "A guide to creating high-converting email templates with AI-powered versioning.",
  "keywords": "email templates, A/B testing, AI copywriting",
  "body_html": "<h2>Introduction</h2><p>Email marketing is evolving...</p><p><img src=\"https://your-storage.com/images/hero-shot.jpg\" alt=\"Email template example\"></p><p>Here's how to get started...</p>",
  "published": true,
  "images": [
    {
      "reference_key": "diagram-1",
      "url": "https://your-storage.com/images/workflow-diagram.png",
      "alt": "Workflow diagram showing the versioning process",
      "caption": "The VersionLab workflow"
    }
  ]
}
```

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `external_id` | string | **Yes** | Your unique identifier for this post. Used for upsert — sending the same `external_id` again updates the existing post instead of creating a duplicate. |
| `title` | string | Yes | The post title. Also used to auto-generate the slug if `slug` is omitted. |
| `slug` | string | No | URL-safe slug for the post (e.g., `my-post-title`). Auto-generated from `title` if omitted. Must be unique. |
| `description` | string | No | Meta description for SEO. |
| `keywords` | string | No | Comma-separated keywords for SEO. |
| `body_html` | string | Yes | The full HTML body of the post. Can contain `<img>`, `<h1>`–`<h6>`, `<p>`, `<ul>`, `<ol>`, `<blockquote>`, `<a>`, `<strong>`, `<em>`, etc. |
| `published` | boolean | No | Whether the post is publicly visible. Defaults to `false` (draft). |
| `images` | array | No | Optional array of image metadata for explicit image references (see below). |

### Image Handling

There are two ways images in `body_html` are processed:

#### 1. Auto-import (simplest — recommended for most cases)

Just include normal `<img src="https://...">` tags in your `body_html`. The server will:
- Download each image
- Store it in S3 via ActiveStorage
- Rewrite the `src` to a local proxy URL
- Deduplicate by URL path (so re-publishing the same post won't re-download unchanged images)

**This is all you need for most use cases.** No `images` array required.

#### 2. Explicit references (for fine-grained control)

If you want to attach metadata (alt text, captions) or control deduplication keys:

1. In `body_html`, use the placeholder protocol: `<img src="helios://image/diagram-1">`
2. In the `images` array, provide the actual download URL:

```json
{
  "images": [
    {
      "reference_key": "diagram-1",
      "url": "https://your-storage.com/images/workflow-diagram.png",
      "alt": "Workflow diagram",
      "caption": "Figure 1: The VersionLab workflow"
    }
  ]
}
```

The `reference_key` in the `images` array is matched to `helios://image/<reference_key>` in the HTML.

You can mix both approaches in the same post — explicit references for images you want to control, auto-import for the rest.

---

## Response

### Success (200 OK)

```json
{
  "ok": true,
  "id": 42,
  "slug": "how-to-build-better-email-templates"
}
```

### Validation Error (422 Unprocessable Entity)

```json
{
  "errors": ["Name can't be blank", "Slug has already been taken"]
}
```

### Missing external_id (400 Bad Request)

```json
{
  "error": "external_id is required"
}
```

### Unauthorized (401)

```json
{
  "error": "unauthorized"
}
```

---

## Upsert Behavior

The API uses **upsert by `external_id`**. This means:

- **First call** with a given `external_id`: creates a new post.
- **Subsequent calls** with the same `external_id`: updates the existing post (title, body, slug, published status, etc.).
- Images are also deduplicated on re-ingestion — already-downloaded images are not re-fetched.

This makes it safe to re-publish/update posts repeatedly.

---

## Implementation Guide for Your App

### Environment Variable

Store the API key:
```
VERSIONLAB_BLOG_API_KEY=your-secret-key-here
```

### Example Integration (TypeScript/fetch)

```typescript
interface BlogPostPayload {
  external_id: string;
  title: string;
  slug?: string;
  description?: string;
  keywords?: string;
  body_html: string;
  published: boolean;
  images?: Array<{
    reference_key: string;
    url: string;
    alt?: string;
    caption?: string;
  }>;
}

async function publishToVersionLab(post: BlogPostPayload) {
  const response = await fetch("https://versionlab.io/api/press/posts", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-API-Key": process.env.VERSIONLAB_BLOG_API_KEY!,
    },
    body: JSON.stringify(post),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(`Publish failed: ${JSON.stringify(error)}`);
  }

  return response.json(); // { ok: true, id: number, slug: string }
}
```

### Key Points

1. **Generate a stable `external_id`** for each post in your system (e.g., your internal post ID or a UUID). This is what enables safe re-publishing.
2. **Include images as normal `<img>` tags** in `body_html` — the server handles downloading and re-hosting automatically.
3. **Set `published: false`** for drafts, `true` when ready to go live.
4. **Slugs must be unique** — if you omit the `slug` field, one is auto-generated from the title. If you provide one, make sure it won't collide with existing posts.
5. **Image size limit** is 15MB per image. Images that fail to download are skipped silently (the original `src` URL is preserved).
