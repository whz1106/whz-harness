---
name: materials-intake
description: 把外部资料（部署包、项目文档、脚本、手册）收进 ~/whz-harness/materials/ 并做适配：脱敏、登记哈希、写标准 README、挂上记忆与机器约束的指针。当用户丢来一个压缩包/目录/一批脚本说「放进去」「以后要用」「让 agent 能直接读」时使用。
---

# 外部资料收编

**判断标准：放进来之后，一个没有上下文的 agent 读完 `README.md` 就知道"能不能跑、要什么前置、坑在哪"。做不到就等于没放。**

## 一、先分流

| 情况 | 去哪 |
| --- | --- |
| 纯文本（md / conf / sh / py / json） | `materials/<name>/`，入库 |
| 二进制 / 受控 PDF / zip / > 5 MB 数据 | **不入库**：本体留在原处，只登记到 `materials/INDEX.md` |
| 客户名、完整 IP 出现在文本里 | 入库前脱敏（见第三节） |
| 只在一台机器上用 | `local/`，不进 `materials/` |

## 二、落盘

```bash
mkdir -p ~/whz-harness/materials/<name>/{docs,scripts}
# 拷贝文本资料；排除 __MACOSX、.DS_Store、*.log、*.pdf、*.zip
```

`<name>` 用「机器/项目代号-用途」：`agc64f-llm-deploy`、`four-test-benchmark`。

每个 material 必须有 `README.md`，骨架见 `materials/README.md`：

```
# <name>
## 是什么 / 从哪来
## 前置条件
## 怎么用（最短路径）
## 已知坑（现象 → 原因 → 处置）
## 相关记忆与环境（指针）
```

`docs/` 里保留原始文档（手册、SOP、基线）。**大文档不复制进 README**，只给指针 —— 否则每次都要烧 token。

## 三、脱敏（入库前必做）

1. 扫一遍：

   ```bash
   grep -rnE '([0-9]{1,3}\.){3}[0-9]{1,3}' materials/<name> | grep -vE '127\.0\.0\.1|0\.0\.0\.0'
   ```

2. 完整 IP → 换成占位符（`$AGC64F_HOST`）或网段（`172.18.5.***`）；真实值写 `local/<机器>.local.md`。
3. 客户名/单位名 → 机器代号。
4. 凭据一律删除，只留「在哪里取」。
5. **改完必须与原文件 diff**：只应看到被脱敏的那几行变化。批量替换不要叠 `sed`，行尾反斜杠会被误伤。

## 四、登记与挂接

1. `materials/INDEX.md` 加一行：material 名 / 路径 / 是什么 / 规模；未入库的补文件名 + 大小 + sha256。
2. 在该 material 的 `README.md` 里挂指针：相关 `agent-memory/projects/<项目>.md`、`machines/<机器>.md`、`machines/RULES.md`。
3. 如果资料对应一个已有项目记忆，在项目记忆里反向加一行指向 `materials/<name>/README.md`。
4. 收尾：

   ```bash
   bash ~/whz-harness/scripts/scan-sensitive.sh
   bash ~/whz-harness/scripts/capture.sh "materials/<name>：<一句话用途>" --tag materials
   ```

## 五、让 AI 真的用得上

- README 的「怎么用」要**可复制执行**，含 `cd` 与完整命令。
- 脚本涉及远程机器时，README 里写明"动手前先读 `machines/RULES.md`"，并在「已知坑」里写清故障信号。
- 资料里已有结论的，提炼一句进 `agent-memory/projects/<项目>.md`，别让 agent 每次去翻 500 行手册。
