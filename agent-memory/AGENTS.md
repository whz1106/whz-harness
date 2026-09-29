# agent-memory —— 记忆系统

> 这一层回答一个问题：**我（用户）是怎么干活的、踩过什么坑、手上这些项目什么状况。**
> 注入为 `agent-memory` 层；但这里的长文**不注入**，由 `AGENTS.md` 的导航按需 read。
> 以下路径以 whz-harness 仓库根目录为基准。

## 结构

```
agent-memory/
├── AGENTS.md        本文件：索引 + 写入规则            ← 注入
├── personal.md      个人记忆长文：偏好、工作方式、工具链细节、通用坑
├── projects/        项目记忆（每个项目一个文件）
│   ├── agc64f-llm-deploy.md    64F 大模型多实例部署
│   ├── four-test-v1.md         独立项目仓库的导航指针
│   └── zhiyuan-enterprise.md     知远企业版（Zhiyuan Enterprise）（AEP/AaaS/k3s 全栈）
└── notes/inbox.md   捕获区（追加式）
```

## 什么时候读哪个

| 场景 | 读 |
| --- | --- |
| 想知道我的偏好/习惯/工具链 | `agent-memory/personal.md` |
| 要动某个项目 | 当前项目自己的 `AGENTS.md`；有跨项目结论时再读 `agent-memory/projects/<项目>.md` |
| 要动某台机器 | `machines/AGENTS.md` → `machines/<机器>.md`（**环境约束优先于项目记忆**） |
| 要外部资料/脚本 | `materials/INDEX.md` |

## 写入规则（防膨胀）

1. **入口只有一个**：新事实先落 `agent-memory/notes/inbox.md` 一行，格式 `- <UTC 时间> [<主机>] <事实>`。
2. **提升**：稳定后把它整理进 `agent-memory/personal.md` 或 `agent-memory/projects/<项目>.md`，然后**删掉 inbox 里那一行**。
3. **准入门槛**（写进 `personal.md` 前自问）：
   - 会不会影响我 3 个以上项目的决策？否 → 放项目文件或不写。
   - 是不是「可复用的偏好/结论/坑」？否（一次性上下文、日志、能直接看 git diff 的东西）→ 不写。
4. **每条带时间与出处**；不确定的标 `[推测]`。
5. **一个主题一个文件**；新增项目文件后在 `agent-memory/AGENTS.md` 的索引里加一行（就在下面）。
6. 项目级规则**跟项目走**：项目自己的 `AGENTS.md` 放项目仓库里，这里只放「跨项目也要知道的结论 + 指向」。

## 索引

| 主题 | 文件 | 一句话 |
| --- | --- | --- |
| 个人偏好与工作方式 | `agent-memory/personal.md` | 交付要可验证、回答要短、破坏性操作先确认 |
| 项目：64F 大模型多实例部署 | `agent-memory/projects/agc64f-llm-deploy.md` | 三个模型三选一，Docker+Kata 混合，nginx :8000 聚合 |
| 项目：four-test v1 多模态压测 | `agent-memory/projects/four-test-v1.md` | 仅指向独立项目仓库；细节以该仓当前 `AGENTS.md` 为准 |
| 项目：知远企业版（Zhiyuan Enterprise） | `agent-memory/projects/zhiyuan-enterprise.md` | AEP + 知远企业扩展，k3s 全栈部署（runbook 在 zhiyuan-docs） |
| 环境（机器与硬约束） | `machines/AGENTS.md` | kata/vfio/docker 的禁改项，动手前必读 |
| 外部资料 | `materials/INDEX.md` | 部署包、脚本、受控原件指针 |
| 怎么用这套记忆 | skill `harness-memory` | 读写流程与命令 |
