#!/usr/bin/env python3
"""Small stdlib CLI for ModelScope OpenAPI calls."""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


DEFAULT_BASE_URL = "https://modelscope.cn/openapi/v1"


def build_url(base_url: str, path: str, query: list[tuple[str, str]]) -> str:
    base = base_url.rstrip("/")
    normalized_path = "/" + path.lstrip("/")
    url = f"{base}{normalized_path}"
    if query:
        url = f"{url}?{urllib.parse.urlencode(query)}"
    return url


def get_token(env: dict[str, str] | None = None) -> str:
    env = env or os.environ
    token = env.get("MODELSCOPE_API_TOKEN") or env.get("MODELSCOPE_TOKEN")
    if not token:
        raise SystemExit(
            "Missing ModelScope token. Set MODELSCOPE_API_TOKEN in the shell "
            "or project environment before calling the API."
        )
    return token


def redact_headers(headers: dict[str, str]) -> dict[str, str]:
    redacted = dict(headers)
    if "Authorization" in redacted:
        redacted["Authorization"] = "Bearer <redacted>"
    return redacted


def parse_pairs(values: list[str]) -> list[tuple[str, str]]:
    pairs = []
    for value in values:
        if "=" not in value:
            raise SystemExit(f"Expected KEY=VALUE, got: {value}")
        key, item = value.split("=", 1)
        if not key:
            raise SystemExit(f"Expected non-empty key in: {value}")
        pairs.append((key, item))
    return pairs


def read_json_body(inline_json: str | None, json_file: str | None) -> bytes | None:
    if inline_json and json_file:
        raise SystemExit("Use either --data or --json-file, not both.")
    if not inline_json and not json_file:
        return None

    raw = Path(json_file).read_text(encoding="utf-8") if json_file else inline_json
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON body: {exc}") from exc
    return json.dumps(parsed, ensure_ascii=False).encode("utf-8")


def build_multipart(form: list[tuple[str, str]], files: list[tuple[str, str]]) -> tuple[bytes, str]:
    boundary = f"----modelscope-{secrets.token_hex(12)}"
    chunks: list[bytes] = []

    for key, value in form:
        chunks.extend(
            [
                f"--{boundary}\r\n".encode(),
                f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode(),
                value.encode(),
                b"\r\n",
            ]
        )

    for key, file_path in files:
        path = Path(file_path)
        filename = path.name
        content_type = mimetypes.guess_type(filename)[0] or "application/octet-stream"
        chunks.extend(
            [
                f"--{boundary}\r\n".encode(),
                (
                    f'Content-Disposition: form-data; name="{key}"; '
                    f'filename="{filename}"\r\n'
                ).encode(),
                f"Content-Type: {content_type}\r\n\r\n".encode(),
                path.read_bytes(),
                b"\r\n",
            ]
        )

    chunks.append(f"--{boundary}--\r\n".encode())
    return b"".join(chunks), f"multipart/form-data; boundary={boundary}"


def build_request(args: argparse.Namespace) -> urllib.request.Request:
    query = parse_pairs(args.query)
    url = build_url(args.base_url, args.path, query)
    headers = {"Accept": "application/json"}

    if not args.no_auth:
        headers["Authorization"] = f"Bearer {get_token()}"

    form = parse_pairs(args.form)
    files = parse_pairs(args.file)
    json_body = read_json_body(args.data, args.json_file)

    if json_body and (form or files):
        raise SystemExit("JSON body cannot be combined with --form or --file.")

    body = None
    if files or form:
        body, content_type = build_multipart(form, files)
        headers["Content-Type"] = content_type
    elif json_body is not None:
        body = json_body
        headers["Content-Type"] = "application/json"

    return urllib.request.Request(url, data=body, method=args.method, headers=headers)


def emit_response(response: urllib.response.addinfourl) -> None:
    raw = response.read()
    text = raw.decode("utf-8", errors="replace")
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        print(text)
        return
    print(json.dumps(parsed, ensure_ascii=False, indent=2))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Call ModelScope OpenAPI.")
    parser.add_argument("method", choices=["GET", "POST", "PUT", "PATCH", "DELETE"])
    parser.add_argument("path", help="OpenAPI path, for example /models")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--query", action="append", default=[], help="Query KEY=VALUE")
    parser.add_argument("--data", help="Inline JSON request body")
    parser.add_argument("--json-file", help="Path to JSON request body")
    parser.add_argument("--form", action="append", default=[], help="Multipart field KEY=VALUE")
    parser.add_argument("--file", action="append", default=[], help="Multipart file KEY=PATH")
    parser.add_argument("--no-auth", action="store_true", help="Skip bearer auth header")
    parser.add_argument("--dry-run", action="store_true", help="Print request without sending it")
    args = parser.parse_args(argv)

    request = build_request(args)
    if args.dry_run:
        body = request.data.decode("utf-8", errors="replace") if request.data else None
        print(
            json.dumps(
                {
                    "method": request.get_method(),
                    "url": request.full_url,
                    "headers": redact_headers(dict(request.header_items())),
                    "body": body,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0

    try:
        with urllib.request.urlopen(request) as response:
            emit_response(response)
    except urllib.error.HTTPError as exc:
        print(exc.read().decode("utf-8", errors="replace"), file=sys.stderr)
        return exc.code

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
