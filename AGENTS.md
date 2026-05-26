# WHZ Harness Instructions

本仓库是 agent 工作脚手架，包含规则、模板和 skills。

## Test Log Convention

测试记录写到 `testlog/YYYY-MM/YYYY-MM-DD_HHMM_<task-slug>/`

按需包含：
- `report.md`: 测试目的、环境、参数、结果、结论。
- `run.sh`: 关键测试命令或复现脚本。
- `params.yaml`: 模型、硬件、服务参数、环境变量摘要。
- `results.json`: 结构化结果，只有需要机器读取时才创建。

## When To Update Summary

当测试产生阶段性结论时，更新 `testlog/summary.md`：
- 当前有效结论。
- 最佳参数组合。
- 已验证无效方案。
- 关键性能指标。
- 主要瓶颈。
- 下一步测试建议。

`summary.md` 不复制完整测试过程，只沉淀可复用结论。

## Do Not Record

- 密钥、token、完整 `.env`。
- 大日志、完整模型输出、截图、dump 文件。
- 无意义命令流水账。
- 可以直接从 Git diff 看出的代码细节。
- 与当前任务无关的背景信息。
