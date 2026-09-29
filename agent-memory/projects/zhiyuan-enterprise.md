# 项目：知远企业版（Zhiyuan Enterprise）（zhiyuan-enterprise）

> 事实 + 时间；不确定标 `[推测]`。工作目录：`D:/rongxin/`（win-main）。

## 使用说明（会话开始先读这节）

1. **仓库规则优先**：进哪个仓库先读该仓的 `AGENTS.md`（zhiyuanAaaS / Agent-Enterprise-Protocol 各有一份，规则详细且优先于本档案）。
2. **外部知识 → zhiyuan-docs**：产品/架构/API/**部署**问题一律查 `D:/rongxin/zhiyuan-docs/`（指针登记在 `materials/zhiyuan-docs/README.md`）。本机已 clone；没 clone 的机器先 `gh repo clone rongxinzy/zhiyuan-docs`。关键入口：`07-deployment/k3s-bringup.md`（部署权威手册）、`07-deployment/cicd-cluster.md`。
3. **antd skill 必须使用**：凡任务涉及 Ant Design（写组件、查 props/token/demo、版本迁移、分析 antd 用法，触发词含 `antd` import），必须读并遵循项目内 `.agents/skills/antd/SKILL.md`（zhiyuanAaaS 已安装，来源 `ant-design/ant-design-cli`，锁在 `skills-lock.json`）。skill 依赖 `@ant-design/cli`，首次使用自动 `npm install -g @ant-design/cli`；输出出现 "Update available" 时先跑 `antd upgrade`。**不要凭记忆写 antd 代码**——离线元数据里有 v4/v5/v6 的精确 API。
4. **记忆回写**：本项目新结论（部署坑、模型约定、流程变化）→ 提炼进本档案或该仓 `AGENTS.md`，别只留在会话里。

## 仓库拓扑（2026-09-29 确认）

| 仓库 | 性质 | 说明 |
|---|---|---|
| `D:/rongxin/zhiyuanAaaS` | 闭源企业扩展 | 知远企业扩展 + Admin Console；详细规则见仓库内 `AGENTS.md`；已装项目级 antd skill |
| `D:/rongxin/Agent-Enterprise-Protocol` | 公开 AEP | 契约/SDK/控制面/网关；见仓库内 `AGENTS.md` |
| `D:/rongxin/zhiyuan-docs` | 私有文档（rongxinzy/zhiyuan-docs） | 产品/架构/API/部署手册；指针见 `materials/zhiyuan-docs/README.md` |
| `aep-deerflow-governance` | 私有（未 clone 到本机） | 治理版 DeerFlow、memory-stack/DeerFlow/de-portal 的 k3s 清单都在这里 |
| `WeKnora` fork（rongxinzy，分支 `zhiyuan/helm-extra-env`） | 未 clone 到本机 | WeKnora 知识库 helm chart |

## 部署（k3s 全栈）

**唯一权威手册：`D:/rongxin/zhiyuan-docs/07-deployment/k3s-bringup.md`**（2026-09-24）。
单节点 k3s on WSL2；部署顺序不可乱序：Higress → AEP 控制面 → 记忆栈 → 模型路由 → WeKnora → DeerFlow/de-portal。

关键端口：AEP 30180 / 模型网关 30181 / de-portal 30190 / Admin Console 30196 / deerflow-gateway 30101。
开发备选（无 k3s）：`npm run compose:gateway:up`（AEP 仓）。

高频坑速查见手册第 12 节：AEP 密码 ≥12 字符；Docker 29 转推镜像先拍平（`~/flatten-push.py`）；pause 必须 3.10.2；openviking 不传 args；同 tag 覆盖不生效 → deerflow-gov 严格 vN 递增。

## UI 约定（两套不混用）

- **Admin Console 现有 UI 是 shadcn/Tea 主题**（见 AaaS `AGENTS.md`「Admin Console UI」节）：shadcn 组件、Lucide 图标、Tea 语义 token、i18n 双语。改现有页面按这套来。
- **antd skill**：AaaS 已确认引入 antd 6.6.5 + `@ant-design/icons`（`package.json`，`src/admin/App.tsx` 在用），antd 相关任务**必须**走 `.agents/skills/antd/SKILL.md`（见「使用说明」第 3 条）。新页面若用 antd，遵守 skill 的元数据查询流程，不凭记忆猜 API。

## 待办 / 缺口

- [ ] clone `aep-deerflow-governance`（k3s 清单来源）
- [ ] clone rongxinzy/WeKnora fork
