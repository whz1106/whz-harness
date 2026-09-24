#!/usr/bin/env bash
# 把记忆仓库的各个「层」注入到各 agent 的用户级配置。
#
# 单一仓库 $HOME/whz-harness，内含四层（每层一个 marker block）：
#   personal-memory  仓库根           规则 + 个人记忆：偏好、工具链、编码/提交习惯、通用坑
#   agent-memory     agent-memory/    记忆系统：索引、项目记忆、捕获区
#   env-memory       env/             业务环境信息与硬约束（kata/vfio/docker），高频更新
#   local-memory     local/           本地投放区（gitignore）：真实地址、受控资料，clone 后自己放
#
# 用法: bash ~/whz-harness/scripts/sync.sh [--no-pull]
# 环境变量: MEMORY_REPO（默认 ~/whz-harness）、MEMORY_LAYERS（默认见下）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGER="$(basename "$(dirname "$SCRIPT_DIR")")"

log() { printf '[sync] %s\n' "$*"; }

# Git Bash / MSYS 常把 HOME 留空，此时回退到 USERPROFILE；两者都不可用时宁可失败，
# 也不要往 "/.omp" 这种假路径写一份没人读的记忆。
if [ -z "${HOME:-}" ] || [ ! -d "${HOME:-}" ]; then
	if [ -n "${USERPROFILE:-}" ]; then
		if command -v cygpath >/dev/null 2>&1; then
			HOME="$(cygpath -u "$USERPROFILE")"
		else
			HOME="$USERPROFILE"
		fi
	fi
fi
if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then
	printf '[sync] 无法确定家目录（HOME=%s USERPROFILE=%s），中止\n' "${HOME:-}" "${USERPROFILE:-}" >&2
	exit 1
fi

REPO="${MEMORY_REPO:-$HOME/whz-harness}"
LAYERS="${MEMORY_LAYERS:-personal-memory: agent-memory:agent-memory env-memory:env local-memory:local}"

[ -d "$REPO/.git" ] || {
	printf '[sync] %s 不是 git 仓库，中止\n' "$REPO" >&2
	exit 1
}

TMPDIR_SYNC="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_SYNC"' EXIT

# 就地替换 marker block；没有 block 就追加，block 之外的内容保持不动。
replace_block() {
	local file="$1" content="$2" name="$3"
	local begin="<!-- BEGIN $name (managed by $MANAGER/scripts/sync; do not edit) -->"
	local end="<!-- END $name -->"
	local tmp
	tmp="$(mktemp)"

	if [ -f "$file" ] && grep -qF "$begin" "$file"; then
		awk -v begin="$begin" -v end="$end" -v cf="$content" '
			BEGIN { while ((getline line < cf) > 0) body = body line "\n"; close(cf) }
			$0 == begin { print begin; printf "%s", body; print end; skip = 1; next }
			skip && $0 == end { skip = 0; next }
			skip { next }
			{ print }
		' "$file" >"$tmp"
	else
		if [ -s "$file" ]; then
			cat "$file" >"$tmp"
			printf '\n' >>"$tmp"
		fi
		{
			echo "$begin"
			cat "$content"
			echo "$end"
		} >>"$tmp"
	fi

	mkdir -p "$(dirname "$file")"
	mv "$tmp" "$file"
	log "wrote ${file/#$HOME/~} ($name)"
}

if [ "${1:-}" != "--no-pull" ]; then
	if [ -n "$(git -C "$REPO" remote 2>/dev/null)" ]; then
		if git -C "$REPO" -c pull.rebase=false pull --ff-only >/dev/null 2>&1; then
			log "pulled $REPO"
		else
			log "pull 失败，继续用本地内容"
		fi
	fi
fi

ACTIVE=""
for spec in $LAYERS; do
	name="${spec%%:*}"
	sub="${spec#*:}"
	dir="$REPO${sub:+/$sub}"
	[ -f "$dir/AGENTS.md" ] || continue

	cat "$dir/AGENTS.md" >"$TMPDIR_SYNC/$name.agents"
	: >"$TMPDIR_SYNC/$name.rules"
	cat "$TMPDIR_SYNC/$name.agents" >"$TMPDIR_SYNC/$name.combined"
	if [ -f "$dir/RULES.md" ]; then
		cat "$dir/RULES.md" >"$TMPDIR_SYNC/$name.rules"
		printf '\n\n' >>"$TMPDIR_SYNC/$name.combined"
		cat "$TMPDIR_SYNC/$name.rules" >>"$TMPDIR_SYNC/$name.combined"
	fi
	ACTIVE="$ACTIVE $name"

	# 技能包：层目录里的 skills/ 是事实来源，逐目录镜像到 omp 用户技能目录。
	if [ -d "$dir/skills" ]; then
		for skill in "$dir"/skills/*/; do
			[ -d "$skill" ] || continue
			dest="$HOME/.omp/agent/skills/$(basename "$skill")"
			mkdir -p "$dest"
			if command -v rsync >/dev/null 2>&1; then
				rsync -a --delete "$skill" "$dest/"
			else
				rm -rf "$dest"
				cp -R "$skill" "$dest"
			fi
			echo "$(basename "$skill")" >>"$TMPDIR_SYNC/skills.new"
			log "skill: $(basename "$skill") ($name)"
		done
	fi
done

if [ -z "$ACTIVE" ]; then
	printf '[sync] 在 %s 下没找到任何层（找的是: %s），中止\n' "$REPO" "$LAYERS" >&2
	exit 1
fi

# 技能镜像清单：仓库里删掉/改名的 skill，在用户技能目录里也要清掉，否则旧 skill 会一直被广告。
SKILL_DIR="$HOME/.omp/agent/skills"
SKILL_MANIFEST="$SKILL_DIR/.whz-harness-mirrored"
if [ -d "$SKILL_DIR" ]; then
	sort -u "$TMPDIR_SYNC/skills.new" 2>/dev/null >"$TMPDIR_SYNC/skills.new.sorted" || : >"$TMPDIR_SYNC/skills.new.sorted"
	if [ -f "$SKILL_MANIFEST" ]; then
		sort -u "$SKILL_MANIFEST" >"$TMPDIR_SYNC/skills.old.sorted"
		for stale in $(comm -23 "$TMPDIR_SYNC/skills.old.sorted" "$TMPDIR_SYNC/skills.new.sorted"); do
			rm -rf "$SKILL_DIR/$stale"
			log "pruned stale skill: $stale"
		done
	fi
	cp "$TMPDIR_SYNC/skills.new.sorted" "$SKILL_MANIFEST"
fi

# omp 侧 AGENTS.md / RULES.md 分开写（RULES.md 是 native sticky rule）；
# 其他工具没有 sticky 概念，注入 AGENTS+RULES 合并全文。
for name in $ACTIVE; do
	replace_block "$HOME/.omp/agent/AGENTS.md" "$TMPDIR_SYNC/$name.agents" "$name"
	if [ -s "$TMPDIR_SYNC/$name.rules" ]; then
		replace_block "$HOME/.omp/agent/RULES.md" "$TMPDIR_SYNC/$name.rules" "$name"
	fi
	for target in ".claude/CLAUDE.md" ".codex/AGENTS.md" ".gemini/GEMINI.md" ".copilot/copilot-instructions.md"; do
		replace_block "$HOME/$target" "$TMPDIR_SYNC/$name.combined" "$name"
	done
done

log "done"
