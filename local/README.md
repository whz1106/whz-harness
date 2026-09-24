# local/ —— 本地投放区（不进 git）

这个目录**刻意被 gitignore**（只保留本文件）。用途：clone 仓库之后，把**不该公开**的东西放到这里，agent 就能读到。

## 放什么

| 放什么 | 例子 | 谁读它 |
| --- | --- | --- |
| 真实值 | `agc64f.local.md`：真实地址、ssh 别名、现场接入方式 | `machines/agc64f.md` 里引用 |
| 受控参考资料 | 客户给的 PDF、截图、脚本、数据索引、临时笔记 | 按文件名被引用，或在本目录 `AGENTS.md` 里列一行 |
| 大文件的真实路径 | `artifacts.local.md`：部署包 zip、测试数据在哪 | `materials/INDEX.md` 里引用 |

**规则：完整 IP 也不写在这里。** 只写网段（`172.18.5.***`），真值留在 `~/.ssh/config` 或你的密码管理器里 —— 这个目录只是"不进 git"，不等于"可以随便写"。

## 怎么让 agent 看到

`scripts/sync.*` 把本目录当作 `local-memory` 层注入到用户级配置：

- `local/AGENTS.md` → 注入（**这是入口**，在里面列出本机放了什么）；
- 其它 `*.md` → 不自动注入，由 `AGENTS.md` 用相对导入 `@agc64f.local.md` 带进来，或写明路径让 agent 需要时自己读。

所以加完东西记得在 `local/AGENTS.md` 里补一行。

## 换机器

新机器 clone 之后：

```bash
mkdir -p ~/whz-harness/local
# 把本机那份 local/ 内容拷/同步进来（U 盘、内网、或你自己的加密通道）
bash ~/whz-harness/scripts/sync.sh
```

## 别做的事

- **不要把这里的文件 `git add -f`**：这是本仓库唯一挡在公开面上的东西。
- 不要改 `.gitignore` 里 `local/*` 那两行。
- 扫描器（`scripts/scan-sensitive.sh`）**故意跳过这个目录** —— 它拦的是"不该出现在公开面的内容"，不是这里的正常内容。
