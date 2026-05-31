---
name: daily-work-summary
description: Use when the user asks in Chinese or English to record today's work, summarize today's work, generate a daily work report, summarize this month's work, generate a monthly report, sync work logs, or maintain the daily-work-journal markdown repository.
---

# Daily Work Summary

Maintain concise Chinese work notes and summaries in the sibling markdown journal repository `daily-work-journal/` unless `DAILY_WORK_JOURNAL` is set.

Use `scripts/daily_work_journal.py` for deterministic path creation, raw log appends, daily summary files, monthly summary files, and secret redaction.

## Journal Layout

```text
daily-work-journal/
  YYYY/
    YYYY-MM/
      raw/
        YYYY-MM-DD/
          <machine-or-server>-<agent>-<project>.md
      daily/
        YYYY-MM-DD.md
      monthly-summary.md
```

Meanings:

- `raw/YYYY-MM-DD/*.md`: each agent's own daily raw notes. Ordinary agents write only here.
- `daily/YYYY-MM-DD.md`: merged daily report generated only by the summarizing agent when the user explicitly asks for a daily report.
- `monthly-summary.md`: monthly report generated only by the summarizing agent when the user explicitly asks for a monthly report.

## Work Recording

When asked for `记录今日工作`, `记录下`, `总结下本次工作`, `记录下今天工作`, `同步并记录`, or equivalent, treat the request as raw work recording unless the user explicitly asks to generate a report:

1. Determine today's date from the machine timezone unless the user specifies a date.
2. If the journal is a git repository and the user requested sync or remote sharing, run `git pull --rebase` before writing.
3. If the current session produced meaningful progress, append a short sanitized raw entry to the current agent file:

   ```bash
   python3 今日总结.skill/scripts/daily_work_journal.py append-raw \
     --date YYYY-MM-DD \
     --agent-file mac-codex-project.md \
     --project "项目 / 任务" \
     --entry "摘要、关键命令、测试结果、发现、解决方案、遗留事项"
   ```

4. Do not edit `daily/YYYY-MM-DD.md` or `monthly-summary.md`.
5. If the user requested sync, commit only the changed raw file, then run `git pull --rebase` again and `git push`.

## Daily Report

When asked for `生成今日总结`, `生成今日汇报`, `生成日报`, `今日汇报`, `汇总今日工作`, or explicitly asks to generate/update the daily summary:

1. Determine today's date from the machine timezone unless the user specifies a date.
2. If the journal is a git repository, run `git pull --rebase` before reading raw logs.
3. If the current session produced meaningful progress not yet recorded, append it to this agent's raw file first.
4. If the current directory is a git repo, pass it to the generator with `--repo "$PWD"` so today's commits and status are considered.
5. Generate the daily file:

   ```bash
   python3 今日总结.skill/scripts/daily_work_journal.py daily --date YYYY-MM-DD --repo "$PWD"
   ```

6. Read the generated `daily/YYYY-MM-DD.md` and return a concise report in the conversation.
7. If the user requested sync, commit the changed raw and daily files, then run `git pull --rebase` again and `git push`.

Daily report format:

```md
# YYYY-MM-DD 今日工作总结

## 核心进展
## 解决的问题
## 重要发现
## 当前风险 / 遗留问题
## 明日建议
## 工作记录详情
```

Keep the first five sections concise and report-oriented. Use `工作记录详情` as a flexible section for richer context from the agents' raw notes. Do not force a fixed layout inside that section: organize it by business context, task, experiment, test run, investigation path, command sequence, or any other shape that best explains what happened.

## Monthly Summary

When asked for `总结本月工作`, `生成月度总结`, `月度汇报`, `这个月做了什么`, or equivalent:

1. Determine the target month, defaulting to the current month.
2. If the journal is a git repository, run `git pull --rebase` before reading summaries.
3. Generate from `daily/*.md`; use `--include-raw` only when daily files are missing or too sparse.

   ```bash
   python3 今日总结.skill/scripts/daily_work_journal.py monthly --month YYYY-MM
   ```

4. Read `monthly-summary.md` and return a concise monthly report.
5. If the user requested sync, commit the changed monthly file, then run `git pull --rebase` again and `git push`.

Monthly report format:

```md
# YYYY-MM 月度工作总结

## 主要成果
## 关键突破
## 高频问题与解决模式
## 重要技术沉淀
## 遗留风险
## 下月建议
```

## Raw Log Rules

Use one raw file per agent per day:

```text
<machine-or-server>-<agent>-<project>.md
```

Raw entry shape:

```md
# YYYY-MM-DD 工作记录

## HH:MM 项目 / 任务

- 目标：
- 操作：
- 测试：
- 发现：
- 解决：
- 遗留：
```

Keep entries brief. Include only summaries, important commands, key results, conclusions, failures, fixes, and remaining risks.

When a task has substantial details such as multiple test runs, parameter comparisons, command output summaries, debugging paths, or business context, write those details in the raw file using natural Markdown. The daily summary may carry them into `工作记录详情` without enforcing fixed subheadings.

## Storage And Safety

- Store only markdown text.
- Do not store screenshots, archives, database dumps, full test artifacts, complete `.env` files, large logs, or unrelated command transcripts.
- Redact API keys, tokens, passwords, private endpoint parameters, and secrets before writing.
- Prefer keeping each raw file under 200KB; summarize older detail before appending more.
- Ordinary agents must only write their own `raw/YYYY-MM-DD/<agent-file>.md`.
- Do not edit `daily/*.md` unless the user explicitly asks to generate or update the daily report.
- Do not edit `monthly-summary.md` unless the user explicitly asks to generate or update the monthly report.

## Git Sync Rules

- Do not commit, pull, or push by default. Sync only when the user explicitly says `同步日志`, `提交日志`, `push 日志`, `同步日报`, or equivalent.
- For raw recording sync: `git pull --rebase`, append raw, `git add` only the changed raw file, commit, `git pull --rebase`, push.
- For daily report sync: `git pull --rebase`, generate daily report, `git add` the changed raw and daily files, commit, `git pull --rebase`, push.
- For monthly report sync: `git pull --rebase`, generate monthly report, `git add` the changed monthly file, commit, `git pull --rebase`, push.
- If `git pull --rebase` reports conflicts, stop and report the conflicted files. Do not auto-resolve journal conflicts.
- Prefer one raw file per agent/project/day so multiple machines do not edit the same raw file.

## Missing Journal

If `daily-work-journal/` does not exist, initialize the month directories with:

```bash
python3 今日总结.skill/scripts/daily_work_journal.py init
```

Then continue with the requested summary. If there are no raw logs and no current-session notes, generate the minimal summary and say that the journal had no prior entries for the date.
