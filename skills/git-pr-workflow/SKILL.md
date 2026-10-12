---
name: git-pr-workflow
description: Prepare commits and PR/MR content, inspect CI failures, manage branches, and backport fixes while preserving local changes and published history. Follow the target repository's language, branch, and validation rules.
---

# Git PR Workflow

## Overview

Use this skill to run a safe Git workflow for feature delivery, bugfix delivery, release backports, and CI triage.

Prefer narrow, explicit operations over broad staging or history edits. Read the target repository's current AGENTS.md first. Its language and branch rules take precedence over this skill's defaults; ZhiYuan and Xiaoruan desktop repositories require English Conventional Commits. Preserve local work and never rewrite published history.

## Typical Requests

Use this skill for requests such as:

- `帮我整理这次提交，写中文 commit message`
- `帮我检查暂存区，只提交这次功能相关文件`
- `准备这个分支的 PR，目标分支是 dev`
- `这个 bug 要回补到 release/1.0，帮我走 cherry-pick 流程`
- `看看这个 CI 为什么失败，如果是代码问题给出解决方案`
- `我准备提 MR，先帮我检查是不是已经 rebase 到远端目标分支`

When the request is ambiguous, first identify:

- current branch
- target branch
- whether local changes exist
- whether the user wants diagnosis only or diagnosis plus implementation

## Required Rules

Always enforce these rules:

- Run `git status --short` before branch switch, rebase, cherry-pick, commit, reset, or clean.
- Inspect divergence from the actual target branch before PR or MR submission. Update a published branch with an ordinary merge commit when needed; rebase only unpublished commits when repository rules permit it.
- Use `feat/<name>` for new features and `fix/<name>` for bugfixes unless the repository already defines a stricter convention.
- Follow the target repository's commit and PR language rules; use Chinese only when no stricter rule exists.
- Never use force push, including `--force-with-lease`, or bypass verification hooks.
- Preserve staged, unstaged, and untracked user changes unless the user explicitly approves a destructive action.
- When CI failure blocks merge or release and is tied to logic, provide a concrete cause and a concrete fix plan.

## Safety Gate

Run `git status --short` before any action that may change branch state or commit history, especially before:

- `git checkout`, `git switch`
- `git rebase`
- `git cherry-pick`
- `git commit`
- `git reset`
- `git clean`

If the working tree is not clean:

1. Tell the user exactly which files are modified, staged, or untracked.
2. Tell the user the next Git operation may be blocked by those changes.
3. Do not discard, overwrite, unstage, stash, or auto-resolve those changes on the user's behalf.
4. Tell the user how they can handle the changes, for example:
   - commit the current work first
   - stage only part of the files
   - stash the changes themselves if they want to suspend the work
   - explicitly approve restoring selected files if they really want to discard changes
5. Stop before any destructive action until the user decides.

Do not use `git add .` or `git add -A`. Stage only the intended files with explicit paths or `git add -p`. A dirty worktree does not block read-only review or committing already authorized, isolated changes; stop only when the next operation risks unrelated work.

## Branch Naming

Use consistent prefixes:

- New feature: `feat/<name>`
- Bugfix on dev or other active branch: `fix/<name>`
- Release backport fix: `fix/<bug>-release-<version>`

Keep names short, specific, and searchable. Use English branch slugs unless the repository already uses a different convention consistently.

## Commit And PR Language Rules

Read the target repository's language requirements. For ZhiYuan and Xiaoruan desktop commits, use English type/scope/subject/body/footer, a lowercase imperative subject of at most 72 characters, and no trailing period. For harness memories, retain its `memory:` / `env:` / `materials:` / `capture:` conventions.

When the repository permits Chinese, use Conventional Commit type prefixes in English with Chinese subject text:

- `feat: 新增用户导出能力`
- `fix: 修复登录超时后无法自动刷新`
- `refactor: 重构任务分发逻辑`
- `test: 补充订单重试场景测试`
- `docs: 更新发布说明`

Keep the first line focused on user-visible intent or code intent. Add a body in the required language only when it clarifies scope, risk, migration, or cherry-pick value.

For reusable formatting examples, read [references/commit-pr-format.md](references/commit-pr-format.md).

## Published History Rule

Before opening a PR or MR, inspect the corresponding remote target branch, not an assumed `origin/dev`. Read the upstream and ahead/behind state and determine which commits are already published. Fetch remote refs when authorized by the Git task.

For a published feature or release branch that needs the target branch's changes, use an ordinary merge after confirming the working tree can accommodate it:

