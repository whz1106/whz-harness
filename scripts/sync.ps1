<#
把记忆仓库的各个「层」注入到各 agent 的用户级配置。

单一仓库 $HOME\whz-harness，内含四层（每层一个 marker block）：
  personal-memory  仓库根           规则 + 个人记忆：偏好、工具链、编码/提交习惯、通用坑
  agent-memory     agent-memory\    记忆系统：索引、项目记忆、捕获区
  machines-memory       machines\             业务环境信息与硬约束（kata/vfio/docker），高频更新
  local-memory     local\           本地投放区（gitignore）：真实地址、受控资料，clone 后自己放

用法: powershell -ExecutionPolicy Bypass -File $HOME\whz-harness\scripts\sync.ps1 [-NoPull]
环境变量: MEMORY_REPO（默认 ~\whz-harness）、MEMORY_LAYERS（默认见下）
#>
#Requires -Version 5.1
[CmdletBinding()]
param([switch]$NoPull)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Manager = Split-Path -Leaf (Split-Path -Parent $ScriptDir)
$HomeDir = $env:USERPROFILE

function Write-Log([string]$Message) { Write-Host "[sync] $Message" }

$Repo = if ($env:MEMORY_REPO) { $env:MEMORY_REPO } else { Join-Path $HomeDir 'whz-harness' }
$Layers = if ($env:MEMORY_LAYERS) { $env:MEMORY_LAYERS } else { 'personal-memory: agent-memory:agent-memory machines-memory:machines local-memory:local' }
$SkillDir = Join-Path $HomeDir '.omp\agent\skills'
$Mirrored = @()

if (-not (Test-Path -LiteralPath (Join-Path $Repo '.git'))) { throw "$Repo 不是 git 仓库" }
$Repo = (Resolve-Path -LiteralPath $Repo).ProviderPath

# 就地替换 marker block；没有 block 就追加，block 之外的内容保持不动。
function Set-ManagedBlock {
	param(
		[Parameter(Mandatory = $true)][string]$Path,
		[Parameter(Mandatory = $true)][string]$Content,
		[Parameter(Mandatory = $true)][string]$Name
	)
	$begin = "<!-- BEGIN $Name (managed by $Manager/scripts/sync; do not edit) -->"
	$end = "<!-- END $Name -->"

	$dir = Split-Path -Parent $Path
	if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

	$block = $begin + "`r`n" + $Content.TrimEnd() + "`r`n" + $end
	$existing = ''
	if (Test-Path -LiteralPath $Path) { $existing = [System.IO.File]::ReadAllText($Path) }

	if ($existing.Contains($begin)) {
		$start = $existing.IndexOf($begin)
		$endIndex = $existing.IndexOf($end, $start)
		if ($endIndex -lt 0) { throw "marker block 不完整（缺少 END）: $Path ($Name)" }
		$updated = $existing.Substring(0, $start) + $block + $existing.Substring($endIndex + $end.Length)
	}
	elseif ([string]::IsNullOrWhiteSpace($existing)) {
		$updated = $block + "`r`n"
	}
	else {
		$updated = $existing.TrimEnd() + "`r`n`r`n" + $block + "`r`n"
	}

	[System.IO.File]::WriteAllText($Path, $updated, (New-Object System.Text.UTF8Encoding($false)))
	Write-Log ("wrote " + $Path.Replace($HomeDir, '~') + " ($Name)")
}

if (-not $NoPull) {
	$remotes = @(& git -C $Repo remote)
	$hasRemote = ($remotes | Where-Object { $_ -ne '' }).Count -gt 0
	if ($hasRemote) {
		# 原生命令的 stderr 不做重定向：PS 5.1 会把重定向后的 stderr 变成 ErrorRecord。
		& git -C $Repo -c pull.rebase=false pull --ff-only
		if ($LASTEXITCODE -ne 0) { Write-Log 'pull 失败，继续用本地内容' } else { Write-Log "pulled $Repo" }
	}
}

