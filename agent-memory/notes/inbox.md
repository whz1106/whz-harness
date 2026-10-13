# 捕获区（inbox）

追加式。`bash ~/whz-harness/scripts/capture.sh "事实" [--tag <机器/项目>]` 往这里追加；整理后把稳定结论提升到 `personal.md` / `projects/<项目>.md` / `machines/<机器>.md`，并删掉这里已整理的条目。

格式：`- <UTC 时间> [<主机>] <事实>`

## 待整理

（新条目追加在这里下面）

- 2026-10-13T12:00:00Z [win-main] WSL k3s 开发集群：本地推理已下线，改走内网 GLM 网关（`172.18.5.***:3000`，模型 `GLM-5.3-Flash`）；API key 存在集群 env 与 wasmplugin 里，不落任何文件。本机只保留嵌入服务（`llama-embed`，512 维）。
- 2026-10-13T12:00:00Z [win-main] 搭档（pi-companion）与数字员工链路统一经 higress 调 `bench-glm`（wasmplugin `aep-ai-proxy-glm` 把 `bench-glm` 映射到 `GLM-5.3-Flash` 并注入 token）。搭档的模型 **id 必须保持 `bench-glm`**：历史会话的 assistant 条目里记录了 `companion/bench-glm`，改 id 后提交会以 `no_model` 直接失败。
- 2026-10-13T12:00:00Z [win-main] `deerflow-gov` 镜像：注册表 push 无凭据（`unauthorized to upload`），离线流程改为 `docker save | sudo k3s ctr images import -` + `docker.io/zhiyuan-local/*` 标签。DigitalEmployee CR 的 `runtime.image` 必须指向含 `knowledge_bases` 支持的治理包 —— 旧的 `v3` 会在 `AepGovernanceMiddleware.__init__` 触发 `TypeError: object.__init__()`，整轮 run 直接失败。
- 2026-10-13T12:00:00Z [win-main] 本集群的 admin 控制台是 `de-admin-console`（NodePort 30196），镜像 `docker.io/zhiyuan-local/admin-console:*`；`deploy/Dockerfile.admin` 的 `FROM node:22-alpine` 在 docker 代理（`127.0.0.1:7897`）不可用时拉不下来，可用本机已有 `node:24-alpine` 打 `node:22-alpine` 标签后离线构建。
- 2026-10-13T12:00:00Z [win-main] portal 的 `POST /api/v1/employees/<id>/chat/threads` 需要带 `Origin`/`Referer`（否则 403，看着像鉴权坏了，其实只是 CSRF 来源校验）。

## 已整理（保留近期几条作为脉络，其余删掉）

- 2026-09-24T00:00:00Z [win-main] 记忆体系统一为一个公开仓库 `whz-harness`，四层注入：`personal-memory`（根）、`agent-memory`（记忆系统）、`machines-memory`（环境与硬约束）、`local-memory`（本地投放区，gitignore）。原来的独立仓库 `agent-memory` / `work-memory` 均已废弃。
- 2026-09-24T00:00:00Z [win-main] 环境信息（`machines/`）单独成层：更新频率最高，且含 kata/vfio 这类「必须经同意才能动」的硬约束，所以既要注入又要保持短，细节放 `machines/<机器>.md` 与 `machines/RULES.md`。
- 2026-09-24T00:00:00Z [win-main] 外部资料进 `materials/`（部署包文本 20 文件 236 KB 已入库到 `materials/agc64f-llm-deploy/`）；受控 PDF、zip、36 GiB 数据只留指针，登记在 `materials/INDEX.md`。
- 2026-09-24T00:00:00Z [win-main] 全仓库扫描确认：无非 loopback IP、无凭据；完整 IP 一律不写，只写网段。
- 2026-09-24T00:00:00Z [win-main] 教训：批量文本替换不要叠 `sed`，行尾反斜杠（shell 续行符）会被误伤成 `$`（曾损坏 12 个文件 297 行）。改完必须与原文件 diff。
