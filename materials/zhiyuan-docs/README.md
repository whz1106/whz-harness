# zhiyuan-docs

## 是什么 / 从哪来
- 知远企业版（AaaS + AEP）的私有文档仓 `rongxinzy/zhiyuan-docs`（GitHub 私有，账号 `whz1106` 有权 clone）。
- **本企业版的主要资料**：产品范围与需求、后台交互规则、架构、接口、开发与部署环境记录都在这里。项目记忆只留结论与指针，不复制正文。

## 本体在哪
本机已 clone：`D:/rongxin/zhiyuan-docs/`（win-main）。**不入库本仓**（私有仓 + 本仓是公开仓）。没 clone 的机器：

```bash
gh repo clone rongxinzy/zhiyuan-docs
```

## 2026-10-08 改版：旧路径全部失效
顶层编号目录（`00-enterprise`…`08-development`）已取消，压平为 `product/`、`requirements/`、`architecture/`、`api/`、`guides/`、`99-archive/`。旧路径 → 新文档的对照表在仓库内 `migration.md`（GitHub 旧 URL 不会自动跳转）。本机 HEAD 已同步到 `c92edbe`（2026-10-08）。

## 顶层导航
| 入口 | 内容 |
|---|---|
| `product/README.md` | **产品文档唯一入口**（2026-10-08 起）：产品范围、能力、需求编号与状态（FR- / ER- / NFR-）、**管理后台交互规则**、验收条件 |
| `product/wireframes/` | 交互线框原型 |
| `requirements/README.md` | 需求索引（正文已归并进 `product/README.md`） |
| `guides/implementation-history.md` | 代码实现与测试记录（各批次范围、待部署事项） |
| `guides/cicd-environment.md` | **当前部署环境记录**：共享 k3s 集群、平台栈版本快照、端口与命名空间、运维纪律 |
| `guides/README.md` | 开发与部署入口（`development.md`、`devops.md`、`getting-started.md`、`devops-rollout-2026-10-07.md`） |
| `guides/k3s-reference.md` | 2026-09 从零部署参考 —— **历史记录，不作为当前安装步骤** |
| `architecture/README.md` | 系统组成、权限、请求链路、治理、记忆与知识、日志 |
| `api/README.md` | 接口与渠道集成（AEP、chat runtime、IM 渠道） |
| `99-archive/` | 历史资料（含 `zhiyuanAaaS/private_doc` 白皮书与已废弃稿） |
| `migration.md` / `CONTRIBUTING.md` / `glossary.md` | 迁移对照 / 文档维护规范 / 术语表 |

仓库自带 `AGENTS.md` 与 `scripts/check_docs.py`（文档校验）；改该仓文档前先读这两份。

## 怎么用（最短路径）
```bash
cd /d/rongxin/zhiyuan-docs && git pull --ff-only
sed -n '1,60p' README.md                 # 全部查阅入口
sed -n '1,80p' product/README.md         # 产品/需求/交互问题
sed -n '1,60p' guides/cicd-environment.md # 部署与环境问题
sed -n '1,60p' migration.md              # 遇到旧路径引用时对照
```

## 已知坑
- **改版后旧路径引用一律先对照 `migration.md`**，包括本仓 2026-10-08 之前的记忆与 `07-deployment/k3s-bringup.md` 这类写法。
- **需求状态不能简读**：分「已实现 / 部分已实现 / 规划」，且代码实现、合入、镜像构建、部署、业务验收**分别记录**。"已实现（本地代码，未部署）"≠ 已上线；引用状态必须带日期与范围。
- `guides/k3s-reference.md` 是历史快照；当前部署跑在 cicd 共享集群（Helm release `zhiyuan`），读错会误导排查方向。
- 环境记录里的"当日只读核查"不等于实时状态；动手前按 `machines/RULES.md` 先只读核对。
- 文档仓是私有仓，但内网地址、密钥占位符仍按本仓公开面纪律处理：**不把完整 IP / 客户名 / 凭据复制到本仓**。

## 相关记忆与环境
- 项目记忆：`agent-memory/projects/zhiyuan-enterprise.md`
- 机器约束：`machines/AGENTS.md`、`machines/RULES.md`（远程机器操作前必读）
