# local/ —— 本地投放区（不进 git）

这个目录**刻意被 gitignore**（只保留本文件）。用途：clone 仓库之后，把**不该公开**的资料放到这里，agent 就能读到。

## 放什么

| 文件 | 内容 | 谁读它 |
| --- | --- | --- |
| `agc64f.local.md` | `$AGC64F_HOST` / `$AGC64F_BIND` 的真实值、ssh 别名、现场接入方式 | `env/64f.md` 里引用 |
| `artifacts.local.md` | 受控原件与大型数据的**真实路径**（甲方 PDF、部署包 zip、测试数据） | `materials/INDEX.md` 里引用 |
| 任意 `*.md` | 其它不想公开的现场记录 | 按文件名被引用 |

## 怎么生效

`scripts/sync.*` 会把这个目录当成第三层（`local-memory`）注入到用户级配置，和 `personal-memory`、`work-memory` 并列。约定：

- 目录里放 `AGENTS.md` → 它的内容会被注入（这是主要入口）；
- 只放 `*.local.md` 碎片也可以：在 `AGENTS.md` 里用 `@agc64f.local.md` 之类相对导入把它们带进来，或者直接在 `AGENTS.md` 里写明「真实值见 `local/agc64f.local.md`」，让 agent 需要时自己读。

## 别做的事

- **不要把这里的文件 `git add -f`**：这是本仓库唯一挡在公开面上的东西。
- 不要改 `.gitignore` 里 `local/` 那两行。
- 扫描器（`scripts/scan-sensitive.sh`）**故意跳过这个目录**，它拦的是"不该出现在公开面的内容"，不是这里的正常内容。

## 换机器

新机器 clone 之后：

```bash
mkdir -p ~/whz-harness/local
# 把本机那份 local/ 内容拷/同步进来（U 盘、内网、或你自己的加密通道）
bash ~/whz-harness/scripts/sync.sh
```
