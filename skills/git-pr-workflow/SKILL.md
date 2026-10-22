---
name: git-pr-workflow
description: Act as the PR/MR manager for GitHub and GitLab — claim a PR, write its problem and acceptance criteria into .docs/pr-<N>-<slug>.md, verify acceptance, merge, close the linked issues, and clean up branches and worktrees while preserving local changes and published history. Follow the target repository's language, branch, and validation rules.
---

# Git PR Workflow

## Overview

Use this skill as a **PR/MR manager**, not only a commit helper. The job covers the whole lifecycle:

1. claim the PR/MR and record its problem statement, scope, and acceptance criteria in the repository's `.docs/` directory
2. keep the branch reviewable (commit hygiene, target-branch divergence, CI triage)
3. run the acceptance checks before merging and keep the evidence
4. merge with the repository's merge method, then close out GitHub issues / GitLab issues
5. clean up source branches, worktrees, and local refs

GitHub PR and GitLab MR are the same role in this skill. Where they differ, use the parity table in [GitHub And GitLab Parity](#github-and-gitlab-parity).

Prefer narrow, explicit operations over broad staging or history edits. Read the target repository's current AGENTS.md first. Its language and branch rules take precedence over this skill's defaults; ZhiYuan and Xiaoruan desktop repositories require English Conventional Commits. Preserve local work and never rewrite published history.

## Typical Requests

Use this skill for requests such as:

- `帮我整理这次提交，写中文 commit message`
- `帮我检查暂存区，只提交这次功能相关文件`
- `准备这个分支的 PR，目标分支是 dev`
- `这个 bug 要回补到 release/1.0，帮我走 cherry-pick 流程`
- `看看这个 CI 为什么失败，如果是代码问题给出解决方案`
- `我准备提 MR，先帮我检查是不是已经 rebase 到远端目标分支`
- `领取 #12 这个 PR，把问题和验收标准写到 .docs 里`
- `这个 PR 验收通过了就合并，把关联 issue 关掉`
- `合并完把源分支和 worktree 清理掉`

When the request is ambiguous, first identify:

- platform and repository (GitHub or GitLab, which remote)
- current branch
- target branch
- whether local changes exist
- whether the user wants diagnosis only, or diagnosis plus implementation
- whether the user is claiming a PR, submitting one, or merging one

## Required Rules

Always enforce these rules:

- Run `git status --short` before branch switch, rebase, cherry-pick, commit, reset, or clean.
- Inspect divergence from the actual target branch before PR or MR submission. Update a published branch with an ordinary merge commit when needed; rebase only unpublished commits when repository rules permit it.
- Use `feat/<name>` for new features and `fix/<name>` for bugfixes unless the repository already defines a stricter convention.
- Follow the target repository's commit and PR language rules; use Chinese only when no stricter rule exists.
- Never use force push, including `--force-with-lease`, or bypass verification hooks.
- Preserve staged, unstaged, and untracked user changes unless the user explicitly approves a destructive action.
- When CI failure blocks merge or release and is tied to logic, provide a concrete cause and a concrete fix plan.
- Every PR/MR this skill manages has a tracking document under `.docs/` before merge. No tracking document, no merge unless the user explicitly waives it.
- The tracking document carries the original text verbatim: the issue or GitLab work item title, body, labels, author, and URL are pasted as-is into `## 原文`. Summaries and analysis go in their own sections; never replace the source text with a paraphrase.
- Never report an acceptance criterion as passed without the command, output, or evidence that proves it.
- A merged PR/MR is not closed work: the linked issue, its status label, the source branch, and the worktree must be closed out before reporting completion.

## Safety Gate

Run `git status --short` before any action that may change branch state or commit history, especially before:

- `git checkout`, `git switch`
- `git rebase`
- `git cherry-pick`
- `git commit`
- `git reset`
- `git clean`
- `git worktree remove`, `git branch -D`

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

Before `git worktree remove`, check the worktree for uncommitted or untracked files with `git -C <worktree> status --short` and preserve anything the user still needs (copy tracking documents such as `.docs/*.md` into the main checkout) before deletion.

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

## Claiming A PR Or MR

Claiming means taking ownership of review, acceptance, and merge for an existing PR/MR. Do it when the user says `领取`, `认领`, `接手`, `claim`, or assigns a PR/MR number.

Steps:

1. Read the PR/MR: title, description, source and target branch, commits, diff, current CI state, linked issues, and review comments.
2. Confirm the platform and repository (`gh repo view` / `glab repo view` or the remote URL) — do not assume `origin`.
3. Create the tracking document at `.docs/pr-<number>-<slug>.md` in the repository checkout (use the PR/MR number; `<slug>` is a short kebab-case version of the title). Reuse an existing document for the same number instead of creating a second one.
4. Fetch the source text before writing anything: the PR/MR description plus every linked issue or GitLab work item. Use the API so the body is complete and exact (`gh issue view <N> --json title,body,labels,author,url`, `glab api projects/:id/issues/<iid>`, `glab api projects/:id/merge_requests/<iid>`); for GitLab work items use the issue endpoint, which returns the work item description.
5. Open the document with an `## 原文` section and paste the original title, body, labels, author, and URL verbatim — Markdown preserved, nothing trimmed, no rewritten wording. When both an issue and a PR/MR exist, paste each with its own source heading.
6. Fill the rest from the template below: the problem in your own analysis, the scope it does and does not cover, and the acceptance criteria that must be true before merge.
7. Link the document from the PR/MR (description or a comment) so reviewers see the criteria that will be enforced.
8. Report the claim, the document path, and any blocking gaps (no acceptance criteria derivable from the PR, missing linked issue, broken CI, target branch mismatch).

The tracking document is a durable artifact: do not delete it after merge. It is the local record of what was agreed.

### Tracking Document Template

```markdown
# PR #<number> — <title>

- 平台 / 仓库：GitHub `owner/repo` / GitLab `group/project`
- 链接：<PR/MR URL>
- 分支：`<source>` → `<target>`
- 关联 issue：<#N 列表，或「无」>
- 领取人 / 领取时间：<user> / <YYYY-MM-DD>

## 原文

> 逐字粘贴，不改写、不概括、不省略；每个来源单独一节。正文里的 Markdown 结构保持原样。

### 来源：issue #<N> — <原标题>

- 作者 / 标签 / 时间：<author> / <labels> / <YYYY-MM-DD>
- 链接：<URL>

<原 body 全文>

### 来源：PR/MR !<N> — <原标题>

- 作者 / 标签 / 时间：<author> / <labels> / <YYYY-MM-DD>
- 链接：<URL>

<原 body 全文>

## 背景与问题

<基于原文的分析，区分事实与推测；不要把原文再概述一遍。>

## 范围

- 包含：<改了什么，按模块列>
- 不包含：<明确排除的内容、后续 issue>

## 验收标准

- [ ] AC-1 <可独立判定的描述>（证据：<命令/用例/接口返回>）
- [ ] AC-2 <...>
- [ ] AC-3 <...>

验收标准必须可判定：能给出命令、测试名、接口响应或界面操作路径；不写「体验良好」这类无法验证的条目。

## 验证记录

| 时间 | 检查项 | 命令或操作 | 结果 |
|---|---|---|---|
|  |  |  |  |

## 风险与回滚

<兼容性、数据迁移、部署顺序、回滚步骤；无风险也要写明依据。>

## 合并与收尾

- 合并方式：<merge / squash / rebase，按仓库设置>
- issue 关闭策略：<`Closes #N` / 合并后手动关闭 / 保持打开并更新状态标签>
- 部署顺序：<若涉及多个仓库，写明先后>
- 分支与 worktree 清理：<是否删除源分支、移除哪个 worktree>

## 状态

<待办 / 进行中 / 待评审 / 已合并 / 已关闭；每行带日期与依据>
```

## PR Or MR Preparation

Before drafting PR content:

1. Check the diff and commit list against the target branch.
2. Summarize only the actual change in scope.
3. Call out risk, verification, and whether a release cherry-pick is required.
4. State the exact target branch.
5. State the target-branch divergence and any merge or unpublished rebase performed.
6. Point at the tracking document (`.docs/pr-<number>-<slug>.md`) and keep its acceptance criteria consistent with the PR description. Re-read the linked issue/work item and refresh `## 原文` whenever the source text changed, so the pasted text matches what reviewers see.

Use the repository's PR language requirements. Keep titles and descriptions concrete and include:

- What changed
- Why it changed
- How it was verified
- What risks or rollback notes exist
- Whether cherry-pick is required
- What the target branch is
- Which issues it closes

Do not claim tests passed if they were not run. Do not hide known risks.

## Acceptance Before Merge

Merge is allowed only after each acceptance criterion in the tracking document is either proven or explicitly waived by the user.

For every criterion:

1. Run the specific check (test, curl, UI path, migration dry run) rather than trusting the PR description.
2. Record command and observed result in the tracking document's verification table.
3. Mark the checkbox only when the evidence exists.

Also verify before merging:

- CI status is known: `gh pr checks <N>` / `glab ci status`, and any red job is classified as code, flake, or infrastructure. Name the failing job and the reason; never merge silently past a red pipeline.
- CI gate policy: if the repository blocks merge on a pipeline, wait or fix; if the gate is disabled, state explicitly that the pipeline was red and why the merge still proceeded.
- Target branch is not protected against your role; check merge permission and required approvals first.
- No conflict, no draft state, no requested changes pending.
- Deployment order across repositories is written down (e.g. backend before frontend).

## Merge And Issue Close-out

Merge with the repository's configured method (do not squash unless the repository or the user says so):

```bash
# GitHub
gh pr merge <N> --merge          # or --squash / --rebase per repo setting
# GitLab
glab mr merge <N> --yes
```

Then close out the linked issues. Both platforms honor closing keywords in the PR/MR description or commit message:

- `Closes #N`, `Fixes #N`, `Resolves #N` — close on merge into the default branch
- `Related to #N` — creates a cross-reference only, does **not** close

Closing-keyword caveat: keywords only take effect at merge time from the description/commits. If the PR is already merged, close the issue explicitly and reference the merge commit.

Manual close-out sequence when keywords are absent or the merge already happened:

```bash
# GitHub
gh issue close <N> --comment "已由 #<PR> 合并（<merge-commit>）交付。"
gh issue edit <N> --add-label "status:..."; gh issue edit <N> --remove-label "status:closed"
# GitLab
glab issue close <N> --message "已由 !<MR> 合并（<merge-commit>）交付。"
glab issue update <N> --label "状态:待评审" --unlabel "状态:进行中"
```

Rules:

- Close an issue only when the delivered scope actually satisfies its acceptance criteria; otherwise keep it open and update its status label, stating the remaining gap.
- Record the merge commit SHA on the issue so the link survives later label changes.
- Never close an issue that other open PRs/MRs still reference as incomplete work.
- Verify the result (`closes_issues` / the issue's related-MR panel), then report.

## Post-Merge Cleanup

After a merge is confirmed:

1. Delete the source branch (most GitLab projects do it automatically; GitHub needs `gh pr merge --delete-branch` or a manual delete).
2. Remove the source branch worktree: `git worktree remove <path>` after checking it is clean, then `git worktree prune`.
3. Delete the local branch: `git branch -d <branch>` (use `-D` only after confirming the commits are contained in the merged target branch).
4. Keep the tracking document. Copy anything still valuable out of the worktree before removal.
5. Report the merge commit, deleted branch/worktree, issue state, and any remaining red CI.

## Pre-Submission Checklist

Before commit, PR, or MR submission, verify:

- `git status --short` has been checked
- only intended files are staged
- no unrelated debug code, temporary files, or accidental formatting noise is included
- commit message follows repository language and formatting rules and matches the actual scope
- target branch is confirmed
- target-branch divergence has been checked and published history is preserved
- required tests or checks have been run, or the lack of verification is explicitly stated
- the tracking document exists and its acceptance criteria match the actual change
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

## GitHub And GitLab Parity

| Task | GitHub | GitLab |
|---|---|---|
| PR / MR | Pull request | Merge request |
| View | `gh pr view <N>` | `glab mr view <N>` |
| Diff | `gh pr diff <N>` | `glab mr diff <N>` |
| Checks / pipeline | `gh pr checks <N>` | `glab ci status` |
| Review comment | `gh pr review <N>` / `gh pr comment <N>` | `glab mr note <N>` |
| Merge | `gh pr merge <N> --merge` | `glab mr merge <N> --yes` |
| Issue close | `gh issue close <N>` | `glab issue close <N>` |
| Issue labels | `gh issue edit <N> --add-label` | `glab issue update <N> --label` |
| Raw API | `gh api` | `glab api` |
| Branch protection | Rulesets / branch protection | Protected branches |

Behavioral parity notes:

- Both close issues from `Closes/Fixes/Resolves #N` in the PR/MR description at merge time.
- Both auto-delete the source branch only if configured; verify instead of assuming.
- GitHub squash-merges by default in many repos, GitLab keeps the source commits unless squash is enabled. Read the repository setting before merging.
- GitLab can auto-merge when the pipeline is running; GitHub waits on required checks. If the pipeline can never go green (known infrastructure failure), record it and merge explicitly rather than leaving an auto-merge pending.
- Branch deletion does not delete local worktrees; clean them separately in both platforms.

## Communication Rules

Be explicit when reporting Git state:

- Current branch
- Target branch
- Whether the working tree is dirty
- Whether an unpublished rebase or a cherry-pick was performed
- Whether an ordinary push is possible or remote divergence still needs resolution
- Tracking document path and acceptance status
- Merged commit SHA, issue state, deleted branch/worktree, and any remaining red CI

If a command could discard or overwrite user work, stop and get approval first.
