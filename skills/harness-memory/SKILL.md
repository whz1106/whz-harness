---
name: harness-memory
description: 读写 ~/whz-harness 这套记忆系统：查已有记忆、追加捕获、把结论提升到正式文件、提交推送、脱敏检查。当用户说「记住这件事」「更新记忆」，或需要确认既有偏好、项目结论、环境事实时使用。
---

# 记忆系统操作手册

**一个公开仓库** `~/whz-harness`，四层，全部通过 `scripts/sync.*` 注入用户级配置，所以**注入层的 `AGENTS.md` / `RULES.md` 内容你通常已经看到**，不必再读一遍。

| 层（marker block） | 目录 | 内容 | 注入 |
| --- | --- | --- | --- |
| `personal-memory` | 仓库根 | 规则、偏好、工具链、编码/提交习惯、通用坑 | ✅ |
| `agent-memory` | `agent-memory/` | 记忆系统：个人长文、项目记忆、捕获区 | ✅（长文按需读） |
| `env-memory` | `env/` | 业务环境信息与硬约束（kata/vfio/docker），高频更新 | ✅ |
| `local-memory` | `local/` | 本机私有：真实地址、受控路径（gitignore） | ✅ |

## 先判断去哪

| 内容 | 去哪 |
| --- | --- |
| 跨项目偏好、习惯、通用坑 | 根 `AGENTS.md`（或 `agent-memory/personal.md` 长文） |
| 必须每轮常驻的硬约束 | 根 `RULES.md` |
| 项目结论、强制流程、坑 | `agent-memory/projects/<项目>.md` |
| 机器事实、禁改项、故障信号 | `env/<机器>.md`（禁改项同时进 `env/RULES.md`） |
| 外部资料与脚本 | `materials/<name>/` + 登记 `materials/INDEX.md` |
| 还没想清的零散事实 | `agent-memory/notes/inbox.md` |
| 本机私有值（真实地址、受控路径） | `local/`（**绝不入库**） |

## 读取

```bash
git -C ~/whz-harness pull --ff-only
sed -n '1,120p' ~/whz-harness/agent-memory/AGENTS.md    # 记忆索引
sed -n '1,120p' ~/whz-harness/env/AGENTS.md             # 环境铁律 + 机器索引
ls ~/whz-harness/agent-memory/projects ~/whz-harness/materials
```

细节**故意不注入**，按索引路径按需读。查历史结论：`git -C ~/whz-harness log -p -- <路径>`。

## 写入

```bash
# 零散事实（只提交该层 inbox）
bash ~/whz-harness/scripts/capture.sh "事实"                    # → agent-memory 层
bash ~/whz-harness/scripts/capture.sh "某机器的坑" --layer env   # → env 层

# 正式文件：直接编辑后提交
git -C ~/whz-harness pull --ff-only
# 编辑 agent-memory/... 或 env/...
git -C ~/whz-harness add -A
git -C ~/whz-harness commit -m "memory: <摘要>"     # 环境用 env:，资料用 materials:
git -C ~/whz-harness push
bash ~/whz-harness/scripts/sync.sh                  # 改过注入层后必须跑（Windows: sync.ps1）
```

**提升规则**：inbox 里的条目稳定后整理进正式文件，然后删掉那行。写进 `personal.md` 前自问：*这条会不会影响我 3 个以上项目的决策？*

## 硬约束

- **完整 IP 一律不写**（只写网段）；客户名/单位名用机器代号；密钥/令牌一律不写，只记「在哪里取」；受控原件只记文件名 + 大小 + sha256。
- `capture.sh` 会拦内网地址与凭据特征（exit 3）；被拦下就脱敏，**不要绕过**。`scripts/scan-sensitive.sh` 可手工全库扫描（**故意跳过 `local/`**），pre-commit 钩子也会自动跑。
- 只记事实与已验证结论；推测标 `[推测]`，并写清时间与出处。
- 绝不 `push --force`、绝不重写已推送历史；冲突用普通 merge commit。
- 冲突无法自动解决时停下来说明，不要丢弃任何一侧的内容。
