# whz-harness

**个人 agent 上下文仓库**：共享工作习惯与技能索引，并为项目、64F 环境和部署资料提供明确入口。本仓库公开，敏感值和大文件留在 `local/` 或个人硬盘。

clone 到 Mac 或 Windows 后，运行一次 `scripts/sync.*`，把简短规则与索引写到已配置的 omp / Claude Code / Codex CLI / Gemini CLI / Copilot 用户级入口。同步内容会写入本机仓库绝对路径；本文所有仓库路径均以仓库根目录为基准。

## Agent 怎么读

| 当前任务 | 先读 | 再按需读 |
| --- | --- | --- |
| 普通项目工作 | 当前项目 `AGENTS.md` / `CLAUDE.md`、本仓库 `AGENTS.md` | 按项目实际目录读取开发技能，或本仓库 `skills/<name>/SKILL.md` |
| Git 提交或 PR | 本仓库 `AGENTS.md` 的提交习惯 | `skills/git-pr-workflow/SKILL.md` |
| 64F 相关工作 | `machines/AGENTS.md`、`machines/RULES.md` | `machines/agc64f.md`；操作前只读核对当前状态 |
| 64F 大模型部署 | 上一行机器规则 | `materials/agc64f-llm-deploy/README.md` → `materials/agc64f-llm-deploy/ASSETS.md` → `materials/agc64f-llm-deploy/AI_CONTEXT.md`；本机 `local/assets.local.md`（若存在） |
| `four-test-v1` 工作 | 该项目仓库当前 `AGENTS.md` | 本仓库只提供 `materials/four-test/README.md` 指针和 64F 通用禁改规则 |
| 知远企业版（zhiyuanAaaS / Agent-Enterprise-Protocol） | 项目仓各自 `AGENTS.md` + 本仓库 `agent-memory/projects/zhiyuan-enterprise.md` | 产品/需求/交互读 `zhiyuan-docs/product/README.md`；部署与环境读 `zhiyuan-docs/guides/cicd-environment.md`（入口汇总 `materials/zhiyuan-docs/README.md`）；antd 任务读项目 `.agents/skills/antd/SKILL.md` |
| 知远桌面应用（`D:/rongxin/RongxinAI`） | 项目 `AGENTS.md` / `CLAUDE.md` + `agent-memory/projects/zhiyuan-app.md` | UI 读 `DESIGN.md` 与 `.codex/skills/frontend-ui-change-strategy/SKILL.md`；复用 shadcn/ui + ai-elements |
| 晓软定制桌面应用（`D:/rongxin/xiaoruan-ai-agent`） | 项目 `AGENTS.md` / `CLAUDE.md` + `agent-memory/projects/xiaoruan-app.md` | 定制读 `CUSTOMIZATION.md`；UI 读 `DESIGN.md` 与 `.codex/skills/frontend-ui-change-strategy/SKILL.md` |

`AGENTS.md` 是 agent 的执行入口；本 `README.md` 是安装、目录分工和人工维护说明。历史机器基线、上次观察和项目规则快照均不能代替操作前的当前核对。

开发技能沿用项目实际入口，不为统一命名搬迁。2026-10-07 两个桌面项目均有 `.codex/skills/frontend-ui-change-strategy/` 和 `.codex/skills/rongxinai-ui-adapter/`，CLAUDE.md 使用普通文件的 `@AGENTS.md` 导入；它们的 `SKILLs/` 是产品运行时内置技能。全局 UI 技能按当前环境核对，企业版的 Ant Design 要求不自动套到桌面项目。

## 结构

```
AGENTS.md          入口：导航 + 规则 + 个人记忆（偏好、工具链、编码/提交习惯、通用坑）  ← 注入
RULES.md           硬规则：远程环境必须经同意、公开面不写敏感值、仓库纪律              ← 注入
CLAUDE.md          @AGENTS.md（一行导入，不复制内容，避免漂移）

agent-memory/      记忆系统
  ├── AGENTS.md      索引 + 写入规则（防膨胀）                                        ← 注入
  ├── personal.md    个人记忆长文
  ├── projects/      项目记忆（每个项目一个文件）
  └── notes/inbox.md 捕获区

machines/               业务环境历史基线与硬约束
  ├── AGENTS.md      铁律 + 机器索引                                                  ← 注入
  ├── agc64f.md      机器事实：kata / docker / vfio / 拓扑 / 坑
  └── RULES.md 禁改项清单（必须经我明确同意）

materials/         外部依赖资料
  ├── README.md      放什么、怎么放、README 骨架
  ├── INDEX.md       登记表：文件名 + 大小 + sha256 + 在哪
  └── agc64f-llm-deploy/   部署文档、脚本、配置、资产索引；不含权重/镜像

skills/            个人通用 skills（已接入工具按注入索引读取；omp 另有镜像）
templates/         项目、机器、本机索引与资产状态模板
scripts/           sync（注入）/ capture（捕获）/ scan-sensitive（脱敏扫描）
.githooks/         pre-commit：提交前自动扫描
local/             本机投放区（gitignore，只有 README.md 入库；有 AGENTS.md 时注入）
```

