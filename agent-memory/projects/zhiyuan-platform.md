# 项目：智源数字员工平台（zhiyuan-platform）

> 事实 + 时间；不确定标 `[推测]`。工作目录：`D:/rongxin/`（win-main）。

## 仓库拓扑（2026-09-29 确认）

| 仓库 | 性质 | 说明 |
|---|---|---|
| `D:/rongxin/zhiyuanAaaS` | 闭源企业扩展 | 知远企业扩展 + Admin Console；详细规则见仓库内 `AGENTS.md` |
| `D:/rongxin/Agent-Enterprise-Protocol` | 公开 AEP | 契约/SDK/控制面/网关；见仓库内 `AGENTS.md` |
| `D:/rongxin/zhiyuan-docs` | 私有文档（rongxinzy/zhiyuan-docs） | 产品/架构/API/部署手册 |
| `aep-deerflow-governance` | 私有（未 clone 到本机） | 治理版 DeerFlow、memory-stack/DeerFlow/de-portal 的 k3s 清单都在这里 |
| `WeKnora` fork（rongxinzy，分支 `zhiyuan/helm-extra-env`） | 未 clone 到本机 | WeKnora 知识库 helm chart |

## 部署（k3s 全栈）

**唯一权威手册：`D:/rongxin/zhiyuan-docs/07-deployment/k3s-bringup.md`**（2026-09-24）。
单节点 k3s on WSL2；部署顺序不可乱序：Higress → AEP 控制面 → 记忆栈 → 模型路由 → WeKnora → DeerFlow/de-portal。

关键端口：AEP 30180 / 模型网关 30181 / de-portal 30190 / Admin Console 30196 / deerflow-gateway 30101。
开发备选（无 k3s）：`npm run compose:gateway:up`（AEP 仓）。

高频坑速查见手册第 12 节：AEP 密码 ≥12 字符；Docker 29 转推镜像先拍平（`~/flatten-push.py`）；pause 必须 3.10.2；openviking 不传 args；同 tag 覆盖不生效 → deerflow-gov 严格 vN 递增。

## UI 约定

Admin Console 用 **Ant Design** 时安装了 `skills/antd`（harness 内，`npx skills add ant-design/ant-design-cli` 的离线元数据 CLI skill）。
注意：AaaS 仓库现有 UI 是 shadcn/Tea 主题（见 AaaS `AGENTS.md`），antd skill 用于新页面/工具类工作，两套约定不混用。

## 待办 / 缺口

- [ ] clone `aep-deerflow-governance`（k3s 清单来源）
- [ ] clone rongxinzy/WeKnora fork
- [ ] Admin Console 是否引入 antd 待定（现为 shadcn）
