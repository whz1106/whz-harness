#!/usr/bin/env python3
import argparse
import datetime as dt
import os
import re
import subprocess
from pathlib import Path
from typing import Optional


SECRET_PATTERNS = [
    re.compile(r"(?i)\b(api[_-]?key|token|password|passwd|secret)\s*[:=]\s*['\"]?[^'\"\s]+"),
    re.compile(r"\b(sk-[A-Za-z0-9_-]{16,})\b"),
    re.compile(r"\b(e2b_[A-Za-z0-9_-]{16,})\b"),
]


def journal_root() -> Path:
    default_root = Path(__file__).resolve().parents[2] / "daily-work-journal"
    return Path(os.environ.get("DAILY_WORK_JOURNAL", str(default_root))).expanduser()


def today() -> str:
    return dt.date.today().isoformat()


def month_for(date_text: str) -> str:
    return date_text[:7]


def month_dir(root: Path, month_text: str) -> Path:
    return root / month_text[:4] / month_text


def paths_for_date(root: Path, date_text: str) -> dict:
    month_text = month_for(date_text)
    base = month_dir(root, month_text)
    return {
        "base": base,
        "raw_day": base / "raw" / date_text,
        "daily_dir": base / "daily",
        "daily_file": base / "daily" / f"{date_text}.md",
    }


def redact(text: str) -> str:
    redacted = text
    for pattern in SECRET_PATTERNS:
        redacted = pattern.sub(lambda m: f"{m.group(1)}=[REDACTED]" if m.groups() else "[REDACTED]", redacted)
    return redacted


def ensure_month(root: Path, date_text: str) -> dict:
    paths = paths_for_date(root, date_text)
    paths["raw_day"].mkdir(parents=True, exist_ok=True)
    paths["daily_dir"].mkdir(parents=True, exist_ok=True)
    return paths


def valid_agent_file(name: str) -> str:
    if not name.endswith(".md"):
        name = f"{name}.md"
    if "/" in name or "\\" in name or name.startswith("."):
        raise SystemExit("--agent-file must be a simple markdown filename")
    return name


def append_raw(args: argparse.Namespace) -> None:
    date_text = args.date or today()
    paths = ensure_month(journal_root(), date_text)
    target = paths["raw_day"] / valid_agent_file(args.agent_file)
    now = dt.datetime.now().strftime("%H:%M")
    project = args.project or "工作记录"
    entry = redact(args.entry.strip())

    if not target.exists():
        target.write_text(f"# {date_text} 工作记录\n\n", encoding="utf-8")

    with target.open("a", encoding="utf-8") as handle:
        handle.write(f"## {now} {project}\n\n")
        if not entry.startswith("-"):
            for line in entry.splitlines():
                clean = line.strip()
                if clean:
                    handle.write(f"- {clean}\n")
        else:
            handle.write(f"{entry}\n")
        handle.write("\n")

    print(target)


def read_markdown_files(files: list[Path]) -> list[tuple[Path, str]]:
    result = []
    for file_path in files:
        if file_path.is_file() and file_path.suffix == ".md":
            result.append((file_path, redact(file_path.read_text(encoding="utf-8", errors="replace"))))
    return result


def extract_bullets(text: str) -> list[str]:
    bullets = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("## "):
            item = stripped[3:].strip()
            if item and item not in bullets:
                bullets.append(item)
        if stripped.startswith(("- ", "* ")):
            item = stripped[2:].strip()
            if item and item not in bullets:
                bullets.append(item)
    return bullets


def git_lines(repo: Optional[str], date_text: str) -> list[str]:
    if not repo:
        return []
    repo_path = Path(repo).expanduser()
    if not (repo_path / ".git").exists():
        return []

    lines = []
    commands = [
        ["git", "log", "--since", f"{date_text} 00:00", "--until", f"{date_text} 23:59:59", "--oneline", "--decorate"],
        ["git", "status", "--short"],
    ]
    for command in commands:
        completed = subprocess.run(command, cwd=repo_path, text=True, capture_output=True, check=False)
        output = redact(completed.stdout.strip())
        if output:
            label = "今日提交" if command[1] == "log" else "未提交变更"
            for line in output.splitlines()[:20]:
                lines.append(f"{label}: `{line}`")
    return lines


