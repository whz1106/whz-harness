# ModelScope OpenAPI Summary

Source: `openapi.json`

- OpenAPI version: 3.1.1
- API version: 1.1.0
- Base URL: `https://modelscope.cn/openapi/v1`
- Auth: bearer token via `Authorization: Bearer <token>`
- Preferred token env var: `MODELSCOPE_API_TOKEN`
- Fallback token env var: `MODELSCOPE_TOKEN`
- Resource downloads: use `references/sdk-downloads.md` and the official ModelScope SDK/CLI; this OpenAPI document does not expose model or dataset file download endpoints.

## Endpoint Index

`*` marks required path parameters.

| Tag | Method | Path | Operation | Summary | Parameters | Body |
| --- | --- | --- | --- | --- | --- | --- |
| User | GET | `/users/me` | `getCurrentUser` | 获取当前用户信息 | - | - |
| Models | GET | `/models` | `listModels` | 获取模型列表 | `search`, `owner`, `sort`, `page_number`, `page_size`, `filter.task`, `filter.library`, `filter.model_type`, `filter.custom_tag`, `filter.license`, `filter.deploy` | - |
| Models | GET | `/models/{owner}/{repo_name}` | `getModel` | 获取模型详情 | `owner*`, `repo_name*` | - |
| Datasets | GET | `/datasets` | `listDatasets` | 获取数据集列表 | `search`, `owner`, `sort`, `page_number`, `page_size`, `filter.task`, `filter.license` | - |
| Datasets | GET | `/datasets/{owner}/{repo_name}` | `getDataset` | 获取数据集详情 | `owner*`, `repo_name*` | - |
| MCP | PUT | `/mcp/servers` | `listMcpServers` | 获取 MCP 服务列表 | - | `application/json` |
| MCP | GET | `/mcp/servers/operational` | `listOperationalMcpServers` | 获取用户托管 MCP 服务列表 | - | - |
| MCP | GET | `/mcp/servers/{id}` | `getMcpServer` | 获取指定 MCP 服务详情 | `id*`, `get_operational_url` | - |
| MCP | POST | `/mcp/servers/{id}/deploy` | `deployMcpServer` | 部署 MCP 服务 | `id*` | `application/json` |
| MCP | DELETE | `/mcp/servers/{id}/undeploy` | `undeployMcpServer` | 解除 MCP 服务部署 | `id*` | - |
| Studios | POST | `/studios` | `createStudio` | 创建创空间 | - | `CreateStudioRequest` |
| Studios | GET | `/studios/hardware` | `listHardware` | 查询可用硬件配置 | `sdk_type`, `studio` | - |
| Studios | GET | `/studios/sdk-versions` | `listSdkVersions` | 查询可用 SDK 版本 | `sdk_type` | - |
| Studios | GET | `/studios/base-images` | `listBaseImages` | 查询可用基础镜像 | - | - |
| Studios | GET | `/studios/{owner}/{repo_name}` | `getStudio` | 获取创空间详情 | `owner*`, `repo_name*` | - |
| Studios | PATCH | `/studios/{owner}/{repo_name}/settings` | `updateStudioSettings` | 更新创空间设置 | `owner*`, `repo_name*` | `UpdateStudioSettingsRequest` |
| Studios | GET | `/studios/{owner}/{repo_name}/secrets` | `listStudioSecrets` | 获取创空间密文变量列表 | `owner*`, `repo_name*` | - |
| Studios | POST | `/studios/{owner}/{repo_name}/secrets` | `addStudioSecret` | 添加创空间密文变量 | `owner*`, `repo_name*` | `AddStudioSecretRequest` |
| Studios | PUT | `/studios/{owner}/{repo_name}/secrets` | `updateStudioSecret` | 更新创空间密文变量 | `owner*`, `repo_name*` | `UpdateStudioSecretRequest` |
| Studios | DELETE | `/studios/{owner}/{repo_name}/secrets` | `deleteStudioSecret` | 删除创空间密文变量 | `owner*`, `repo_name*` | `DeleteStudioSecretRequest` |
| Studios | GET | `/studios/{owner}/{repo_name}/variables` | `listStudioVariables` | 获取创空间明文变量列表 | `owner*`, `repo_name*` | - |
| Studios | POST | `/studios/{owner}/{repo_name}/variables` | `addStudioVariable` | 添加创空间明文变量 | `owner*`, `repo_name*` | `AddStudioVariableRequest` |
| Studios | PUT | `/studios/{owner}/{repo_name}/variables` | `updateStudioVariable` | 更新创空间明文变量 | `owner*`, `repo_name*` | `UpdateStudioVariableRequest` |
| Studios | DELETE | `/studios/{owner}/{repo_name}/variables` | `deleteStudioVariable` | 删除创空间明文变量 | `owner*`, `repo_name*` | `DeleteStudioVariableRequest` |
| Studios | POST | `/studios/{owner}/{repo_name}/deploy` | `deployStudio` | 部署创空间 | `owner*`, `repo_name*` | - |
| Studios | POST | `/studios/{owner}/{repo_name}/stop` | `stopStudio` | 停止创空间 | `owner*`, `repo_name*` | - |
| Studios | GET | `/studios/{owner}/{repo_name}/logs/{log_type}` | `getStudioLogs` | 获取创空间日志 | `owner*`, `repo_name*`, `log_type*`, `page_num`, `page_size`, `keyword`, `start_timestamp`, `end_timestamp` | - |
| Skills | GET | `/skills` | `listSkills` | 获取技能列表 | `search`, `filter.developer`, `filter.category`, `filter.license`, `filter.custom_tag`, `filter.owner`, `page_number`, `page_size` | - |
| Skills | POST | `/skills` | `createSkill` | 创建技能 | - | `CreateSkillRequest` |
| Skills | GET | `/skills/{id}` | `getSkill` | 获取指定技能详情 | `id*` | - |
| Skills | PATCH | `/skills/{owner}/{skill_name}/settings` | `updateSkillSettings` | 更新技能设置 | `owner*`, `skill_name*` | `UpdateSkillSettingsRequest` |
| Files | POST | `/files/upload` | `uploadFile` | 上传文件 | - | `UploadFileRequest` |

