#!/usr/bin/env python3
"""Check local prerequisites for the ModelScope skill."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys


def check_token(env: dict[str, str] | None = None) -> dict[str, str]:
    env = env or os.environ
    for name in ("MODELSCOPE_API_TOKEN", "MODELSCOPE_TOKEN"):
        if env.get(name):
            return {
                "name": "token",
                "status": "ok",
                "source": name,
                "message": f"Found token in {name}.",
            }
    return {
        "name": "token",
        "status": "missing",
        "source": "",
        "message": "Set MODELSCOPE_API_TOKEN before authenticated OpenAPI calls.",
    }


def check_modelscope_cli(run_help: bool = False) -> dict[str, str]:
    path = shutil.which("modelscope")
    if not path:
        return {
            "name": "modelscope_cli",
            "status": "missing",
            "path": "",
            "message": "Install with: python3 -m pip install modelscope",
        }

    if not run_help:
        return {
            "name": "modelscope_cli",
            "status": "ok",
            "path": path,
            "message": "ModelScope CLI is available.",
        }

    result = subprocess.run(
        ["modelscope", "download", "--help"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode == 0:
        return {
            "name": "modelscope_cli",
            "status": "ok",
            "path": path,
            "message": "ModelScope download command is available.",
        }
    return {
        "name": "modelscope_cli",
        "status": "error",
        "path": path,
        "message": result.stderr.strip() or result.stdout.strip(),
    }


def check_python() -> dict[str, str]:
    version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    status = "ok" if sys.version_info >= (3, 9) else "warning"
    return {
        "name": "python",
        "status": status,
        "version": version,
        "message": "Python 3.9+ is recommended for these helper scripts.",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Check ModelScope skill setup.")
    parser.add_argument(
        "--run-help",
        action="store_true",
        help="Run `modelscope download --help` instead of only checking PATH.",
    )
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")
    args = parser.parse_args(argv)

    checks = [check_python(), check_token(), check_modelscope_cli(args.run_help)]
    if args.json:
        print(json.dumps({"checks": checks}, ensure_ascii=False, indent=2))
    else:
        for check in checks:
            detail = check.get("path") or check.get("source") or check.get("version") or ""
            suffix = f" ({detail})" if detail else ""
            print(f"{check['status'].upper()}: {check['name']}{suffix} - {check['message']}")

    return 1 if any(check["status"] == "error" for check in checks) else 0


if __name__ == "__main__":
    raise SystemExit(main())
