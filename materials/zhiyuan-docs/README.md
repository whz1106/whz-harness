# zhiyuan-docs

## 是什么 / 从哪来
- 智源数字员工平台的私有文档仓 `rongxinzy/zhiyuan-docs`（GitHub 私有，用户 `whz1106` 有权 clone）。
- 产品设计、治理白皮书、需求、架构、API 指南、**k3s 部署手册**。AEP 仓库 README 明确引用它的 k3s bring-up runbook。

## 本体在哪
本机已 clone：`D:/rongxin/zhiyuan-docs/`（win-main）。**不入库本仓**（私有仓 + 本仓是公开仓），需要时：
```bash
gh repo clone rongxinzy/zhiyuan-docs
```

## 顶层导航
| 目录 | 内容 |
|---|---|
| `00-enterprise` / `01-product` / `02-whitepaper` / `03-requirements` | 企业/产品/白皮书/需求 |
| `04-tech` / `05-architecture` / `06-api` | 技术/架构/API |
| `07-deployment` | **部署（最重要）** |
| `08-development` | 开发 |

关键文档：
- `07-deployment/k3s-bringup.md` —— k3s 全栈部署手册（Higress → AEP → 记忆栈 → 模型路由 → WeKnora → DeerFlow/de-portal）
- `07-deployment/cicd-cluster.md` —— CI/CD 集群

## 已知坑
见 `k3s-bringup.md` 第 12 节「部署常见坑速查」。

## 相关记忆与环境
- 项目记忆：`agent-memory/projects/zhiyuan-platform.md`
- 机器约束：`machines/AGENTS.md`、`machines/RULES.md`（远程机器操作前必读）