$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("omp-sync-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

try {
	$Active = @()
	foreach ($spec in ($Layers -split '\s+' | Where-Object { $_ })) {
		$name = $spec.Split(':')[0]
		$sub = if ($spec.Contains(':')) { $spec.Substring($spec.IndexOf(':') + 1) } else { '' }
		$dir = if ($sub) { Join-Path $Repo $sub } else { $Repo }
		$agentsPath = Join-Path $dir 'AGENTS.md'
		if (-not (Test-Path -LiteralPath $agentsPath)) { continue }

		$agentsText = '> whz-harness 根目录（当前机器）：`' + $Repo + '`。下文相对路径均以此为基准。' + "`r`n`r`n" + [System.IO.File]::ReadAllText($agentsPath)
		$rulesText = ''
		$rulesPath = Join-Path $dir 'RULES.md'
		if (Test-Path -LiteralPath $rulesPath) { $rulesText = [System.IO.File]::ReadAllText($rulesPath) }

		$combined = $agentsText.TrimEnd()
		if ($rulesText.Trim()) { $combined = $combined + "`r`n`r`n" + $rulesText.TrimEnd() }

		$enc = New-Object System.Text.UTF8Encoding($false)
		[System.IO.File]::WriteAllText((Join-Path $TmpDir "$name.agents"), $agentsText, $enc)
		[System.IO.File]::WriteAllText((Join-Path $TmpDir "$name.rules"), $rulesText, $enc)
		[System.IO.File]::WriteAllText((Join-Path $TmpDir "$name.combined"), $combined, $enc)
		$Active += $name

		# 技能包：层目录里的 skills\ 是事实来源，逐目录镜像到 omp 用户技能目录。
		$srcSkills = Join-Path $dir 'skills'
		if (Test-Path -LiteralPath $srcSkills) {
			New-Item -ItemType Directory -Force -Path $SkillDir | Out-Null
			foreach ($skill in Get-ChildItem -LiteralPath $srcSkills -Directory) {
				$dest = Join-Path $SkillDir $skill.Name
				& robocopy $skill.FullName $dest /MIR /NFL /NDL /NJH /NJS /NP /R:2 /W:1 | Out-Null
				if ($LASTEXITCODE -ge 8) { throw "robocopy 失败: $($skill.Name) (exit $LASTEXITCODE)" }
				$Mirrored += $skill.Name
				Write-Log "skill: $($skill.Name) ($name)"
			}
		}
	}

	if ($Active.Count -eq 0) { throw "在 $Repo 下没找到任何层（找的是: $Layers）" }

	# 技能镜像清单：仓库里删掉/改名的 skill，在用户技能目录里也要清掉，否则旧 skill 会一直被广告。
	if (Test-Path -LiteralPath $SkillDir) {
		$manifest = Join-Path $SkillDir '.whz-harness-mirrored'
		if (Test-Path -LiteralPath $manifest) {
			foreach ($old in (Get-Content -LiteralPath $manifest | Where-Object { $_ -ne '' })) {
				if ($Mirrored -notcontains $old) {
					Remove-Item -LiteralPath (Join-Path $SkillDir $old) -Recurse -Force -ErrorAction SilentlyContinue
					Write-Log "pruned stale skill: $old"
				}
			}
		}
		[System.IO.File]::WriteAllLines($manifest, ($Mirrored | Sort-Object -Unique), (New-Object System.Text.UTF8Encoding($false)))
	}

	# omp 侧 AGENTS.md / RULES.md 分开写（RULES.md 是 native sticky rule）；
	# 其他工具没有 sticky 概念，注入 AGENTS+RULES 合并全文。
	foreach ($name in $Active) {
		$blockName = $name
		$rulesFile = Join-Path $TmpDir "$name.rules"
		Set-ManagedBlock -Path (Join-Path $HomeDir '.omp\agent\AGENTS.md') -Content ([System.IO.File]::ReadAllText((Join-Path $TmpDir "$name.agents"))) -Name $blockName
		if ((Get-Item -LiteralPath $rulesFile).Length -gt 0) {
			Set-ManagedBlock -Path (Join-Path $HomeDir '.omp\agent\RULES.md') -Content ([System.IO.File]::ReadAllText($rulesFile)) -Name $blockName
		}
		foreach ($target in '.claude\CLAUDE.md', '.codex\AGENTS.md', '.gemini\GEMINI.md', '.copilot\copilot-instructions.md') {
			Set-ManagedBlock -Path (Join-Path $HomeDir $target) -Content ([System.IO.File]::ReadAllText((Join-Path $TmpDir "$name.combined"))) -Name $blockName
		}
	}

	Write-Log 'done'
}
finally {
	Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