## 仓库目录怎么分工

| 目录 | 放什么 | 不放什么 |
| --- | --- | --- |
| `skills/` | 跨项目复用的个人技能，每个技能一个 `SKILL.md` | 某个项目独有的流程 |
| 项目仓 `.agent/skills/`、`.agents/skills/`、`.codex/skills/` | 沿用项目实际开发技能目录；项目 `AGENTS.md` 写触发条件 | 个人通用技能的复制品 |
| `agent-memory/` | 个人习惯、项目结论和短索引 | 可以从代码或日志直接重建的大段细节 |
| `machines/` | 带来源的历史基线、核验入口和危险操作规则 | 凭旧记录猜测的当前在线状态 |
| `materials/` | 可入库的部署文本、脚本、配置和大文件指针 | 权重、镜像 tar、受控原件 |
| `local/` | 每台电脑不同的路径、资产位置、最近一次只读观察；Git 忽略 | 需要跨机器公开同步的通用规则 |
| `templates/` | 新项目、新机器、本机资产及状态记录的起点 | 已填有真实路径或私有值的文件 |

`four-test`、`four-test-v1` 的小模型与实验代码留在各自项目仓库；这里仅保留必要指针。大模型则在 `materials/agc64f-llm-deploy/` 维护部署方法，在个人硬盘保存权重和镜像。

普通项目采用下面的最小结构；`.agent/skills/` 只放该项目确实需要的技能：

```text
my-project/
├── AGENTS.md                    # 项目规则、技能触发条件、环境边界
├── .agent/
│   └── skills/
│       └── <project-skill>/
│           └── SKILL.md         # 项目专用流程
└── ...                          # 项目自己的代码、数据索引和文档
```

`templates/AGENTS.md` 是项目入口模板，默认按 `~/whz-harness` 克隆位置编写；若仓库放在别处，生成项目规则时把引用替换为实际路径。

## 注入层

| marker block | 来源 | 内容 | 入库 |
| --- | --- | --- | --- |
| `personal-memory` | 根 `AGENTS.md` / `RULES.md` | 规则、偏好、习惯、通用坑 | ✅ |
| `agent-memory` | `agent-memory/AGENTS.md` | 记忆系统索引（长文按需读） | ✅ |
| `machines-memory` | `machines/AGENTS.md` | 环境铁律 + 机器索引 | ✅ |
| `local-memory` | `local/AGENTS.md`（存在时） | 本机私有索引，不自动展开文件内容 | ❌ gitignore |

**只有各层的 `AGENTS.md` / `RULES.md` 被注入**；`agent-memory/personal.md`、`agent-memory/projects/`、`machines/<机器>.md`、`materials/` 由索引指引按需读取，避免每轮装入整份手册。

新项目默认技能目录见上面的最小结构；已有项目沿用真实路径，并在 `AGENTS.md` 写清触发场景。已读取项目规则的 agent 可以按路径打开技能；原生自动发现仍取决于具体工具。模板见 `templates/AGENTS.md`。

## Mac / Windows 首次安装

Mac（终端）：

```bash
gh repo clone whz1106/whz-harness "$HOME/whz-harness"
cd "$HOME/whz-harness"
git config core.hooksPath .githooks
cp templates/local-AGENTS.md local/AGENTS.md
# 按本机已有文件编辑 local/AGENTS.md，再执行下一行
bash scripts/sync.sh --no-pull
```

Windows（PowerShell）：

```powershell
gh repo clone whz1106/whz-harness "$HOME\whz-harness"
Set-Location "$HOME\whz-harness"
git config core.hooksPath .githooks
Copy-Item templates\local-AGENTS.md local\AGENTS.md
# 按本机已有文件编辑 local\AGENTS.md，再执行下一行
powershell -ExecutionPolicy Bypass -File scripts\sync.ps1 -NoPull
```

先编辑 `local/AGENTS.md`，删掉不存在的本机文件项；模型权重、镜像路径按 `templates/local-assets.md` 填入 `local/assets.local.md`，64F 最近一次只读观察按 `templates/agc64f-state.local.md` 填写。`local/` 不随 Git 同步，换电脑需自行安全转移或重新填写。

