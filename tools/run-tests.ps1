<#
.SYNOPSIS
Runs the INFERNO test tools: static check, LuaJIT compile, and the stubbed CSP harness.

.DESCRIPTION
Needs Node.js (with `npm install` run once in tools\) and LuaJIT 2.1
(winget install DEVCOM.LuaJIT). The full harness trace is written to
tools\last-run.txt. Exit code 1 if anything fails.
#>
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$luajitDir = Join-Path $env:LOCALAPPDATA 'Programs\LuaJIT\bin'
if (-not (Get-Command luajit -ErrorAction SilentlyContinue) -and (Test-Path $luajitDir)) { $env:Path += ";$luajitDir" }
$failed = $false

Write-Host '== Static check'
node (Join-Path $PSScriptRoot 'check.js') $repo
if ($LASTEXITCODE -ne 0) { $failed = $true }

Write-Host '== LuaJIT compile'
Get-ChildItem $repo -Recurse -Filter *.lua | Where-Object { $_.FullName -notmatch '\\(tools|node_modules|\.git)\\' } | ForEach-Object {
	$result = luajit -e "local f, e = loadfile([[$($_.FullName)]]); io.write(f and 'ok' or e)"
	if ($result -ne 'ok') { Write-Host "FAIL $result"; $failed = $true }
}

Write-Host '== Harness'
$trace = Join-Path $PSScriptRoot 'last-run.txt'
Push-Location $repo
luajit (Join-Path $PSScriptRoot 'harness.lua') (Join-Path $repo 'INFERNO-ChatAlerts.lua') > $trace 2>&1
$harnessExit = $LASTEXITCODE
Pop-Location
Get-Content $trace | Where-Object { $_ -match '^(ERROR|FAIL|== summary)' }
if ($harnessExit -ne 0) { $failed = $true }

if ($failed) { Write-Host 'TESTS FAILED'; exit 1 }
Write-Host 'ALL TESTS PASSED'
