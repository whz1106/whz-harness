---
name: agent-bootstrap
description: 新起一个 agent / 新接一个项目或机器时，用 ~/whz-harness 生成一份本地 AGENTS.md：抄进该环境的硬约束、挂上记忆与资料的指针、装好注入。当用户说「新建一个 agent」「给这个项目/机器建规则」「初始化工作环境」，或在一个还没有 AGENTS.md 的目录里开始干活时使用。
---

# 新 agent / 新环境引导

目标：**让一个没有任何上下文的 agent，在一个新目录里开工之前，先拿到"规则 + 该环境的硬约束 + 去哪找细节"。**

## 流程

### 1. 摸清这个环境是什么

- 当前目录是什么项目？仓库根在哪？是不是客户现场机器？
- 有没有既有约定文件：`AGENTS.md` / `CLAUDE.md` / `.omp/AGENTS.md` / `README.md`。
- 若是远程机器：**先读 `~/whz-harness/machines/AGENTS.md`**，判断它在不在 `machines/` 索引里。

### 2. 生成 `AGENTS.md`

以 `~/whz-harness/templates/AGENTS.md` 为骨架（远程机器用 `templates/machine.md` 补一份 `machines/<机器>.md`），逐节填实，**不许留占位符**：

- 第二节「怎么跑」写最短路径，超过 10 行就拆到 `docs/` 并在原地给指针。
- 第三节「硬约束」是必填项：
  - 若该环境属于 `machines/` 里登记的机器 → 把 `machines/RULES.md` 的禁改项抄进来（vfio/kata/reboot/全局 pkill），并写明"必须经我明确同意"。
  - 任何环境都要写：不写完整 IP / 客户名 / 密钥；真实值放 `local/` 或 `~/.ssh/config`。
- 第五节「去哪看细节」保留指向本仓库 `machines/`、`agent-memory/`、`materials/`、`local/` 的表；若仓库未克隆到 `~/whz-harness`，改成当前机器的实际路径。
- 项目有 `.agent/skills/` 时，在「项目技能」表逐项写具体触发场景和 `SKILL.md` 路径；项目没有专用技能时删掉占位表。不同 agent 均按这张表读取技能，不假设 `.agent/` 会被原生扫描。

### 3. 挂上记忆与资料

- 这个项目/机器在 `agent-memory/projects/` 或 `machines/` 里已有文件 → 在生成的 `AGENTS.md` 里直接引用路径；没有 → 建一个骨架文件（项目名、一句话用途、待补），并在 `agent-memory/AGENTS.md` 或 `machines/AGENTS.md` 的索引里加一行。
- 有外部资料/脚本 → 按 skill `materials-intake` 放进 `materials/`，登记 `materials/INDEX.md`。

### 4. 装注入（同一台机器上只做一次）

```bash
cd ~/whz-harness && git config core.hooksPath .githooks     # 若还没装
bash scripts/sync.sh                                          # Windows: powershell -File $HOME\whz-harness\scripts\sync.ps1
```

跑完确认目标文件里每层都有块：

```bash
grep -c 'BEGIN .*-memory' ~/.omp/agent/AGENTS.md    # 期望 4
```

### 5. 交付

向用户报告三件事：生成了哪些文件、抄进去了哪些硬约束、还缺什么（例如 `local/` 里的真实地址还没放）。

## 注意

- **不要**把项目级规则写进 `~/whz-harness` 的公开面：项目规则跟项目走（放项目仓库的 `AGENTS.md`），公开面只放跨项目结论 + 指针。
- **不要**在生成的 `AGENTS.md` 里写完整 IP、客户名、密钥。
- 新环境涉及远程机器时，动手前走一遍 skill `machine-ops-guard`。