## Request Schemas

### CreateStudioRequest

Required: `repo_name`, `owner`

- `repo_name`: string, repository name
- `owner`: string, username or organization
- `display_name`: string
- `license`: string, defaults to apache-2.0
- `visibility`: `public`, `protected`, or `private`
- `private`: boolean, deprecated; prefer `visibility`
- `description`: string
- `cover_image`: string URL
- `sdk_type`: `gradio`, `streamlit`, `docker`, or `static`
- `sdk_version`: string; query `GET /studios/sdk-versions?sdk_type=gradio`
- `base_image`: string; query `GET /studios/base-images`
- `hardware`: string; query `GET /studios/hardware`

### UpdateStudioSettingsRequest

All fields are optional and partial updates are supported: `display_name`, `license`, `visibility`, `private`, `description`, `cover_image`, `sdk_type`, `sdk_version`, `base_image`, `hardware`.

### Studio Secrets

- `AddStudioSecretRequest`: required `key`, `value`
- `UpdateStudioSecretRequest`: required `key`, `value`
- `DeleteStudioSecretRequest`: required `key`
- Secret values are not returned by list responses.

### Studio Variables

- `AddStudioVariableRequest`: required `key`, `value`
- `UpdateStudioVariableRequest`: required `key`, `value`
- `DeleteStudioVariableRequest`: required `key`
- Variables are plaintext. Do not store secrets here.

### CreateSkillRequest

Required: `skill_name`, `owner`, `license`, `category`, `skill_file`

- `skill_name`: lowercase letters, digits, and hyphens only
- `owner`: username or organization
- `display_name`: display name
- `source_url`: source repository URL
- `private`: boolean, defaults to false
- `description`: description
- `license`: license, defaults to Apache-2.0 when omitted
- `category`: one of `skill-management`, `developer-tools`, `marketing-seo`, `frontend-development`, `ai-media`, `code-quality-testing`, `mobile-development`, `cloud-devops`, `other`
- `tags`: array of strings
- `logo_url`: icon URL
- `skill_file`: file ID returned by `POST /files/upload`

Skill zip constraints from the OpenAPI description:

- Maximum 5 MB
- Zip root must contain exactly one `SKILL.md`
- May contain subdirectories and helper files
- `SKILL.md` must contain YAML frontmatter with `name`, `version`, and `description`

### UpdateSkillSettingsRequest

Partial update fields: `display_name`, `source_url`, `private`, `description`, `license`, `category`, `tags`, `logo_url`, `skill_file`.

Passing `tags` replaces the whole tag list. Passing an empty `logo_url` restores the platform default icon.

### UploadFileRequest

Use multipart form data with required field `file`. Maximum file size is 5 MB according to the skill upload schema notes.

## CLI Patterns

```bash
python3 skills/modelscope-api/scripts/modelscope_api.py GET /users/me
python3 skills/modelscope-api/scripts/modelscope_api.py GET /models --query search=Qwen --query page_size=10
python3 skills/modelscope-api/scripts/modelscope_api.py PATCH /studios/me/demo/settings --data '{"visibility":"private"}' --dry-run
python3 skills/modelscope-api/scripts/modelscope_api.py POST /files/upload --file file=./skill.zip
```

For model or dataset downloads, use:

```bash
python3 skills/modelscope-api/scripts/modelscope_download.py model qwen/Qwen3-8B --local-dir ./Qwen3-8B --dry-run
python3 skills/modelscope-api/scripts/modelscope_download.py dataset modelscope/test-dataset --cache-dir ./ms-cache --dry-run
```
