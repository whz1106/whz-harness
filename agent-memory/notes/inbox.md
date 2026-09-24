# 捕获区（inbox）

追加式。`bash ~/whz-harness/scripts/capture.sh "事实" [--tag <机器/项目>]` 往这里追加；整理后把稳定结论提升到 `personal.md` / `projects/<项目>.md` / `machines/<机器>.md`，并删掉这里已整理的条目。

格式：`- <UTC 时间> [<主机>] <事实>`

## 待整理

（新条目追加在这里下面）

## 已整理（保留近期几条作为脉络，其余删掉）

- 2026-09-24T00:00:00Z [win-main] 记忆体系统一为一个公开仓库 `whz-harness`，四层注入：`personal-memory`（根）、`agent-memory`（记忆系统）、`machines-memory`（环境与硬约束）、`local-memory`（本地投放区，gitignore）。原来的独立仓库 `agent-memory` / `work-memory` 均已废弃。
- 2026-09-24T00:00:00Z [win-main] 环境信息（`machines/`）单独成层：更新频率最高，且含 kata/vfio 这类「必须经同意才能动」的硬约束，所以既要注入又要保持短，细节放 `machines/<机器>.md` 与 `machines/RULES.md`。
- 2026-09-24T00:00:00Z [win-main] 外部资料进 `materials/`（部署包文本 20 文件 236 KB 已入库到 `materials/agc64f-llm-deploy/`）；受控 PDF、zip、36 GiB 数据只留指针，登记在 `materials/INDEX.md`。
- 2026-09-24T00:00:00Z [win-main] 全仓库扫描确认：无非 loopback IP、无凭据；完整 IP 一律不写，只写网段。
- 2026-09-24T00:00:00Z [win-main] 教训：批量文本替换不要叠 `sed`，行尾反斜杠（shell 续行符）会被误伤成 `$`（曾损坏 12 个文件 297 行）。改完必须与原文件 diff。
