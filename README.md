# INFERNO-AC

Chat keyword alerts for Assetto Corsa (Custom Shaders Patch apps).

- **INFERNO-Chat Alerts**: the release app. Plays a sound and shows an alert when a chat message matches your keywords, friends or muted keywords.
- **INFERNO-DEV**: a separate developer app, a copy of FERNO-DEV (icon browser). It is not built from this repository.

## Install

1. Clone this repository into a working folder outside the game, for example `Documents\Dev\INFERNO-AC`.
2. Put your sound files in `sounds\` (see below). Only `sounds\DefaultAppSounds\00defaultALERT.wav` is part of the repository.
3. Run `deploy.ps1` (PowerShell). It copies the mod to `apps\lua\INFERNO-ChatAlerts`.

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

Use `-AppsFolder` to target another `apps\lua` folder.

## Migrating from IsuChat Alert

Earlier versions lived in `apps\lua\isuChatAlertLua`. On first start, INFERNO-Chat Alerts copies the settings file and the `Friends`, `Saves` and `SharedKeywords` folders from `Documents\Assetto Corsa\cfg\extension\state\lua\app\` into the new location. It never overwrites existing data, and the old files are left in place. Disable the old app in Custom Shaders Patch to avoid two alerts.

## Sounds

Sound files are not published here: most are copyrighted extracts. Put your own `.wav` or `.mp3` files in `sounds\` or in subfolders of it.

## Repository layout

- `INFERNO-ChatAlerts.lua`: the mod script (source of truth for both apps).
- `manifest.ini`: CSP app and window definitions.
- `deploy.ps1`: deployment to the Assetto Corsa apps folder.
- `icons\`, `icon.png`, `Damier1.png`: UI assets.
- `*.md`: development notes.