```bash
git merge origin/<target-branch>
git push origin <branch>
```

Rebase is optional only for unpublished commits and only when repository rules permit it. A rejected ordinary push requires inspecting remote divergence; never retry with force. Resolve conflicts only within the task's file ownership, otherwise stop and report.

## Feature Development Workflow

When the user asks to start a new feature from `dev`, use this sequence unless repository-specific rules override it:

```bash
git fetch origin
git checkout -b feat/<name> origin/dev
```

During development:

1. Inspect `git status --short`.
2. Stage only intended changes.
3. Write a commit message in the repository's required language.
4. Inspect divergence from the actual target branch and apply the published-history rule.
5. Push ordinarily when publishing is authorized.

## Bugfix Workflow

For ordinary bugfixes not tied to a release backport:

```bash
git fetch origin
git checkout -b fix/<name> origin/dev
```

Then follow the same rules as feature development: precise staging, repository-specific commit language, target-branch inspection, and ordinary push without rewriting published history.

## Release Backport Workflow

When the user needs to backport a bugfix from `dev` to a release branch:

1. Fetch remote refs.
2. Inspect `origin/dev` history and identify the exact bugfix commit.
3. Create a release fix branch from the target release branch.
4. Cherry-pick only the required commit or commit set.
5. Resolve conflicts carefully and continue.
6. Inspect divergence from the target release branch; merge new target changes when needed without rewriting published commits.
7. Push the release fix branch.

Reference sequence:

```bash
git fetch origin
git log --oneline origin/dev
git checkout -b fix/<bug>-release-<version> origin/release/<version>
git cherry-pick <commit>
```

If conflicts occur:

1. Run `git status`.
2. Resolve only the intended files.
3. Stage resolved files explicitly.
4. Continue with:

```bash
git cherry-pick --continue
```

Then push:

```bash
git push origin fix/<bug>-release-<version>
```

Prefer small, isolated bugfix commits on `dev` so they can be cherry-picked cleanly onto release branches.

## PR Or MR Preparation

Before drafting PR content:

1. Check the diff and commit list against the target branch.
2. Summarize only the actual change in scope.
3. Call out risk, verification, and whether a release cherry-pick is required.
4. State the exact target branch.
5. State the target-branch divergence and any merge or unpublished rebase performed.

Use the repository's PR language requirements. Keep titles and descriptions concrete and include:

- What changed
- Why it changed
- How it was verified
- What risks or rollback notes exist
- Whether cherry-pick is required
- What the target branch is

Do not claim tests passed if they were not run. Do not hide known risks.

## Pre-Submission Checklist

Before commit, PR, or MR submission, verify:

- `git status --short` has been checked
- only intended files are staged
- no unrelated debug code, temporary files, or accidental formatting noise is included
- commit message follows repository language and formatting rules and matches the actual scope
- target branch is confirmed
- target-branch divergence has been checked and published history is preserved
- required tests or checks have been run, or the lack of verification is explicitly stated
- if the change may need release backport, the commit is small enough to cherry-pick cleanly

Before final submission, report any unresolved risk, skipped validation, or follow-up work explicitly in the PR or MR description.

## CI Failure Triage

When the user asks to inspect a failed CI job:

1. Read the failing job, failing step, and exact error.
2. Classify the failure:
   - CI configuration or environment issue
   - Dependency or network issue
   - Test flake
   - Code logic or build logic issue
3. Report the likely cause with evidence.

If the failure involves code logic, build logic, or test logic, provide:

- Root-cause hypothesis
- Concrete fix direction
- Impact scope
- Validation plan

If the failure is severe enough to block merge or release, also provide:

- Whether the issue is reproducible locally or likely environment-specific
- Whether the failure should block the PR immediately
- The recommended priority and next action

Use a concise report structure. For a reusable template, read [references/commit-pr-format.md](references/commit-pr-format.md).

Preferred analysis flow:

1. identify the first real failing step rather than later cascading failures
2. separate symptom from root cause
3. state whether the issue is code, test, build, dependency, or CI environment
4. explain the smallest safe fix
5. state how to verify the fix

Do not silently modify code unless the user asked for a fix. Diagnosis and implementation are separate unless the user combines them.

## Communication Rules

Be explicit when reporting Git state:

- Current branch
- Target branch
- Whether the working tree is dirty
- Whether an unpublished rebase or a cherry-pick was performed
- Whether an ordinary push is possible or remote divergence still needs resolution

If a command could discard or overwrite user work, stop and get approval first.
