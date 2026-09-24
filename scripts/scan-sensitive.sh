#!/usr/bin/env bash
# 扫描仓库里的敏感内容：非 loopback IP、凭据特征、可选的本地黑名单词。
#
#   bash ~/whz-harness/scripts/scan-sensitive.sh [路径...]
#   bash ~/whz-harness/scripts/scan-sensitive.sh --install-hook
#
# 退出码：0 = 干净；1 = 有命中。
# 本地黑名单：$HOME/.whz-harness-denylist，每行一个词（客户名、真实地址等）。
# 该文件**不入库**，所以黑名单词本身也不会进仓库。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"

if [ "${1:-}" = "--install-hook" ]; then
	git -C "$REPO" config core.hooksPath .githooks
	printf 'scan-sensitive: 已设置 core.hooksPath=.githooks（提交前自动扫描）\n'
	exit 0
fi

TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=("$REPO")

IP_RE='([0-9]{1,3}\.){3}[0-9]{1,3}'
IP_ALLOW='127\.0\.0\.1|0\.0\.0\.0|255\.255|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.'
CRED_RE='BEGIN [A-Z ]*PRIVATE KEY|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}'

hits=0
report() { hits=1; printf '  %s:%s: %s\n' "${1#"$REPO"/}" "$2" "$3"; }

# 逐行解析 grep -rnE 的 "文件:行号:内容"（文件路径可能含冒号，所以从右侧按数字行号切）
scan() {
	local re="$1" label="$2" line file lineno content
	while IFS= read -r line; do
		if [[ "$line" =~ ^(.+):([0-9]+):(.*)$ ]]; then
			file="${BASH_REMATCH[1]}"
			lineno="${BASH_REMATCH[2]}"
			content="${BASH_REMATCH[3]}"
		else
			continue
		fi
		case "/$file" in */.git/*) continue ;; esac
		case "$file" in */scripts/scan-sensitive.sh) continue ;; esac
		# local/ 是有意保留的本地投放区（真实地址、受控资料），本就不该入库，跳过
		case "/$file" in */local/*) continue ;; esac
		report "$file" "$lineno" "[$label] $(printf '%s' "$content" | cut -c1-100)"
	done
}

printf 'scan-sensitive: 扫描 %s\n' "${TARGETS[*]}"

scan "$IP_RE" "非 loopback IP" < <(grep -rnE "$IP_RE" "${TARGETS[@]}" 2>/dev/null | grep -vE "$IP_ALLOW")
scan "$CRED_RE" "凭据特征" < <(grep -rnE "$CRED_RE" "${TARGETS[@]}" 2>/dev/null)

DENYLIST="${HOME:-}/.whz-harness-denylist"
if [ -n "${HOME:-}" ] && [ -f "$DENYLIST" ]; then
	while IFS= read -r term; do
		[ -n "$term" ] || continue
		scan "$(printf '%s' "$term" | sed 's/[][\.*^$]/\\&/g')" "本地黑名单" < <(grep -rnF -- "$term" "${TARGETS[@]}" 2>/dev/null)
	done <"$DENYLIST"
fi

if [ "$hits" -eq 0 ]; then
	printf 'scan-sensitive: 干净\n'
	exit 0
fi
printf 'scan-sensitive: 发现可疑内容，请脱敏后再提交（内网地址用 $AGC64F_HOST 这类占位符）\n'
exit 1
