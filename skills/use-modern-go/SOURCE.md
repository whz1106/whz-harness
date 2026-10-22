# Upstream source

- Repository: https://github.com/JetBrains/go-modern-guidelines
- Commit: `155dc7ca10da5e1f6c841503086957b1b37f5815`
- Skill path: `plugin/skills/use-modern-go`
- CLI version: `v0.1.1` (pinned by `scripts/VERSION`)
- License: Apache-2.0; the upstream license is included in `LICENSE`.
- Installed: 2026-10-14 with the Codex skill-installer helper.

`SKILL.md` and `scripts/` are unmodified upstream files. `SOURCE.md` records local
provenance; `LICENSE` is copied from the same upstream commit. The wrapper installs
the CLI in the user's cache, outside this repository.

Use `list --file-path <target.go>` to resolve the project's supported Go version.
The project's security, contract, compatibility and behavior requirements remain
in effect; installing this skill does not upgrade its Go toolchain or dependencies.
