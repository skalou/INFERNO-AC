# Release Build Script - Create GitHub release ZIP with proper folder structure
# Usage: powershell -ExecutionPolicy Bypass -File .\release-build.ps1
# Output: INFERNO-AC-X.Y.Z.zip ready to upload to GitHub release assets

param(
    [string]$Version = "0.5.0"  # Edit core\paths.lua and update this for each release
)

Write-Host "Release Builder for INFERNO-AC" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host ""

$tempDir = "C:\temp\release-build\assettocorsa\apps\lua\INFERNO-ChatAlerts"
$zipName = "INFERNO-AC-$Version.zip"

# Cleanup old build
if (Test-Path "C:\temp\release-build") { 
    Remove-Item "C:\temp\release-build" -Recurse -Force 
}
if (Test-Path $zipName) { 
    Remove-Item $zipName -Force 
}

# Create folder structure: assettocorsa\apps\lua\INFERNO-ChatAlerts
$null = New-Item -ItemType Directory -Path $tempDir -Force
Write-Host "? Created release folder structure" -ForegroundColor Green
Write-Host ""

# Copy essential files only
Write-Host "Adding files:" -ForegroundColor Cyan
Copy-Item "INFERNO-ChatAlerts.lua" $tempDir
Copy-Item "manifest.ini" $tempDir
Copy-Item "README.md" $tempDir
Write-Host "  + INFERNO-ChatAlerts.lua" -ForegroundColor Gray
Write-Host "  + manifest.ini" -ForegroundColor Gray
Write-Host "  + README.md" -ForegroundColor Gray

# Copy essential directories
Write-Host ""
Write-Host "Adding directories:" -ForegroundColor Cyan
Copy-Item "core" -Destination $tempDir -Recurse
Copy-Item "lang" -Destination $tempDir -Recurse
Copy-Item "ui" -Destination $tempDir -Recurse
Write-Host "  + core/" -ForegroundColor Gray
Write-Host "  + lang/" -ForegroundColor Gray
Write-Host "  + ui/" -ForegroundColor Gray

# Copy only DefaultAppSounds (not the entire sounds folder)
Write-Host ""
Write-Host "Adding sounds:" -ForegroundColor Cyan
$soundsDest = Join-Path $tempDir "sounds"
$null = New-Item -ItemType Directory -Path $soundsDest -Force
Copy-Item "sounds\DefaultAppSounds" -Destination $soundsDest -Recurse
Copy-Item "sounds\MyCustomSoundsEXEMPLE" -Destination $soundsDest -Recurse
Write-Host "  + sounds/DefaultAppSounds/" -ForegroundColor Gray
Write-Host "  + sounds/MyCustomSoundsEXEMPLE/" -ForegroundColor Gray

# Copy required icon files
Write-Host ""
Write-Host "Adding icons:" -ForegroundColor Cyan
Copy-Item "icon.png" $tempDir
Copy-Item "flag_en.png" $tempDir
Write-Host "  + icon.png" -ForegroundColor Gray
Write-Host "  + flag_en.png" -ForegroundColor Gray

# Copy INFERNO-DEV app (developer tools)
Write-Host ""
Write-Host "Adding developer app:" -ForegroundColor Cyan
Copy-Item "INFERNO-DEV" -Destination $tempDir -Recurse
Write-Host "  + INFERNO-DEV/" -ForegroundColor Gray

# Create ZIP archive
Write-Host ""
Write-Host "Creating ZIP archive..." -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory("C:\temp\release-build", $zipName, [System.IO.Compression.CompressionLevel]::Optimal, $false)

# Display ZIP contents
Write-Host ""
Write-Host "ZIP structure (ready for player installation):" -ForegroundColor Green
$zip = [System.IO.Compression.ZipFile]::OpenRead($zipName)
$zip.Entries | Where-Object { $_.FullName -notmatch '/$' } | ForEach-Object { 
    Write-Host "  $($_.FullName)" -ForegroundColor Gray 
}
$zip.Dispose()

# Cleanup temp directory
Remove-Item "C:\temp\release-build" -Recurse -Force

Write-Host ""
Write-Host "SUCCESS!" -ForegroundColor Green
Write-Host "File: $zipName" -ForegroundColor Yellow
Write-Host ""
Write-Host "Installation: Player extracts this ZIP in their Assetto Corsa root folder:" -ForegroundColor Cyan
Write-Host "  assettocorsa\apps\lua\INFERNO-ChatAlerts\ will be created automatically" -ForegroundColor Gray
Write-Host ""
Write-Host "Next: Upload $zipName to GitHub release assets" -ForegroundColor Yellow
