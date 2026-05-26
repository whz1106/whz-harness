---
name: daily-work-summary
description: Use when the user asks in Chinese or English to summarize today's work, generate a daily work report, summarize what was done today, summarize this month's work, generate a monthly report, or maintain the daily-work-journal markdown repository.
---

# Daily Work Summary

Create concise Chinese work summaries from the sibling markdown journal repository `daily-work-journal/` unless `DAILY_WORK_JOURNAL` is set.

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

- `raw/YYYY-MM-DD/*.md`: each agent's own daily raw notes.
- `daily/YYYY-MM-DD.md`: merged daily report generated only when summary is requested.
- `monthly-summary.md`: monthly report generated only when monthly summary is requested.

## Daily Summary

When asked for `帮我总结`, `总结今日工作`, `总结下今日工作`, `生成今日汇报`, `今日总结`, `总结今天干了什么`, or equivalent:

1. Determine today's date from the machine timezone unless the user specifies a date.
2. If the current session produced meaningful progress, append a short sanitized raw entry to the current agent file:

   ```bash
   python3 今日总结.skill/scripts/daily_work_journal.py append-raw \
     --date YYYY-MM-DD \
     --agent-file mac-codex-project.md \
     --project "项目 / 任务" \
     --entry "摘要、关键命令、测试结果、发现、解决方案、遗留事项"
   ```

3. If the current directory is a git repo, pass it to the generator with `--repo "$PWD"` so today's commits and status are considered.
4. Generate the daily file:

   ```bash
   python3 今日总结.skill/scripts/daily_work_journal.py daily --date YYYY-MM-DD --repo "$PWD"
   ```

5. Read the generated `daily/YYYY-MM-DD.md` and return a concise report in the conversation.

Daily report format:

```md
# YYYY-MM-DD 今日工作总结

## 核心进展
## 解决的问题
## 重要发现
## 当前风险 / 遗留问题
## 明日建议
```

## Monthly Summary

When asked for `总结本月工作`, `生成月度总结`, `月度汇报`, `这个月做了什么`, or equivalent:

1. Determine the target month, defaulting to the current month.
2. Generate from `daily/*.md`; use `--include-raw` only when daily files are missing or too sparse.

   ```bash
   python3 今日总结.skill/scripts/daily_work_journal.py monthly --month YYYY-MM
   ```

3. Read `monthly-summary.md` and return a concise monthly report.

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

## Storage And Safety

- Store only markdown text.
- Do not store screenshots, archives, database dumps, full test artifacts, complete `.env` files, large logs, or unrelated command transcripts.
- Redact API keys, tokens, passwords, private endpoint parameters, and secrets before writing.
- Prefer keeping each raw file under 200KB; summarize older detail before appending more.
- Do not edit `daily/*.md` or `monthly-summary.md` unless the user asked for a summary.
- Do not commit or push the journal by default. Commit or push only when the user explicitly says `同步日志`, `提交日报`, or equivalent.

## Missing Journal

If `daily-work-journal/` does not exist, initialize the month directories with:

```bash
python3 今日总结.skill/scripts/daily_work_journal.py init
```

Then continue with the requested summary. If there are no raw logs and no current-session notes, generate the minimal summary and say that the journal had no prior entries for the date.
