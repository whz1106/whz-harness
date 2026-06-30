# Publishing ModelScope Skills

Use this when packaging, creating, or updating a Skill on ModelScope.

## Package Shape

The OpenAPI description requires the uploaded zip package to:

- Be at most 5 MB
- Have exactly one `SKILL.md` at the zip root
- Include YAML frontmatter in `SKILL.md`
- Optionally include helper directories and files

This means the zip should contain:

```text
SKILL.md
agents/openai.yaml
scripts/...
references/...
```

It should not contain:

```text
skills/modelscope-api/SKILL.md
__pycache__/
.env
.git/
node_modules/
```

## Package And Validate

Run from the repository root:

```bash
python3 skills/modelscope-api/scripts/package_skill.py skills/modelscope-api --output /tmp/modelscope-api-skill.zip
```

Machine-readable output:

```bash
python3 skills/modelscope-api/scripts/package_skill.py skills/modelscope-api --output /tmp/modelscope-api-skill.zip --json
```

Validate an existing zip:

```bash
python3 skills/modelscope-api/scripts/package_skill.py --output /tmp/modelscope-api-skill.zip --validate-only
```

## Upload Flow

1. Check setup:

```bash
python3 skills/modelscope-api/scripts/check_setup.py
```

2. Package the skill:

```bash
python3 skills/modelscope-api/scripts/package_skill.py skills/modelscope-api --output /tmp/modelscope-api-skill.zip
```

3. Upload the zip and save the returned file id:

```bash
python3 skills/modelscope-api/scripts/modelscope_api.py POST /files/upload --file file=/tmp/modelscope-api-skill.zip
```

4. Create a new Skill with `POST /skills`, passing the uploaded `skill_file` id:

```bash
python3 skills/modelscope-api/scripts/modelscope_api.py POST /skills --data '{
  "skill_name": "modelscope-api",
  "owner": "YOUR_OWNER",
  "display_name": "ModelScope API",
  "description": "Use ModelScope OpenAPI and SDK/CLI tooling.",
  "license": "Apache-2.0",
  "category": "developer-tools",
  "tags": ["modelscope", "openapi", "sdk"],
  "skill_file": "FILE_ID_FROM_UPLOAD"
}' --dry-run
```

5. Remove `--dry-run` only after the owner, visibility/private field, source URL, license, category, and file id are correct.

## Update Flow

Use `PATCH /skills/{owner}/{skill_name}/settings`. Passing `skill_file` replaces the whole uploaded package. Passing `tags` replaces the whole tag list.

```bash
python3 skills/modelscope-api/scripts/modelscope_api.py PATCH /skills/YOUR_OWNER/modelscope-api/settings --data '{
  "skill_file": "NEW_FILE_ID_FROM_UPLOAD",
  "tags": ["modelscope", "openapi", "sdk"]
}' --dry-run
```

## Safety Checks

- Keep the zip under 5 MB.
- Confirm the zip root contains `SKILL.md`, not a nested project folder.
- Do not upload `.env`, caches, downloaded models, datasets, or generated archives.
- Use `--dry-run` before create/update calls.
- Record `request_id` from API responses when troubleshooting.
