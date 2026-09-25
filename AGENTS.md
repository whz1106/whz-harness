# whz-harness —— agent 上下文包

> 这份文件有两个身份：**本仓库的 `AGENTS.md`**（在这里工作时自动读到），以及**用户级记忆**（`scripts/sync.*` 把它注入到 omp / Claude Code / Codex / Gemini / Copilot 的用户级配置）。
> 只写**可复用的偏好与已验证事实**；一次性上下文不写，项目细节放 `agent-memory/projects/`。
> 下文路径均相对 **whz-harness 仓库根目录**，不是当前工作项目；同步后的受管块开头会给出这台电脑上的绝对路径。

## 每次开始任务

1. 先读当前项目的 `AGENTS.md`（若存在），按它的触发条件读取项目 `.agent/skills/<name>/SKILL.md`。项目当前文件是项目规则的来源。
2. 本文件提供个人偏好和导航。只按任务需要继续读对应层，不要每次加载全部机器手册、项目记忆和部署包。
3. 涉及 `agc64f` 或其它登记机器时，**先读** `machines/AGENTS.md`、`machines/RULES.md`、`machines/<机器>.md`，再做只读现场核对。历史基线或 `local/` 的上次观察都不代表当前状态；ACS/VFIO/PCI/Kata 全局变更须用户明确授权。
4. 涉及大模型部署时，再读 `materials/agc64f-llm-deploy/README.md`、`materials/agc64f-llm-deploy/ASSETS.md`，以及本机 `local/assets.local.md`（若存在）。权重和镜像在个人硬盘，不在 Git。

## 先看哪里（导航）

| 我要…… | 去哪 |
| --- | --- |
| 知道这台机器/这个环境的硬约束 | `machines/AGENTS.md` → `machines/RULES.md`（**动手前必读**） |
| 查已有记忆、写新记忆 | `agent-memory/AGENTS.md` |
| 拿外部资料（部署包、脚本、项目资料） | `materials/README.md` → `materials/INDEX.md` |
| 复用个人技能 | 本仓库 `skills/<name>/SKILL.md`；注入层会给出本仓库绝对路径 |
| 使用项目自选技能 | 项目根目录 `.agent/skills/<name>/SKILL.md`，先读项目 `AGENTS.md` 的选择规则 |
| 起一个新项目/新机器的规则文件 | `templates/AGENTS.md` + skill `agent-bootstrap` |
| 本机私有索引（SSH 别名、受控资料与硬盘路径） | `local/AGENTS.md`（若存在；不进 git） |

## 用户与账号

- GitHub 账号：`whz1106`；优先用 `gh` 处理 GitHub 仓库与 PR。历史记录中 `gh` 已登录，执行需认证的操作前用 `gh auth status` 核对当前机器状态；git 走 https。
- git identity：`whz <hzwang991106@gmail.com>`。
- 交流默认中文；代码、标识符、命令保持英文。

## 机器

| 别名 | 系统 | 家目录 | 本仓库路径 |
| --- | --- | --- | --- |
| win-main | Windows 11 Pro x64 / Intel i5-14500 / Windows Terminal | `C:\Users\Administrator` | 推荐 `~/whz-harness` |
| mac | macOS | `~/` | 推荐 `~/whz-harness` |

两端推荐克隆到各自家目录下的 `whz-harness`。若放在其它位置，以同步受管块给出的本机绝对路径为准；仓库内文档的相对路径始终以仓库根目录为基准。

## 工具链

- `omp`（Oh My Pi）：当前 18.2.6。agent 目录 `~/.omp/agent`（`PI_CODING_AGENT_DIR` 可重定位；`--profile <name>` 用 `~/.omp/profiles/<name>/agent`）。
- 本仓库被注入到这些用户级上下文文件（marker block 包裹，块内勿手改）：
  `~/.omp/agent/AGENTS.md`、`~/.omp/agent/RULES.md`、`~/.claude/CLAUDE.md`、`~/.codex/AGENTS.md`、`~/.gemini/GEMINI.md`、`~/.copilot/copilot-instructions.md`。
- `skills/*/SKILL.md` 会镜像到 `~/.omp/agent/skills/`。
- 其它 agent 通过本文件的技能索引按需读取本仓库 `skills/<name>/SKILL.md`；不要假设它们会自动发现 omp 的镜像。
- 这份注入只覆盖上列已配置的工具和配置路径；新 agent 或自定义 profile 需另行核对其加载入口。

## 技能选择

