#!/usr/bin/env python3
"""Package a Codex skill zip for ModelScope upload."""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path


DEFAULT_SKILL_DIR = Path(__file__).resolve().parents[1]
EXCLUDED_NAMES = {".DS_Store", ".env"}
EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".zip"}
EXCLUDED_DIR_PARTS = {"__pycache__", ".git", ".venv", "node_modules"}


def should_include(path: Path) -> bool:
    parts = set(path.parts)
    if parts & EXCLUDED_DIR_PARTS:
        return False
    if path.name in EXCLUDED_NAMES:
        return False
    if path.suffix in EXCLUDED_SUFFIXES:
        return False
    if path.name.startswith(".env."):
        return False
    return True


def collect_files(skill_dir: Path) -> list[Path]:
    files = []
    for path in skill_dir.rglob("*"):
        if path.is_file() and should_include(path.relative_to(skill_dir)):
            files.append(path)
    return sorted(files)


def validate_skill_dir(skill_dir: Path) -> None:
    if not skill_dir.is_dir():
        raise SystemExit(f"Skill directory does not exist: {skill_dir}")
    skill_file = skill_dir / "SKILL.md"
    if not skill_file.is_file():
        raise SystemExit(f"Missing required SKILL.md at: {skill_file}")
    text = skill_file.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise SystemExit("SKILL.md must start with YAML frontmatter.")
    frontmatter = text.split("---\n", 2)[1]
    if "name:" not in frontmatter or "description:" not in frontmatter:
        raise SystemExit("SKILL.md frontmatter must include name and description.")


def create_zip(skill_dir: Path, output: Path) -> dict[str, object]:
    validate_skill_dir(skill_dir)
    output.parent.mkdir(parents=True, exist_ok=True)
    files = collect_files(skill_dir)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, path.relative_to(skill_dir).as_posix())
    return validate_zip(output)


def validate_zip(zip_path: Path, max_size_mb: int = 5) -> dict[str, object]:
    if not zip_path.is_file():
        raise SystemExit(f"Zip file does not exist: {zip_path}")
    size = zip_path.stat().st_size
    max_size = max_size_mb * 1024 * 1024
    if size > max_size:
        raise SystemExit(f"Zip exceeds {max_size_mb} MB: {zip_path}")

    with zipfile.ZipFile(zip_path) as archive:
        names = [name for name in archive.namelist() if not name.endswith("/")]

    skill_files = [name for name in names if name == "SKILL.md"]
    nested_skill_files = [name for name in names if name.endswith("/SKILL.md")]
    if skill_files != ["SKILL.md"] or nested_skill_files:
        raise SystemExit("The zip root must contain exactly one SKILL.md.")

    return {
        "status": "ok",
        "zip": str(zip_path),
        "size_bytes": size,
        "file_count": len(names),
        "skill_files": skill_files,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Package a skill zip for ModelScope.")
    parser.add_argument(
        "skill_dir",
        nargs="?",
        default=str(DEFAULT_SKILL_DIR),
        help="Skill directory to package.",
    )
    parser.add_argument("--output", default="/tmp/modelscope-api-skill.zip")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    skill_dir = Path(args.skill_dir)
    output = Path(args.output)
    result = validate_zip(output) if args.validate_only else create_zip(skill_dir, output)

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(
            f"{result['status']}: {result['zip']} "
            f"({result['file_count']} files, {result['size_bytes']} bytes)"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
