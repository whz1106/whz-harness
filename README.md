# whz-harness

`whz-harness` 是给 agent 使用的轻量开发/测试工作脚手架。

上传到仓库的是规则、模板和 skills，不上传实际项目日志、测试结果或大文件。

## 包含内容

- `AGENTS.md`: 各 agent 的工作规则。
- `CLAUDE.md`: Claude Code 的工作规则。
- `templates/`: 可复制到项目中的记录模板。
- `skills/`: 可复用 agent skills。

## 不包含内容

- 真实项目的 `testlog/` 内容。
- 真实项目的 `specs/` 内容。
- benchmark 原始输出、大日志、截图、dump、trace。
- `.env`、token、密钥、私有配置。

## 日志仓库

本仓库不包含日志数据。日志存储在独立的 [daily-work-journal](https://github.com/whz1106/daily-work-journal) 仓库中。
