# materials —— 外部依赖资料

> 这里放**外部来的**东西：项目资料、部署包、脚本、手册。
> 目的：clone 之后 AI 能**快速构建上下文并直接干活**，而不是每次重新翻压缩包。

## 一个 material 的标准结构

```
materials/<name>/
├── README.md       ← 必填，入口。AI 只读这个就能决定要不要深入
├── docs/           文档（手册、SOP、手册文本）
├── scripts/        可执行脚本
└── artifacts/      二进制/大文件（一般不入库，只留指针到 materials/INDEX.md）
```

`README.md` 必须按这个骨架写（skill `materials-intake` 会检查）：

```markdown
# <name>
## 是什么 / 从哪来
## 前置条件（跑之前必须满足什么）
## 怎么用（最短路径的命令）
## 已知坑（现象 → 原因 → 处置）
## 相关记忆与环境
- 项目记忆：agent-memory/projects/<x>.md
- 机器约束：env/<机器>.md、env/RULES.md
```

**为什么要这个骨架**：AI 读完 README 就知道"能不能跑、要什么前置、坑在哪"，不用把整个 `docs/` 读进来。索引不清晰的材料等于没放。

## 放置规则

| 情况 | 怎么做 |
| --- | --- |
| 纯文本资料（md / conf / sh / py） | 直接放进 `materials/<name>/`，并在 `materials/INDEX.md` 登记 |
| 二进制、受控 PDF、zip、> 5 MB 的数据 | **本体不入库**：放本机/服务器/NAS，在 `materials/INDEX.md` 记文件名 + 大小 + sha256，真实路径写 `local/` |
| 客户名/内网地址出现在文本里 | 入库前脱敏：地址换网段或 `$占位符`，客户名换机器代号 |
| 只在一台机器上要用的 | 放 `local/`，不进 `materials/` |

新增一个 material 的流程（也可以直接交给 skill）：

```bash
bash scripts/capture.sh "materials/<name>：<一句话用途>" --layer agent-memory
# 然后按上面的骨架补 README.md，并在 materials/INDEX.md 加一行
bash scripts/scan-sensitive.sh        # 提交前扫一遍
```

## 现有材料

见 `INDEX.md`。

## 相关

- 登记表：`INDEX.md`
- 放材料的流程：skill `materials-intake`
- 机器约束（跑脚本前必读）：`env/AGENTS.md`
