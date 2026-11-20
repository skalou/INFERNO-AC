<#
.SYNOPSIS
Deploys the INFERNO mod into the Assetto Corsa apps folder.

.DESCRIPTION
Copies this folder to apps\lua\INFERNO-ChatAlerts (release app). Files are
overwritten, nothing is deleted. Personal data (ServerSharedKeywords, friends,
saves) is never copied. INFERNO-DEV is not built here: it is a separate app
copied from FERNO-DEV.
#>
param(
	[string]$AppsFolder = 'C:\Program Files (x86)\Steam\steamapps\common\assettocorsa\apps\lua'
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

$release = Join-Path $AppsFolder 'INFERNO-ChatAlerts'
Copy-ModFiles $release
Write-Host "Release app deployed to $release"
