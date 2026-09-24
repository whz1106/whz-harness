#!/usr/bin/env bash
# 追加一条捕获到记忆仓库某一层的 notes/inbox.md，提交并推送。
#
#   capture.sh "要记住的事实" [--layer personal|work] [--no-push]
#
# --layer 默认 personal（个人通用层）；工作环境的东西用 --layer work。
# 该仓库是 GitHub 仓库，所以写入前一律做敏感内容守卫：内网地址/私钥块/凭据前缀直接拒绝。
set -euo pipefail

TEXT=""
LAYER="personal"
NO_PUSH=0

while [ $# -gt 0 ]; do
	case "$1" in
	--layer)
		LAYER="${2:-}"
		[ -n "$LAYER" ] || {
			printf 'capture: --layer 需要一个参数\n' >&2
			exit 2
		}
		shift 2
		;;
	--layer=*)
		LAYER="${1#--layer=}"
		shift
		;;
	--no-push)
		NO_PUSH=1
		shift
		;;
	*)
		if [ -z "$TEXT" ]; then TEXT="$1"; else TEXT="$TEXT $1"; fi
		shift
		;;
	esac
done

if [ -z "$TEXT" ]; then
	printf '用法: capture.sh "要记住的事实" [--layer personal|work] [--no-push]\n' >&2
	exit 2
fi

if [ -z "${HOME:-}" ] || [ ! -d "${HOME:-}" ]; then
	if [ -n "${USERPROFILE:-}" ]; then
		if command -v cygpath >/dev/null 2>&1; then HOME="$(cygpath -u "$USERPROFILE")"; else HOME="$USERPROFILE"; fi
	fi
fi
if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then
	printf 'capture: 无法确定家目录（HOME=%s）\n' "${HOME:-}" >&2
	exit 1
fi

REPO="${MEMORY_REPO:-$HOME/whz-harness}"
[ -d "$REPO/.git" ] || {
	printf 'capture: %s 不是 git 仓库\n' "$REPO" >&2
	exit 1
}

case "$LAYER" in
personal) LAYER_DIR="$REPO" ;;
work) LAYER_DIR="$REPO/work" ;;
*)
	printf 'capture: --layer 只支持 personal 或 work（收到 %s）\n' "$LAYER" >&2
	exit 2
	;;
esac
[ -d "$LAYER_DIR" ] || {
	printf 'capture: 层目录不存在: %s\n' "$LAYER_DIR" >&2
	exit 1
}
if [ "$LAYER" = "personal" ]; then INBOX_REL="notes/inbox.md"; else INBOX_REL="$LAYER/notes/inbox.md"; fi

# 敏感内容守卫：这个仓库在 GitHub 上，内网地址/凭据一律不入库。
if printf '%s' "$TEXT" | grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}|BEGIN [A-Z ]*PRIVATE KEY|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ssh -b '; then
	printf 'capture: 拒绝写入 —— 文本含内网地址/凭据特征。\n' >&2
	printf '         请脱敏后用占位符（如 $AGC64F_HOST），受控原件只记文件名+sha256。\n' >&2
	exit 3
fi

SUMMARY="$(printf '%s' "$TEXT" | head -n 1)"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOSTNAME_="$(hostname)"

if [ -n "$(git -C "$REPO" remote 2>/dev/null)" ]; then
	git -C "$REPO" -c pull.rebase=false pull --ff-only >/dev/null 2>&1 || printf '[capture] pull 失败，继续用本地内容\n'
fi

mkdir -p "$LAYER_DIR/notes"
printf -- '- %s [%s] %s\n' "$STAMP" "$HOSTNAME_" "$SUMMARY" >>"$LAYER_DIR/notes/inbox.md"

# 只提交这个 inbox：仓库里其它未提交改动留给用户自己提交。
if [ -n "$(git -C "$REPO" status --porcelain -- ":!$INBOX_REL")" ]; then
	printf '[capture] 注意：仓库还有其它未提交改动，本次只提交 %s\n' "$INBOX_REL"
fi
git -C "$REPO" add -- "$INBOX_REL"
git -C "$REPO" commit -q -o -m "capture($LAYER): $SUMMARY" -- "$INBOX_REL"

if [ "$NO_PUSH" -eq 0 ] && [ -n "$(git -C "$REPO" remote 2>/dev/null)" ]; then
	git -C "$REPO" push
	printf '[capture] 已记录并推送 (%s): %s\n' "$LAYER" "$SUMMARY"
else
	printf '[capture] 已记录 (%s，未推送): %s\n' "$LAYER" "$SUMMARY"
fi
