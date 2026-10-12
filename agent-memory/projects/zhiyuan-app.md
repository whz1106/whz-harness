# 项目：知远智能体桌面应用（zhiyuan-app）

> 2026-10-07 核对。来源：用户说明、项目当前 `AGENTS.md`、`CLAUDE.md` 和开发技能目录。本档案提供导航，不替代项目规则。

## 项目与入口

- win-main 工作目录：`D:/rongxin/RongxinAI`。
- 知远智能体（ZhiYuan Agent）是 Electron + React + TypeScript 的本地优先 AI Agent 桌面应用，包含 Work/Chat、Skills/MCP、Artifacts 和本地推理等功能。
- 与知远企业版（AEP/AaaS/k3s）是不同开发入口；企业版见 `zhiyuan-enterprise.md`。晓软是基于知远的客户定制分支，见 `xiaoruan-app.md`。切换项目时重新读目标仓规则，不假定功能与配置一致。

## 开始开发时读什么

1. 先读项目根 `AGENTS.md`；`CLAUDE.md` 已于 2026-10-07 改为普通 UTF-8 文件，使用 `@AGENTS.md` 导入同一规则，不再依赖 Git 软链接支持。原先本机把软链接检出为文件名占位的入口问题已修复，Git 配置保持原值。
2. UI 工作先读根 `DESIGN.md` 相关章节、受影响组件和 token/recipe；主题工作再读 `src/renderer/theme/README.md`。
3. 按任务读取下面的开发技能；技能与旧代码不能覆盖当前 `AGENTS.md` / `DESIGN.md`。
4. 检查工作区已有改动，仅修改、暂存本任务文件。具体代码、测试和 PR 规则以项目当前文件为准。

## 配套开发技能（2026-10-07 现场核对）

| 场景 | 入口与状态 |
| --- | --- |
| 既有产品界面的视觉或布局调整 | 已存在 `.codex/skills/frontend-ui-change-strategy/SKILL.md`；读取后按其分析、方案、批准、实施与验证流程执行，结合会话已有授权 |
| shadcn/ui 基础组件、ai-elements 对话组件 | 项目规则要求复用 `src/shared/components/ui/` 与 `src/shared/components/ai-elements/`；项目提到 `shadcn/ui`、`vercel/ai-elements` 技能，实际可用入口须在当前 agent 环境核对 |
| 产品 UI 适配 | 已补齐 `.codex/skills/rongxinai-ui-adapter/SKILL.md`，包含共享组件矩阵、token/recipe 与桥接源码入口、i18n、状态连续性及验证路由 |
| landing、营销、品牌页 | 按项目规则读取可用的 `design-taste-frontend`；明确要求高级视觉或复杂动效时才读取 `high-end-visual-design`，不将营销页风格套到产品页 |
| 提交、PR | harness `skills/git-pr-workflow/SKILL.md`，同时遵守项目自己的 Git 安全与 PR 门禁 |

`SKILLs/` 是应用内置、供产品 Agent 运行时使用的技能，不是开发本项目的 IDE/编码 agent 技能。当前桌面项目采用 shadcn/ui + ai-elements，不沿用企业版的 Ant Design 任务路由。项目适配技能保存在项目仓库，不复制到个人 harness；不同 agent 都可按 AGENTS.md 中的路径读取，不假定工具自动发现。

2026-10-07 全局技能核对：在本机 `.claude/skills`、`.agents/skills`、`.codex/skills` 与 `.omp/agent/skills` 中未找到 `shadcn/ui`、`vercel/ai-elements`、`high-end-visual-design` 对应 SKILL.md。已找到 `design-taste-frontend`：`C:/Users/Administrator/.codex/skills/taste-skill/SKILL.md`。本次仅补齐项目适配技能；外部可选技能和插件在实际任务时核对，不作为桌面开发的安装前提。

## 开发与验证速查

- Node.js >=24 <25、Bun >=1.3；依赖安装用 `bun install`，锁文件 `bun.lock`，npm 用于运行脚本。
- 开发：`npm run electron:dev`；检查：`npm run lint`、`npm test -- <name>`；构建：`npm run build`，仅主进程可用 `npm run compile:electron`。
- token/recipe/生成器变化跑 `bun run theme:generate`；共享主题契约或引擎变化另跑 renderer/shared 测试、构建与 bundle-budget。UI 要实际运行验证明暗主题、交互状态与主题热切换，命令通过不等于视觉验收。
- Pi 是唯一执行内核；主进程负责 IPC、状态、安全与生命周期，纯阻塞扫描/哈希/解析按项目 Worker 边界处理。具体约束开发时重读项目规则，不由本档案保存实现快照。
