# ModelScope SDK And CLI Downloads

Use this reference when the user wants to download model weights, model repository files, or dataset resources from ModelScope.

Context7 source: `/modelscope/modelscope`, query on ModelScope Python SDK downloads. The documented official CLI command is `modelscope download`.

## Role Split

- Use OpenAPI for listing, metadata, publishing, Studio operations, MCP operations, file upload, and account queries.
- Use ModelScope SDK/CLI for resource downloads.
- Use Git LFS only as an advanced fallback when the user explicitly wants Git repository semantics such as clone, branches, commits, or manual LFS control.

## Install

```bash
python3 -m pip install modelscope
```

Do not install dependencies automatically unless the user approves network/package installation.

## CLI Download

Official command shape:

```bash
modelscope download --model MODEL [--revision REVISION] [--cache_dir CACHE_DIR] [--local_dir LOCAL_DIR] [--include INCLUDE ...] [--exclude EXCLUDE ...] [files ...]
modelscope download --dataset DATASET [--revision REVISION] [--cache_dir CACHE_DIR] [--local_dir LOCAL_DIR] [--include INCLUDE ...] [--exclude EXCLUDE ...] [files ...]
```

Important options:

- `--model`: model id to download, for example `qwen/Qwen3-8B`
- `--dataset`: dataset id to download
- `--revision`: model or dataset revision
- `--cache_dir`: cache directory
- `--local_dir`: explicit local download directory; this ignores `cache_dir`
- `--include`: glob patterns to include
- `--exclude`: glob patterns to exclude
- `files`: optional relative file paths such as `tokenizer.json` or `onnx/decoder_model.onnx`

## Skill Helper

Use the bundled wrapper for safer dry-runs:

```bash
python3 skills/modelscope-api/scripts/modelscope_download.py model qwen/Qwen3-8B --local-dir ./Qwen3-8B --dry-run
python3 skills/modelscope-api/scripts/modelscope_download.py model qwen/Qwen3-8B tokenizer.json config.json --dry-run
python3 skills/modelscope-api/scripts/modelscope_download.py dataset modelscope/test-dataset --cache-dir ./ms-cache --dry-run
```

Remove `--dry-run` only after checking the command, destination path, and expected resource size.

Before a large download:

1. Query metadata with `GET /models/{owner}/{repo_name}` or `GET /datasets/{owner}/{repo_name}`.
2. Check `file_size`, privacy/gated flags, and license fields when present.
3. Prefer specific file paths or `--include` for tokenizer/config-only tasks.
4. Use `--local-dir` when the user needs a predictable output path.
5. Ask for explicit confirmation before downloading very large resources.

## Python SDK Pattern

For model snapshots, Context7 examples show:

```python
from modelscope import snapshot_download

model_dir = snapshot_download("qwen/Qwen1.5-4B-Chat")
print(model_dir)
```

Use Python SDK snippets when writing project code. Use the CLI helper when Codex is downloading resources during an interactive task.

## Safety Rules

- Check model or dataset metadata first when size matters.
- Prefer `--include` for targeted files such as tokenizer/config files.
- Prefer `--local-dir` when the user needs a predictable output path.
- Do not download very large resources without explicit user confirmation.
- Do not commit downloaded model weights, datasets, caches, or `.modelscope` directories.
