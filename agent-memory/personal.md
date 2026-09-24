# 个人记忆长文

> 根 `AGENTS.md` 是注入的精简版；这里是细节与历史。**不注入**，按需读。

## 工作方式

- **先证据后结论**：改完跑真实路径，把输出贴出来。不接受「应该能行」「理论上」。
- **一次一件事**：不要把「顺手」的额外改动混进当前任务；要顺手就先问。
- **复现优先**：报 bug 先复现，修完再确认复现路径不再触发。
- **交付要能验收**：说清改了什么、怎么验、还有什么没做。
- **破坏性操作先确认**：`push --force`、删数据、改全局配置、动别人的目录。

## 交流偏好

- 中文交流；代码、标识符、命令、日志用英文原样。
- 回答短、可执行、结论先行；不要营销式措辞和过程叙述。
- 不确定就说不确定，并给出判断依据；不要为了显得可靠而含糊。

## 工具链细节

### omp（Oh My Pi）

- agent 目录 `~/.omp/agent`；`PI_CODING_AGENT_DIR` 可重定位；`--profile <name>` 用 `~/.omp/profiles/<name>/agent`。
- 记忆后端默认 `off`。`local` 后端按 cwd 绝对路径给记忆分目录（Windows/macOS 编出的目录名不同），**不能跨机器共享** → 跨机器共享用本仓库。
- `local` 后端只处理「≥12h 空闲、≤30 天、且被持久化」的会话；子代理不跑记忆管线。
- `/memory view` 在无可注入载荷时提示 `Memory payload is empty …` —— 那是提示不是报错。
- `--config <file>` 可以叠一层临时配置做实验，不动全局设置（试记忆后端时用过）。

### 其它 agent

- Claude Code：用户级 `~/.claude/CLAUDE.md`；支持 `@path` 导入。
- Codex CLI：用户级 `~/.codex/AGENTS.md`（不支持导入，所以本仓库给它注入合并全文）。
- Gemini CLI：用户级 `~/.gemini/GEMINI.md`。
- Copilot / VS Code：`~/.copilot/copilot-instructions.md`。

### git / gh

- `gh` 已登录 `whz1106`（scope：repo、workflow、gist、read:org）。
- 全局有 `pull.rebase = true` → 脚本里一律显式 `-c pull.rebase=false pull --ff-only`，否则自动化 pull 会撞 rebase。
- git identity：`whz <hzwang991106@gmail.com>`。

## 踩过的坑（跨项目）

| 坑 | 结论 |
| --- | --- |
| 批量文本替换叠 `sed` | 行尾反斜杠（shell 续行符）被误伤成 `$`，一次损坏 12 个文件 297 行。改完**必须与原文件 diff**；能用单条 `sed` 就不要叠 |
| PowerShell 5.1 读 `.ps1` | 文件必须是 **UTF-8 with BOM**，否则按 GBK 解码，中文注释把脚本解析坏 |
| PS 5.1 里原生命令重定向 stderr | `2>&1` 会把 stderr 变成 ErrorRecord，配合 `$ErrorActionPreference='Stop'` 直接终止脚本。原生命令不要重定向，用 `$LASTEXITCODE` 判断 |
| Windows 上 `$HOME` | Git Bash/MSYS 常把它留空或指到别处 → 脚本先回退 `USERPROFILE`，都不可用就报错退出，不要往 `/.omp` 写 |
| Git Bash 里的 `bash -c` | 那是 WSL 的 Linux bash，文件系统视图不同（`/c/...` 不存在，要用 `/mnt/c/...`） |
| 内网 GitLab snippet 抓取 | 本机有 `http_proxy`，内网地址要 `curl --noproxy '*'` |
| omp `local` 记忆后端 | 跑一次会真的调用模型做抽取/合并，并往 `~/.omp/agent/memories/` 落盘；试完记得清 |
