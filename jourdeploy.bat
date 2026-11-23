@echo off
REM INFERNO-AC Daily Deploy - Batch Launcher
REM Lance le script PowerShell jourdeploy.ps1

setlocal enabledelayedexpansion

REM Chemin du script
set "scriptPath=%~dp0jourdeploy.ps1"

REM Verification
if not exist "%scriptPath%" (
    echo.
    echo ERREUR: jourdeploy.ps1 non trouve a: %scriptPath%
    echo.
    pause
    exit /b 1
)

REM Lancer PowerShell avec le script
echo.
echo Lancement du deploiement INFERNO-AC...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%"

REM Pause pour voir le resultat
echo.
pause
