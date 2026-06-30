# ModelScope Skill Setup

Use this when the user is installing the skill, checking whether it is ready, or troubleshooting authentication and downloads.

## Minimum Setup

For OpenAPI calls:

```bash
export MODELSCOPE_API_TOKEN="..."
```

For model or dataset downloads:

```bash
python3 -m pip install modelscope
```

Some public downloads may work without a token. Private, gated, account-specific, Studio, Skill publishing, file upload, and MCP deployment operations require authenticated access.

## Setup Check

Run:

```bash
python3 skills/modelscope-api/scripts/check_setup.py
python3 skills/modelscope-api/scripts/check_setup.py --json
```

The checker reports:

- Python version
- Token environment variable presence
- ModelScope CLI availability

Use `--run-help` when you need to verify the actual `modelscope download --help` command:

```bash
python3 skills/modelscope-api/scripts/check_setup.py --run-help
```

## Token Rules

- Prefer `MODELSCOPE_API_TOKEN`.
- Accept `MODELSCOPE_TOKEN` as a fallback for local compatibility.
- Never place a real token in committed files, command examples, logs, issue comments, or skill resources.
- Use `--dry-run` when showing authenticated request examples; `modelscope_api.py` redacts the authorization header.

## Common Failures

| Symptom | Likely Cause | Action |
| --- | --- | --- |
| `Missing ModelScope token` | No token env var | Set `MODELSCOPE_API_TOKEN` |
| `Missing ModelScope CLI` | SDK not installed | Run `python3 -m pip install modelscope` after user approval |
| 401 or unauthorized response | Missing/invalid token | Re-check token and account permissions |
| Download path unclear | No explicit output path | Use `--local-dir` for predictable output |
| Large unexpected download | Missing filters | Use `--include`, specific file paths, and `--dry-run` first |
