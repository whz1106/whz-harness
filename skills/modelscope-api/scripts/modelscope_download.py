#!/usr/bin/env python3
"""Wrapper for official `modelscope download` resource downloads."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download ModelScope model or dataset resources via the official CLI."
    )
    parser.add_argument("resource_type", choices=["model", "dataset"])
    parser.add_argument("resource_id", help="Model or dataset id, for example qwen/Qwen3-8B")
    parser.add_argument(
        "files",
        nargs="*",
        help="Optional relative file paths, for example tokenizer.json",
    )
    parser.add_argument("--revision", help="Model or dataset revision")
    parser.add_argument("--cache-dir", dest="cache_dir", help="ModelScope cache directory")
    parser.add_argument("--local-dir", dest="local_dir", help="Explicit output directory")
    parser.add_argument("--include", nargs="+", help="Glob patterns to include")
    parser.add_argument("--exclude", nargs="+", help="Glob patterns to exclude")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the command without downloading resources",
    )
    return parser.parse_args(argv)


def validate_args(args: argparse.Namespace) -> None:
    marker_count = int(args.resource_type == "model") + int(args.resource_type == "dataset")
    if marker_count != 1 or getattr(args, "model", None):
        raise SystemExit("Choose exactly one resource type: model or dataset.")
    if args.files and (args.include or args.exclude):
        raise SystemExit("Specific files cannot be combined with --include or --exclude.")


def build_command(args: argparse.Namespace) -> list[str]:
    validate_args(args)
    command = ["modelscope", "download"]
    command.extend([f"--{args.resource_type}", args.resource_id])

    if args.revision:
        command.extend(["--revision", args.revision])
    if args.cache_dir:
        command.extend(["--cache_dir", args.cache_dir])
    if args.local_dir:
        command.extend(["--local_dir", args.local_dir])
    if args.include:
        command.append("--include")
        command.extend(args.include)
    if args.exclude:
        command.append("--exclude")
        command.extend(args.exclude)

    command.extend(args.files)
    return command


def ensure_cli_available() -> None:
    if shutil.which("modelscope"):
        return
    raise SystemExit(
        "Missing ModelScope CLI. Install the SDK first, for example: "
        "python3 -m pip install modelscope"
    )


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    command = build_command(args)

    if args.dry_run:
        print(json.dumps({"command": command}, ensure_ascii=False, indent=2))
        return 0

    ensure_cli_available()
    return subprocess.call(command)


if __name__ == "__main__":
    raise SystemExit(main())
