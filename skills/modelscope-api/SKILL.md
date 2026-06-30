---
name: modelscope-api
description: Use when Codex needs to work with Alibaba ModelScope models, datasets, Skills, MCP services, Studios, OpenAPI endpoints, SDK/CLI resource downloads, file uploads, or authenticated ModelScope account operations.
---

# ModelScope API

## Overview

Use ModelScope OpenAPI for platform queries and management, and use the official ModelScope SDK/CLI for downloading model or dataset resources. Keep credentials outside the skill and outside committed files; each user should configure their own token in the environment.

The official OpenAPI source is bundled at `references/openapi.json`. Start with `references/api-summary.md` for endpoint selection, then inspect `openapi.json` only when exact schema details are required.

For downloads, start with `references/sdk-downloads.md`. Context7 documentation for `/modelscope/modelscope` confirms that the official CLI supports `modelscope download` with `--model`, `--dataset`, `--revision`, `--cache_dir`, `--local_dir`, `--include`, `--exclude`, and optional file paths.

## Token Setup

Require one of these environment variables before authenticated calls:

```bash
export MODELSCOPE_API_TOKEN="..."
```

`MODELSCOPE_TOKEN` is accepted as a fallback for local compatibility. Never write tokens into `SKILL.md`, scripts, examples, shell history snippets, logs, or files committed with the skill.

## Quick Start

Check the local environment first:

```bash
python3 skills/modelscope-api/scripts/check_setup.py
```

Use the OpenAPI helper for platform API calls:

```bash
python3 skills/modelscope-api/scripts/modelscope_api.py GET /users/me
python3 skills/modelscope-api/scripts/modelscope_api.py GET /models --query search=Qwen --query page_size=5
python3 skills/modelscope-api/scripts/modelscope_api.py GET /models/qwen/Qwen3-8B
```

Use the SDK/CLI download helper for resources:

```bash
python3 skills/modelscope-api/scripts/modelscope_download.py model qwen/Qwen3-8B --local-dir ./Qwen3-8B --dry-run
python3 skills/modelscope-api/scripts/modelscope_download.py dataset modelscope/test-dataset --cache-dir ./ms-cache --dry-run
```

Use `--dry-run` before mutating calls or when showing examples. It redacts the authorization header:

```bash
python3 skills/modelscope-api/scripts/modelscope_api.py POST /studios --data '{"owner":"my-user","repo_name":"demo"}' --dry-run
```

For file uploads:

```bash
python3 skills/modelscope-api/scripts/modelscope_api.py POST /files/upload --file file=/path/to/archive.zip
```

## Workflow

1. Decide whether the task is metadata/management or resource download.
2. For metadata and management, read `references/api-summary.md`; use `scripts/modelscope_api.py`.
3. For model or dataset downloads, read `references/sdk-downloads.md`; use `scripts/modelscope_download.py` or the official `modelscope download` CLI directly.
4. For setup issues, read `references/setup.md`; use `scripts/check_setup.py`.
5. For skill publishing, read `references/publishing-skills.md`; use `scripts/package_skill.py`.
6. For schema precision, search `references/openapi.json` for `operationId`, path, or schema name.
7. Confirm a token is available in `MODELSCOPE_API_TOKEN` when the operation needs authenticated access; if not, ask the user to configure it.
8. Use `--dry-run` for POST, PUT, PATCH, DELETE, deployments, uploads, secret changes, skill publishing, and large downloads before sending the request.
9. Summarize returned JSON in user language; include `request_id` when present.

## Common Tasks

### Search Models Or Datasets

Use `GET /models` or `GET /datasets` with `search`, `owner`, pagination, and `filter.*` query parameters.

```bash
python3 skills/modelscope-api/scripts/modelscope_api.py GET /models --query search=Qwen --query sort=downloads --query page_size=10
python3 skills/modelscope-api/scripts/modelscope_api.py GET /datasets --query search=中文语料库 --query page_size=5
```

### Download Models Or Datasets

Use the official SDK/CLI, not OpenAPI. The OpenAPI bundled here does not expose model or dataset file download endpoints.

```bash
python3 skills/modelscope-api/scripts/modelscope_download.py model qwen/Qwen3-8B --local-dir ./Qwen3-8B --dry-run
python3 skills/modelscope-api/scripts/modelscope_download.py dataset modelscope/test-dataset --cache-dir ./ms-cache --dry-run
```

Remove `--dry-run` only after checking expected size, output path, include/exclude filters, and user intent.

### Check Setup

Run the setup check before first use or when authentication/downloads fail:

```bash
python3 skills/modelscope-api/scripts/check_setup.py --json
```

Read `references/setup.md` to interpret missing token or missing CLI results.

### Manage Studios

Use the hardware, SDK version, and base image endpoints before creating or updating a Studio. Changes to hardware, SDK, base image, or runtime config may require redeployment.

Use secret endpoints for sensitive values and variable endpoints only for non-sensitive values. Studio variables return plaintext values.

### Publish Or Update ModelScope Skills

Use `POST /files/upload` to upload a zip file first, then use the returned file ID as `skill_file` in `POST /skills` or `PATCH /skills/{owner}/{skill_name}/settings`.

The OpenAPI states the zip package must be at most 5 MB and its root must contain exactly one `SKILL.md`.

Package and validate this skill shape with:

```bash
python3 skills/modelscope-api/scripts/package_skill.py skills/modelscope-api --output /tmp/modelscope-api-skill.zip
```

Read `references/publishing-skills.md` before publishing or updating a Skill on ModelScope.

## References

- `references/api-summary.md`: compact endpoint and schema guide.
- `references/sdk-downloads.md`: ModelScope SDK/CLI download guide.
- `references/setup.md`: local environment and token setup guide.
- `references/publishing-skills.md`: packaging, uploading, creating, and updating ModelScope Skills.
- `references/openapi.json`: complete OpenAPI 3.1.1 source from ModelScope.
- `scripts/modelscope_api.py`: dependency-free CLI for authenticated requests.
- `scripts/modelscope_download.py`: wrapper around the official `modelscope download` CLI.
- `scripts/check_setup.py`: setup checker for token, Python, and ModelScope CLI.
- `scripts/package_skill.py`: package validator for ModelScope Skill zip uploads.
