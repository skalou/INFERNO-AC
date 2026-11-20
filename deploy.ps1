<#
.SYNOPSIS
Deploys the INFERNO mod into the Assetto Corsa apps folder.

.DESCRIPTION
Copies this folder to apps\lua\INFERNO-ChatAlerts (release app) and builds
apps\lua\INFERNO-DEV (dev app) from the same source, renamed in the Lua table
App and in manifest.ini. Files are overwritten, nothing is deleted. Personal
data (ServerSharedKeywords, friends, saves) is never copied.
#>
param(
	[string]$AppsFolder = 'C:\Program Files (x86)\Steam\steamapps\common\assettocorsa\apps\lua',
	[switch]$SkipDev
)

$ErrorActionPreference = 'Stop'
$source = $PSScriptRoot
$excludeDirs = @('.git', '.vs', 'session-state', 'ServerSharedKeywords')
$excludeFiles = @('debug_log.txt', '*.code-workspace', 'Ska-error-bis.txt', '.gitignore', '.gitattributes', 'README.md', 'deploy.ps1')

function Copy-ModFiles([string]$destination) {
	New-Item -ItemType Directory -Force -Path $destination | Out-Null
	& robocopy $source $destination /E /XD @excludeDirs /XF @excludeFiles /NFL /NDL /NJH /NJS /NP | Out-Null
	if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE for $destination" }
}

# Each edit is @(oldText, newText, expectedCount). Keeps the file's BOM and line endings.
function Update-Text([string]$path, [object[]]$edits) {
	$bytes = [IO.File]::ReadAllBytes($path)
	$hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
	$text = [Text.Encoding]::UTF8.GetString($bytes)
	if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
	foreach ($edit in $edits) {
		$count = ([regex]::Matches($text, [regex]::Escape($edit[0]))).Count
		if ($count -ne $edit[2]) { throw "Expected $($edit[2]) match(es) of '$($edit[0])' in $path, found $count" }
		$text = $text.Replace($edit[0], $edit[1])
	}
	[IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($hasBom)))
}

$release = Join-Path $AppsFolder 'INFERNO-ChatAlerts'
Copy-ModFiles $release
Write-Host "Release app deployed to $release"

if (-not $SkipDev) {
	$dev = Join-Path $AppsFolder 'INFERNO-DEV'
	Copy-ModFiles $dev
	$devLua = Join-Path $dev 'INFERNO-DEV.lua'
	Copy-Item (Join-Path $dev 'INFERNO-ChatAlerts.lua') $devLua -Force
	Remove-Item (Join-Path $dev 'INFERNO-ChatAlerts.lua')
	Update-Text $devLua @(
		@("  folderName = 'INFERNO-ChatAlerts',", "  folderName = 'INFERNO-DEV',", 1),
		@("  displayName = 'INFERNO-Chat Alerts',", "  displayName = 'INFERNO-DEV',", 1),
		@("  migrateFrom = { 'INFERNO-ChatAlerts', 'isuChatAlertLua' },", "  migrateFrom = { 'INFERNO-DEV' },", 1)
	)
	Update-Text (Join-Path $dev 'manifest.ini') @(,@('NAME=INFERNO-Chat Alerts', 'NAME=INFERNO-DEV', 3))
	Write-Host "Dev app deployed to $dev"
}