同步与捕获脚本默认使用**自己所在的仓库**（脚本目录的父目录），因此仓库放哪都不影响。仓库被复制/移动到别处、或有多个副本时，用 `MEMORY_REPO` 显式指定要用哪一份（Mac：`export MEMORY_REPO=/实际路径`；PowerShell：`$env:MEMORY_REPO = '实际路径'`）——不要长期保留第二份副本，多副本并存会让注入悄悄用错源。不要在已有仓库上重复运行 clone 命令。

同步后检查目标工具的用户级文件是否含 `personal-memory`、`agent-memory`、`machines-memory` 三个受管块；建立了 `local/AGENTS.md` 时还应有 `local-memory`。再从**另一个项目目录新开 agent 会话**，让它指出 GitHub 账号、该项目的技能入口及 64F 禁改清单的位置，确认它实际读到了索引。技能能否原生自动列出需按所用工具另验。

给一个新项目/新机器建规则：skill **`agent-bootstrap`**（按 `templates/` 生成一份本地 `AGENTS.md`，把该环境的硬约束抄进去）。

## 三条工作流

| 工作流 | 入口 | skill |
| --- | --- | --- |
| 记忆：inbox → 提升到正式文件 | `agent-memory/AGENTS.md` | `harness-memory` |
| 环境：动手前读约束、破坏性操作必须经同意 | `machines/AGENTS.md` → `machines/RULES.md` | `machine-ops-guard` |
| 资料：外部资料入库 + 登记 + 适配 | `materials/README.md` → `INDEX.md` | `materials-intake` |

```bash
bash scripts/capture.sh "事实"                     # 捕获一条（只提交 inbox）
bash scripts/capture.sh "某机器的坑" --tag agc64f
bash scripts/scan-sensitive.sh                     # 手工全库扫描（故意跳过 local/）
```

`capture.sh` / `capture.ps1` 会自动提交，默认还会推送；`--no-push` / `-NoPush` 仅关闭推送，不关闭提交。只做本地记忆编辑时直接追加 inbox 并整理，提交/推送按实际授权执行。脚本自定位仓库，无需再设 `MEMORY_REPO`（win-main 的 C 盘旧副本已于 2026-10-08 删除）。

改过注入层（`AGENTS.md` / `RULES.md` / `agent-memory/*` / `machines/*`）后必须跑一次 `sync`。

## skills 一览

| skill | 用途 |
| --- | --- |
| `agent-bootstrap` | 新项目/新机器：生成 `AGENTS.md`、挂记忆与资料、装注入 |
| `machine-ops-guard` | 动远程机器前的闸门：禁改项、必须经同意、故障信号停手 |
| `materials-intake` | 外部资料收编：分流、脱敏、登记、写标准 README |
| `harness-memory` | 记忆读写流程与命令 |
| `antd` | Ant Design 任务的本地 API/token/demo 查询；优先项目已安装版本 |
| `git-pr-workflow` | 提交与 PR/MR 规范（`references/commit-pr-format.md`） |
| `clarify-before-coding` | 澄清再动手：对齐意图/根因/解法后再改；小 PR；确认后可派 subagent |
| `adversarial-code-review` | 对抗式审查：本 PR 问题 + 合并后新风险；只审不擅自改 |
| `antd` | Ant Design：组件 API/迁移/诊断（`@ant-design/cli`） |
| `modelscope-api` | ModelScope OpenAPI、下载、发布、打包 |
| `Deli_AutoResearch` | 长任务自治框架（状态文件、卡死检测、心跳看护） |

## 公开面纪律

这个仓库是公开的，所以：

- **完整 IP 不写**（只写网段 `172.18.5.***`），真值放 `local/` 或 `~/.ssh/config`。
- 客户名/单位名不写，用机器代号（`agc64f`）。
- 密钥、token 不写；受控 PDF、zip、大数据只记文件名 + 大小 + sha256。
- `scripts/scan-sensitive.sh` + pre-commit 钩子兜底（**故意跳过 `local/`**，那是有意保留的本地投放区）。
- `local/` 里的东西**不要 `git add -f`**。

## 与其它仓库的分工

| 关注点 | 归属 |
| --- | --- |
| agent 上下文（跨项目、跨机器） | **本仓库** |
| 项目代码 + 项目级 `AGENTS.md` | 项目仓（如 `four-test-v1`），规则跟项目走 |
| 工作日志 | `work-docs` |
| 想单独对外发布的 skill | 独立公开仓（如 `modelscope-api-skill`） |

## 不包含

- 密钥、token、完整 `.env`、完整 IP、客户名
- 大型测试数据、部署包 zip、受控 PDF 本体
- benchmark 原始输出、大日志、截图、dump、trace
