<#
.SYNOPSIS
Deploys the INFERNO apps into the Assetto Corsa apps folder.

.DESCRIPTION
Copies this folder to apps\lua\INFERNO-ChatAlerts (release app) and the
INFERNO-DEV folder to apps\lua\INFERNO-DEV (developer app). Files are
overwritten, nothing is deleted. Personal data (ServerSharedKeywords, friends,
saves) and development notes are never copied.
#>
param(
	[string]$AppsFolder = 'C:\Program Files (x86)\Steam\steamapps\common\assettocorsa\apps\lua'
)

$ErrorActionPreference = 'Stop'
$source = $PSScriptRoot
$excludeDirs = @('.git', '.vs', 'session-state', 'ServerSharedKeywords', 'tools', 'icons', 'INFERNO-DEV')
$excludeFiles = @('debug_log.txt', '*.code-workspace', '.gitignore', '.gitattributes', '*.md', 'deploy.ps1')

function Copy-ModFiles([string]$from, [string]$destination, [string[]]$dirs) {
	New-Item -ItemType Directory -Force -Path $destination | Out-Null
	& robocopy $from $destination /E /XD @dirs /XF @excludeFiles /NFL /NDL /NJH /NJS /NP | Out-Null
	if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE for $destination" }
}

$release = Join-Path $AppsFolder 'INFERNO-ChatAlerts'
Copy-ModFiles $source $release $excludeDirs
Copy-Item -LiteralPath (Join-Path $source 'icons\INFERNO-ChatAlerts-icons-02.png') -Destination (Join-Path $release 'icon.png') -Force
Copy-Item -LiteralPath (Join-Path $source 'icons\great-britain-flag-256x154px.png') -Destination (Join-Path $release 'flag_en.png') -Force
Write-Host "Release app deployed to $release"

$dev = Join-Path $AppsFolder 'INFERNO-DEV'
Copy-ModFiles (Join-Path $source 'INFERNO-DEV') $dev @()
Write-Host "Developer app deployed to $dev"
