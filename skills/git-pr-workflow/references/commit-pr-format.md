## Commit Message Patterns

Prefer `类型: 中文摘要`:

- `feat: 新增批量导出功能`
- `fix: 修复支付回调重复入账问题`
- `refactor: 拆分任务调度与重试逻辑`
- `test: 补充用户冻结场景回归测试`
- `docs: 更新发布流程说明`

Optional body template:

```text
变更内容：
- ...

原因：
- ...

风险与影响：
- ...
```

Use a body when the change is non-trivial, risky, or intended for later cherry-pick.

## PR Title Pattern

Prefer a short Chinese summary:

- `新增批量导出功能`
- `修复支付回调重复入账问题`
- `回补 release/1.0 的登录超时修复`

## PR Description Template

```md
## 变更内容
- ...

## 变更原因
- ...

## 验证方式
- ...

## 风险与影响
- ...

## 备注
- 是否需要 cherry-pick：是/否
- 目标分支：...
- 是否已 rebase 目标远端分支：是/否
- 回滚方式：...
```

## Pre-Submission Report Template

```md
## 提交前检查
- 当前分支：...
- 目标分支：...
- 是否已检查工作区状态：是/否
- 是否仅暂存目标文件：是/否
- 是否已 rebase 目标远端分支：是/否
- 是否已完成验证：是/否

## 未完成项 / 风险
- ...
```

## CI Failure Report Template

```md
## 失败位置
- Job: ...
- Step: ...

## 失败现象
- ...

## 原因判断
- ...

## 问题分类
- 代码逻辑 / 测试逻辑 / 构建逻辑 / 依赖问题 / CI 环境问题

## 最小修复方案
- ...

## 建议方案
- ...

## 验证建议
- ...

## 是否阻塞合并 / 发布
- ...

## 建议优先级
- ...
```
