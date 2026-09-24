<#
追加一条捕获到捕获区 agent-memory\notes\inbox.md，提交并推送。

用法:
  powershell -ExecutionPolicy Bypass -File $HOME\whz-harness\scripts\capture.ps1 -Text "要记住的事实"
  ... -Tag <机器/项目>        # 给条目加前缀，方便事后分类
  ... -NoPush

捕获区只有一个（设计如此）：整理后把结论提升到 personal.md / projects\ / machines\，再删掉 inbox 里那一行。
这个仓库是公开仓，所以写入前一律做敏感内容守卫：完整 IP / 凭据特征直接拒绝。
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true, Position = 0)][string]$Text,
	[string]$Tag = '',
	[switch]$NoPush
)

$ErrorActionPreference = 'Stop'

$HomeDir = $env:USERPROFILE
$Repo = if ($env:MEMORY_REPO) { $env:MEMORY_REPO } else { Join-Path $HomeDir 'whz-harness' }
if (-not (Test-Path -LiteralPath (Join-Path $Repo '.git'))) { throw "$Repo 不是 git 仓库" }

$InboxRel = 'agent-memory/notes/inbox.md'
if (-not (Test-Path -LiteralPath (Join-Path $Repo 'agent-memory'))) { throw "$Repo\agent-memory 不存在" }

# 敏感内容守卫：这个仓库是公开仓，完整 IP / 凭据一律不入库。
$sensitive = '([0-9]{1,3}\.){3}[0-9]{1,3}|BEGIN [A-Z ]*PRIVATE KEY|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|ssh -b '
if ($Text -match $sensitive) {
	Write-Error 'capture: 拒绝写入 —— 文本含完整 IP / 凭据特征。完整 IP 只写网段（172.18.5.***），真值放 local\ 或 ~\.ssh\config；受控原件只记文件名+sha256。'
	exit 3
}

$Summary = ($Text -split "`r?`n")[0]
$Stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$Prefix = if ($Tag) { "[$Tag] " } else { '' }

$remotes = @(& git -C $Repo remote)
$hasRemote = ($remotes | Where-Object { $_ -ne '' }).Count -gt 0

if ($hasRemote) {
	& git -C $Repo -c pull.rebase=false pull --ff-only
	if ($LASTEXITCODE -ne 0) { Write-Host '[capture] pull 失败，继续用本地内容' }
}

$notesDir = Join-Path $Repo 'agent-memory\notes'
if (-not (Test-Path -LiteralPath $notesDir)) { New-Item -ItemType Directory -Force -Path $notesDir | Out-Null }
$inbox = Join-Path $Repo 'agent-memory\notes\inbox.md'
$entry = ("- {0} [{1}] {2}{3}" -f $Stamp, $env:COMPUTERNAME, $Prefix, $Summary) + "`r`n"
[System.IO.File]::AppendAllText($inbox, $entry, (New-Object System.Text.UTF8Encoding($false)))

# 只提交 inbox：仓库里其它未提交改动留给用户自己提交。
$other = @(& git -C $Repo status --porcelain -- ":!$InboxRel")
if (($other | Where-Object { $_ -ne '' }).Count -gt 0) {
	Write-Host "[capture] 注意：仓库还有其它未提交改动，本次只提交 $InboxRel"
}
& git -C $Repo add -- $InboxRel
& git -C $Repo commit -q -o -m "capture: $Summary" -- $InboxRel
if ($LASTEXITCODE -ne 0) { throw 'git commit 失败' }

if (-not $NoPush -and $hasRemote) {
	& git -C $Repo push
	if ($LASTEXITCODE -ne 0) { throw 'git push 失败' }
	Write-Host "[capture] 已记录并推送: $Summary"
}
else {
	Write-Host "[capture] 已记录（未推送）: $Summary"
}
