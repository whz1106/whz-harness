# whz-harness

**一个公开仓库，装 agent 需要的全部上下文**：规则与记忆、环境约束、可复用 skills、外部资料、模板。

clone 下来就能让 agent 直接读；跑一次 `scripts/sync.*`，同样的内容注入到 omp / Claude Code / Codex CLI / Gemini CLI / Copilot 的用户级配置，任何项目里都生效。

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

machines/               业务环境信息与硬约束（更新频率最高）
  ├── AGENTS.md      铁律 + 机器索引                                                  ← 注入
  ├── 64f.md         机器事实：kata / docker / vfio / 拓扑 / 坑
  └── RULES.md 禁改项清单（必须经我明确同意）

materials/         外部依赖资料
  ├── README.md      放什么、怎么放、README 骨架
  ├── INDEX.md       登记表：文件名 + 大小 + sha256 + 在哪
  └── agc64f-llm-deploy/   已入库的部署包文本（20 文件 / 236 KB）

skills/            常用 skills
templates/         AGENTS.md / machine.md 参考模板
scripts/           sync（注入）/ capture（捕获）/ scan-sensitive（脱敏扫描）
.githooks/         pre-commit：提交前自动扫描
local/             本地投放区（gitignore，只有 README.md 入库）                      ← 注入
```

## 四层注入

| marker block | 来源 | 内容 | 入库 |
| --- | --- | --- | --- |
| `personal-memory` | 根 `AGENTS.md` / `RULES.md` | 规则、偏好、习惯、通用坑 | ✅ |
| `agent-memory` | `agent-memory/AGENTS.md` | 记忆系统索引（长文按需读） | ✅ |
| `machines-memory` | `machines/AGENTS.md` | 环境铁律 + 机器索引 | ✅ |
| `local-memory` | `local/AGENTS.md` | 真实地址、受控资料路径 | ❌ gitignore |

**只有 `AGENTS.md` / `RULES.md` 被注入**，`personal.md`、`projects/`、`machines/<机器>.md`、`materials/` 只进索引，由 agent 按需 `read` —— 否则每个会话都在烧那几百行手册的 token。

## 新机器 / 新 agent

```bash
gh repo clone whz1106/whz-harness ~/whz-harness
cd ~/whz-harness && git config core.hooksPath .githooks
mkdir -p local && cp <你保存的那份 local 内容> local/      # 真实地址、受控路径
bash scripts/sync.sh                                        # Windows: powershell -File $HOME\whz-harness\scripts\sync.ps1
```

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