- 先读当前项目的 `AGENTS.md`；项目专用技能放在该项目的 `.agent/skills/`，由项目说明何时使用。
- 个人通用技能以本仓库 `skills/` 为唯一内容源。需要时先读对应 `SKILL.md`，按其中步骤执行；不要把项目技能复制进个人记忆层。
- 本仓库的全局技能入口：`agent-bootstrap`（新项目/机器）、`harness-memory`（记忆）、`machine-ops-guard`（远程机器）、`materials-intake`（外部资料）、`git-pr-workflow`（提交与 PR）。其它技能见本仓库 `README.md`。
- 注入层：`personal-memory`（根）/ `agent-memory`（记忆系统）/ `machines-memory`（环境）/ `local-memory`（本地投放）。

## 偏好

- 交付必须可验证：改完要跑真实路径并给出输出，不接受「应该能行」。
- 回答简洁、可执行、直接给结论与证据，不要营销式措辞。
- 破坏性操作（`push --force`、删数据、改全局配置、动别人的目录）先确认。
- 优先复用已有的约定，不要在既有约定旁另起一套。
- 新建项目/新机器时，用 `templates/AGENTS.md` 生成一份本地 `AGENTS.md`，并把该环境的硬约束抄进去（见 skill `agent-bootstrap`）。

## 已知坑

- omp 的记忆后端默认 `off`（`memory.backend`，可选 `off|local|hindsight|mnemopi|sharpshooter`）。`/memory view` 在无可注入载荷时提示 `Memory payload is empty …` —— 那是提示，不是报错。
- omp 的 `local` 后端只处理「≥12h 空闲、≤30 天、且被持久化」的会话，且按 cwd 绝对路径分目录（Windows/macOS 编出的目录名不同）→ **不要**指望它跨机器共享；跨机器共享用本仓库。
- LLM provider 401 通常是凭据/配置问题而非模型故障。`lab-glm` 的 token 在 2026-09-21 前后无效；GLM-5.3-Flash 优先走 `opencode-go`。认证失败先用备用 provider 重试同一请求，别急着改代码或提示词。
- **批量文本替换不要叠 `sed`**：行尾反斜杠（shell 续行符）会被误伤。改完必须与原文件 diff。

## 编码与提交习惯

从本机约 20 个仓库（含 fork 的上游项目）的提交历史归纳：

- **Conventional Commits**：`<type>(<scope>): <subject>`。用到的 type：`feat` `fix` `docs` `chore` `refactor` `test` `perf` `ci` `style` `security` `release`。
- **scope** 用模块名，小写英文 kebab-case（`fix(scheduled-task)`），也常见中文模块名（`feat(模型设置):`）。主体中英混用，一行写完，不加句号。
- **PR 流程**：分支 `<type>/<slug>`（`feat/fixbug`、`ci/deploy-community-auth`、`codex/<slug>`），经 PR 合入主干，合入提交是 `Merge pull request #NNN from <org>/<type>/<slug>`。
- **带编号**：标题末尾加 `(#123)`；admin/后端类仓库用 e2e 测试跟真实中文控制台文案。
- **发布**：`release(<包名>): <版本>`，配 `chore: update package-lock`。
- **观测到的既成习惯**：同一改动分几轮提交时加 `-1`/`-2`/`-3` 后缀 —— 只适合过程提交，最终应 squash 成一条可独立理解的提交。
- **代码/标识符/命令用英文，界面文案与面向用户的话用中文。**
- 完整规范见 `skills/git-pr-workflow/references/commit-pr-format.md`。

## 三条工作流

1. **记忆**：新东西先落 `agent-memory/notes/inbox.md` 一行 → 稳定后提升到 `agent-memory/`（个人/项目）或 `machines/` → 删掉 inbox 里那行。入口见 `agent-memory/AGENTS.md`。
2. **环境**：任何远程机器操作前先读 `machines/AGENTS.md` 与对应 `machines/<机器>.md`；`machines/RULES.md` 里列的禁改项**必须经明确同意**。见 skill `machine-ops-guard`。
3. **资料**：外部资料进 `materials/`，同时在 `materials/INDEX.md` 登记（文件名 + 大小 + sha256），受控件与大数据只留指针。见 skill `materials-intake`。

## 不要记录

- 完整 IP 地址（只写网段，真值放 `local/` 或 `~/.ssh/config`）。
- 密钥、token、完整 `.env`；客户名/单位名。
- 大日志、完整模型输出、截图、dump；受控 PDF 与大数据本体。
- 可以直接从 git diff 看出的代码细节。

## 维护约定

- 每条记忆写「事实 + 时间」；不确定的结论标 `[推测]`。
- 改过本文件 / `RULES.md` / `agent-memory/*` / `machines/*` 后必须跑一次 `scripts/sync.*`，否则注入的还是旧的。
- 提交信息：`memory:` / `env:` / `materials:` / `capture:`；不要重写已推送历史。
