# 项目：晓软智能体定制桌面应用（xiaoruan-app）

> 2026-10-07 核对。来源：用户说明、项目当前 `AGENTS.md`、`CLAUDE.md`、`CUSTOMIZATION.md` 入口及开发技能目录。本档案提供导航，不替代项目规则。

## 项目与入口

- win-main 工作目录：`D:/rongxin/xiaoruan-ai-agent`。
- 晓软智能体（晓软Agent）是基于知远桌面应用的客户定制分支，使用 Electron + React + TypeScript。知远桌面版见 `zhiyuan-app.md`，知远企业版见 `zhiyuan-enterprise.md`。
- 对外名称使用晓软智能体（晓软Agent）；定制约束与知远桌面版分开核对，不因代码来源相同而恢复上游功能。

## 开始开发时读什么

1. 先读项目根 `AGENTS.md`；`CLAUDE.md` 已于 2026-10-07 改为普通 UTF-8 文件，使用 `@AGENTS.md` 导入同一规则，不再依赖 Git 软链接支持。原先本机把软链接检出为文件名占位的入口问题已修复，Git 配置保持原值。
2. 定制功能、认证、模型或打包相关任务，继续读 `CUSTOMIZATION.md`，核对 `src/main/appConstants.ts` 与 `electron-builder.json`。
3. UI 工作先读根 `DESIGN.md` 相关章节、受影响组件和 token/recipe；主题工作再读 `src/renderer/theme/README.md`。
4. 检查工作区已有改动，按任务读取下面的技能。项目当前规则优先，不把 harness 的摘要当作规则快照。

## 定制边界（来源：2026-10-07 项目 AGENTS.md）

- 无产品账号登录、登录 deep-link、游客令牌或内置免费模型；模型只来自用户绑定的 AISphere 平台，所有内置模型调用经过 AISphere 网关，真实地址与密钥仅由主进程持有。
- 不开放第三方提供商、自定义模型或本地模型入口，不重新接入上游账号、免费模型或自动更新服务。仓库存在本地推理代码不代表可以重新开放入口。
- 品牌与数据隔离依据项目配置；旧数据与目录原地弃置，不做未要求的迁移、兼容、读取或主动删除。

## 配套开发技能（2026-10-07 现场核对）

| 场景 | 入口与状态 |
| --- | --- |
| 既有产品界面的视觉或布局调整 | 已存在 `.codex/skills/frontend-ui-change-strategy/SKILL.md`；读取后按其分析、方案、批准、实施与验证流程执行，结合会话已有授权 |
| 基础与对话 UI | 复用 `src/shared/components/ui/`（shadcn/ui）和 `src/shared/components/ai-elements/`；项目提到全局 `shadcn/ui`、`vercel/ai-elements` 技能，实际可用入口须在当前 agent 环境核对 |
| 产品 UI 适配 | 已补齐 `.codex/skills/rongxinai-ui-adapter/SKILL.md`；使用晓软项目自己的版本，包含组件/主题/i18n 路由与 AISphere 定制边界 |
| landing、营销、品牌页 | 按项目规则使用可用的 `design-taste-frontend`；明确要求高级视觉或复杂动效时才读 `high-end-visual-design`；均不得覆盖 `DESIGN.md` |
| 提交、PR | harness `skills/git-pr-workflow/SKILL.md`，同时遵守项目 Git 安全规则 |

`SKILLs/` 是产品运行时的内置技能，不是开发本仓库的技能目录。桌面 UI 使用 shadcn/ui + ai-elements，企业版的 Ant Design 要求不自动适用于晓软。项目适配技能保存在项目仓库，不复制到个人 harness；不同 agent 按 AGENTS.md 的明确路径读取，不假定工具自动发现。

2026-10-07 全局技能核对范围和结果与 `zhiyuan-app.md` 一致：四个本机技能目录未找到 shadcn/ui、ai-elements 和高级视觉技能；`design-taste-frontend` 已在 Codex 的 `taste-skill/SKILL.md` 找到。本次已补齐项目 UI 适配技能，外部可选技能不是开发前提；插件与其它机器另查。

2026-10-07 记忆实现核对：`src/main/main.ts` 已接入 Engram 与 `ProjectMemoryService`，`piRuntimeAdapter.ts` 使用记忆上下文并执行轮后整理，旧 MEMORY.md 导入候选。已修正项目 AGENTS.md 中过时的文件记忆说明；本 harness 是开发 agent 的上下文仓库，与应用的产品记忆是不同系统。

## 开发与验证速查

- Node.js >=24 <25、Bun >=1.3；依赖用 `bun install` 与 `bun.lock`。
- 开发：`npm run electron:dev`；检查：`npm run lint`、`npm test -- <name>`；构建：`npm run build`，仅主进程可用 `npm run compile:electron`。
- token/recipe/生成器变化跑 `bun run theme:generate`；共享主题契约或引擎变化补 renderer/shared 测试、构建和 bundle-budget。UI 要实际验证明暗主题、键盘、适用状态及主题热切换。
- 主进程 / Worker 边界、i18n、IPC 常量和多会话 Git 纪律均按当前项目 `AGENTS.md` 执行；纯文档修改核对链接、路径和 `git diff --check`。
