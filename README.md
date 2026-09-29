# whz-harness

**个人 agent 上下文仓库**：共享工作习惯与技能索引，并为项目、64F 环境和部署资料提供明确入口。本仓库公开，敏感值和大文件留在 `local/` 或个人硬盘。

clone 到 Mac 或 Windows 后，运行一次 `scripts/sync.*`，把简短规则与索引写到已配置的 omp / Claude Code / Codex CLI / Gemini CLI / Copilot 用户级入口。同步内容会写入本机仓库绝对路径；本文所有仓库路径均以仓库根目录为基准。

## Agent 怎么读

| 当前任务 | 先读 | 再按需读 |
| --- | --- | --- |
| 普通项目工作 | 当前项目 `AGENTS.md`、本仓库 `AGENTS.md` | 项目 `.agent/skills/<name>/SKILL.md` 或本仓库 `skills/<name>/SKILL.md` |
| Git 提交或 PR | 本仓库 `AGENTS.md` 的提交习惯 | `skills/git-pr-workflow/SKILL.md` |
| 64F 相关工作 | `machines/AGENTS.md`、`machines/RULES.md` | `machines/agc64f.md`；操作前只读核对当前状态 |
| 64F 大模型部署 | 上一行机器规则 | `materials/agc64f-llm-deploy/README.md` → `materials/agc64f-llm-deploy/ASSETS.md` → `materials/agc64f-llm-deploy/AI_CONTEXT.md`；本机 `local/assets.local.md`（若存在） |
| `four-test-v1` 工作 | 该项目仓库当前 `AGENTS.md` | 本仓库只提供 `materials/four-test/README.md` 指针和 64F 通用禁改规则 |

`AGENTS.md` 是 agent 的执行入口；本 `README.md` 是安装、目录分工和人工维护说明。历史机器基线、上次观察和项目规则快照均不能代替操作前的当前核对。

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
| 项目仓 `.agent/skills/` | 该项目自选技能；项目 `AGENTS.md` 写触发条件 | 个人通用技能的复制品 |
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

项目专用技能放项目仓库的 `.agent/skills/<name>/SKILL.md`，并在该项目 `AGENTS.md` 写清触发场景。已读取项目规则的 agent 可以按路径打开技能；原生自动发现仍取决于具体工具。模板见 `templates/AGENTS.md`。

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

若仓库放在其它位置，运行同步前把 `MEMORY_REPO` 设为实际目录（Mac：`export MEMORY_REPO=/实际路径`；PowerShell：`$env:MEMORY_REPO = '实际路径'`）。不要在已有仓库上重复运行 clone 命令。

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

改过注入层（`AGENTS.md` / `RULES.md` / `agent-memory/*` / `machines/*`）后必须跑一次 `sync`。

## skills 一览

| skill | 用途 |
| --- | --- |
| `agent-bootstrap` | 新项目/新机器：生成 `AGENTS.md`、挂记忆与资料、装注入 |
| `machine-ops-guard` | 动远程机器前的闸门：禁改项、必须经同意、故障信号停手 |
| `materials-intake` | 外部资料收编：分流、脱敏、登记、写标准 README |
| `harness-memory` | 记忆读写流程与命令 |
| `git-pr-workflow` | 提交与 PR/MR 规范（`references/commit-pr-format.md`） |
| `modelscope-api` | ModelScope OpenAPI、下载、发布、打包 |
| `daily-work-summary` | 日常工作总结 |
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
