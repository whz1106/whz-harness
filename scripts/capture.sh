#!/usr/bin/env bash
# 追加一条捕获到捕获区 agent-memory/notes/inbox.md，提交并推送。
#
#   capture.sh "要记住的事实" [--tag <机器/项目>] [--no-push]
#
# 捕获区只有一个（设计如此）：整理后由人/agent 把结论提升到 personal.md / projects/ / machines/，
# 再删掉 inbox 里那一行。--tag 只是给条目加个前缀，方便事后分类，不改变落盘位置。
# 这个仓库是公开仓，所以写入前一律做敏感内容守卫：内网地址/凭据特征直接拒绝。
set -euo pipefail

TEXT=""
TAG=""
NO_PUSH=0

while [ $# -gt 0 ]; do
	case "$1" in
	--tag)
		TAG="${2:-}"
		[ -n "$TAG" ] || {
			printf 'capture: --tag 需要一个参数\n' >&2
			exit 2
		}
		shift 2
		;;
	--tag=*)
		TAG="${1#--tag=}"
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
	printf '用法: capture.sh "要记住的事实" [--tag <机器/项目>] [--no-push]\n' >&2
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

INBOX_REL="agent-memory/notes/inbox.md"
[ -d "$REPO/agent-memory" ] || {
	printf 'capture: 捕获区目录不存在: %s/agent-memory\n' "$REPO" >&2
	exit 1
}

# 敏感内容守卫：这个仓库是公开仓，完整 IP / 凭据一律不入库。
if printf '%s' "$TEXT" | grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}|BEGIN [A-Z ]*PRIVATE KEY|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ssh -b '; then
	printf 'capture: 拒绝写入 —— 文本含完整 IP / 凭据特征。\n' >&2
	printf '         完整 IP 只写网段（172.18.5.***），真值放 local/ 或 ~/.ssh/config；受控原件只记文件名+sha256。\n' >&2
	exit 3
fi

SUMMARY="$(printf '%s' "$TEXT" | head -n 1)"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOSTNAME_="$(hostname)"
PREFIX=""
[ -n "$TAG" ] && PREFIX="[$TAG] "

if [ -n "$(git -C "$REPO" remote 2>/dev/null)" ]; then
	git -C "$REPO" -c pull.rebase=false pull --ff-only >/dev/null 2>&1 || printf '[capture] pull 失败，继续用本地内容\n'
fi

mkdir -p "$REPO/agent-memory/notes"
printf -- '- %s [%s] %s%s\n' "$STAMP" "$HOSTNAME_" "$PREFIX" "$SUMMARY" >>"$REPO/$INBOX_REL"

# 只提交 inbox：仓库里其它未提交改动留给用户自己提交。
if [ -n "$(git -C "$REPO" status --porcelain -- ":!$INBOX_REL")" ]; then
	printf '[capture] 注意：仓库还有其它未提交改动，本次只提交 %s\n' "$INBOX_REL"
fi
git -C "$REPO" add -- "$INBOX_REL"
git -C "$REPO" commit -q -o -m "capture: $SUMMARY" -- "$INBOX_REL"

if [ "$NO_PUSH" -eq 0 ] && [ -n "$(git -C "$REPO" remote 2>/dev/null)" ]; then
	git -C "$REPO" push
	printf '[capture] 已记录并推送: %s\n' "$SUMMARY"
else
	printf '[capture] 已记录（未推送）: %s\n' "$SUMMARY"
fi