def grouped_summary(items: list[str]) -> dict[str, list[str]]:
    groups = {
        "核心进展": [],
        "解决的问题": [],
        "重要发现": [],
        "当前风险 / 遗留问题": [],
        "明日建议": [],
    }
    for item in items:
        lower = item.lower()
        if any(key in item for key in ["遗留", "风险", "失败", "未解决", "阻塞", "TODO", "todo"]):
            groups["当前风险 / 遗留问题"].append(item)
        elif any(key in item for key in ["发现", "结论", "定位", "原因"]):
            groups["重要发现"].append(item)
        elif any(key in item for key in ["解决", "修复", "通过", "恢复", "fixed"]):
            groups["解决的问题"].append(item)
        elif any(key in item for key in ["明日", "建议", "下一步", "follow", "next"]):
            groups["明日建议"].append(item)
        elif lower:
            groups["核心进展"].append(item)
    return groups


def render_sections(title: str, groups: dict[str, list[str]], fallback: str) -> str:
    lines = [f"# {title}", ""]
    for heading, values in groups.items():
        lines.append(f"## {heading}")
        unique = []
        for value in values:
            if value not in unique:
                unique.append(value)
        if unique:
            lines.extend(f"- {value}" for value in unique[:30])
        else:
            lines.append(f"- {fallback}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def daily(args: argparse.Namespace) -> None:
    date_text = args.date or today()
    paths = ensure_month(journal_root(), date_text)
    raw_entries = read_markdown_files(sorted(paths["raw_day"].glob("*.md")))
    bullets = []
    for file_path, content in raw_entries:
        bullets.append(f"来源 {file_path.name}")
        bullets.extend(extract_bullets(content))
    bullets.extend(git_lines(args.repo, date_text))
    if args.entry:
        bullets.extend(extract_bullets(redact(args.entry)))
        if not bullets:
            bullets.append(redact(args.entry.strip()))

    groups = grouped_summary(bullets)
    output = render_sections(f"{date_text} 今日工作总结", groups, "暂无记录")
    paths["daily_file"].write_text(output, encoding="utf-8")
    print(paths["daily_file"])
    print()
    print(output)


def monthly_groups(items: list[str]) -> dict[str, list[str]]:
    groups = {
        "主要成果": [],
        "关键突破": [],
        "高频问题与解决模式": [],
        "重要技术沉淀": [],
        "遗留风险": [],
        "下月建议": [],
    }
    for item in items:
        if any(key in item for key in ["遗留", "风险", "阻塞", "未解决"]):
            groups["遗留风险"].append(item)
        elif any(key in item for key in ["建议", "明日", "下月", "下一步"]):
            groups["下月建议"].append(item)
        elif any(key in item for key in ["解决", "修复", "通过", "恢复"]):
            groups["高频问题与解决模式"].append(item)
        elif any(key in item for key in ["发现", "沉淀", "结论", "模式"]):
            groups["重要技术沉淀"].append(item)
        elif any(key in item for key in ["突破", "上线", "完成"]):
            groups["关键突破"].append(item)
        else:
            groups["主要成果"].append(item)
    return groups


def monthly(args: argparse.Namespace) -> None:
    month_text = args.month or month_for(today())
    base = month_dir(journal_root(), month_text)
    daily_files = sorted((base / "daily").glob("*.md"))
    if not daily_files and args.include_raw:
        daily_files = sorted((base / "raw").glob("*/*.md"))
    entries = read_markdown_files(daily_files)
    bullets = []
    for file_path, content in entries:
        bullets.append(f"来源 {file_path.name}")
        bullets.extend(extract_bullets(content))

    output = render_sections(f"{month_text} 月度工作总结", monthly_groups(bullets), "暂无记录")
    target = base / "monthly-summary.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(output, encoding="utf-8")
    print(target)
    print()
    print(output)


def init(args: argparse.Namespace) -> None:
    date_text = args.date or today()
    paths = ensure_month(journal_root(), date_text)
    print(paths["base"])


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Maintain daily work journal markdown files.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="create the current month journal directories")
    init_parser.add_argument("--date")
    init_parser.set_defaults(func=init)

    append_parser = subparsers.add_parser("append-raw", help="append one sanitized raw log entry")
    append_parser.add_argument("--date")
    append_parser.add_argument("--agent-file", required=True)
    append_parser.add_argument("--project")
    append_parser.add_argument("--entry", required=True)
    append_parser.set_defaults(func=append_raw)

    daily_parser = subparsers.add_parser("daily", help="generate a daily summary from raw logs")
    daily_parser.add_argument("--date")
    daily_parser.add_argument("--repo", help="optional git repository path to inspect")
    daily_parser.add_argument("--entry", help="optional current-session notes to include")
    daily_parser.set_defaults(func=daily)

    monthly_parser = subparsers.add_parser("monthly", help="generate a monthly summary")
    monthly_parser.add_argument("--month")
    monthly_parser.add_argument("--include-raw", action="store_true")
    monthly_parser.set_defaults(func=monthly)
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
