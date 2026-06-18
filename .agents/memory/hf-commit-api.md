---
name: HuggingFace Commit API
description: How to commit files to a HuggingFace Space via REST API.
---

## Working format (verified)
```
POST https://huggingface.co/api/spaces/{owner}/{repo}/commit/{branch}
Authorization: Bearer {token}
Content-Type: application/json

{"summary": "...", "files": [{"path": "app.py", "content": "<raw utf-8 text>"}]}
```

**Key rules:**
- `content` = raw UTF-8 text (NOT base64). HF stores base64 as-is (as text) if you send it.
- `files` key (NOT `operations`). `operations/upsertFile` silently succeeds but adds no files.
- README `colorTo` must be: red/yellow/green/blue/indigo/purple/pink/gray (not "orange").

**Why:** Discovered through trial and error — `operations/upsertFile` with base64 silently succeeds but stores garbage; `files` with raw text works correctly.
