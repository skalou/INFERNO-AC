# Daily Deploy Script - INFERNO-AC to Assetto Corsa
# Copie les mods INFERNO-ChatAlerts et INFERNO-DEV vers le dossier Steam

$steamPath = "C:\Program Files (x86)\Steam\steamapps\common\assettocorsa\apps\lua"
$sourcePath = $PSScriptRoot
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Couleurs
$colorInfo = "Cyan"
$colorSuccess = "Green"
$colorError = "Red"
$colorWarning = "Yellow"

Write-Host "=====================================" -ForegroundColor $colorInfo
Write-Host "INFERNO-AC Daily Deploy Script" -ForegroundColor $colorInfo
Write-Host "   $timestamp" -ForegroundColor Gray
Write-Host "=====================================" -ForegroundColor $colorInfo

# Verifications
Write-Host "`nVerifications..." -ForegroundColor $colorInfo

if (-not (Test-Path $steamPath)) {
    Write-Host "ERREUR: Dossier Steam non trouve" -ForegroundColor $colorError
    Write-Host "   Chemin: $steamPath" -ForegroundColor Gray
    exit 1
}
Write-Host "OK - Dossier Steam trouve" -ForegroundColor $colorSuccess

if (-not (Test-Path "$sourcePath\INFERNO-ChatAlerts.lua")) {
    Write-Host "ERREUR: INFERNO-ChatAlerts.lua non trouve" -ForegroundColor $colorError
    exit 1
}
Write-Host "OK - Sources trouvees" -ForegroundColor $colorSuccess

# Deploiement INFERNO-ChatAlerts
Write-Host "`nDeploiement INFERNO-ChatAlerts..." -ForegroundColor $colorInfo

$alertsTarget = "$steamPath\INFERNO-ChatAlerts"

# Creer/vider le dossier cible
if (Test-Path $alertsTarget) {
    Remove-Item "$alertsTarget" -Recurse -Force | Out-Null
}
New-Item -ItemType Directory -Path $alertsTarget -Force | Out-Null

# Fichiers root essentiels
$rootFiles = @(
    "INFERNO-ChatAlerts.lua",
    "manifest.ini",
    "README.md",
    "icon.png",
    "icon_config.png",
    "flag_en.png"
)

foreach ($file in $rootFiles) {
    if (Test-Path "$sourcePath\$file") {
        Copy-Item "$sourcePath\$file" "$alertsTarget\" -Force
        Write-Host "  OK - $file" -ForegroundColor $colorSuccess
    }
}

# Dossiers essentiels
$folders = @("core", "ui", "lang", "sounds")

foreach ($folder in $folders) {
    if (Test-Path "$sourcePath\$folder") {
        Copy-Item "$sourcePath\$folder" "$alertsTarget\" -Recurse -Force
        $fileCount = (Get-ChildItem "$alertsTarget\$folder" -Recurse -File | Measure-Object).Count
        Write-Host "  OK - $folder/ ($fileCount fichiers)" -ForegroundColor $colorSuccess
    }
}

Write-Host "`nINFERNO-ChatAlerts OK!" -ForegroundColor $colorSuccess

# Deploiement INFERNO-DEV
Write-Host "`nDeploiement INFERNO-DEV..." -ForegroundColor $colorInfo

$devSource = "$sourcePath\INFERNO-DEV"
$devTarget = "$alertsTarget\INFERNO-DEV"

if (Test-Path $devSource) {
    if (Test-Path $devTarget) {
        Remove-Item $devTarget -Recurse -Force | Out-Null
    }
    Copy-Item $devSource $devTarget -Recurse -Force
    $devFiles = (Get-ChildItem $devTarget -Recurse -File | Measure-Object).Count
    Write-Host "  OK - INFERNO-DEV/ ($devFiles fichiers)" -ForegroundColor $colorSuccess
    Write-Host "`nINFERNO-DEV OK!" -ForegroundColor $colorSuccess
} else {
    Write-Host "  ATTENTION - INFERNO-DEV non trouve (optionnel)" -ForegroundColor $colorWarning
}

# Resume
Write-Host "`n========== RESUME ==========" -ForegroundColor $colorInfo

$alertsFileCount = (Get-ChildItem $alertsTarget -Recurse -File | Measure-Object).Count
Write-Host "INFERNO-ChatAlerts: $alertsFileCount fichiers" -ForegroundColor Cyan
Write-Host "   $alertsTarget" -ForegroundColor Gray

if (Test-Path $devTarget) {
    $devFileCount = (Get-ChildItem $devTarget -Recurse -File | Measure-Object).Count
    Write-Host "INFERNO-DEV: $devFileCount fichiers" -ForegroundColor Cyan
    Write-Host "   $devTarget" -ForegroundColor Gray
}

Write-Host "`nDEPLOIEMENT OK!" -ForegroundColor $colorSuccess
Write-Host "Lancez Assetto Corsa pour tester les modifications" -ForegroundColor $colorInfo
Write-Host "=============================" -ForegroundColor $colorInfo
