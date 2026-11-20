# INFERNO-AC

Chat keyword alerts for Assetto Corsa (Custom Shaders Patch apps).

- **INFERNO-Chat Alerts**: the release app. Plays a sound and shows an alert when a chat message matches your keywords, friends or muted keywords.
- **INFERNO-DEV**: a developer window of the same app (icon browser). Enable it from the CSP apps list like the other windows.

## Install

1. Clone this repository into a working folder outside the game, for example `Documents\Dev\INFERNO-AC`.
2. Put your sound files in `sounds\` (see below). Only `sounds\DefaultAppSounds\00defaultALERT.wav` is part of the repository.
3. Run `deploy.ps1` (PowerShell). It copies the mod to `apps\lua\INFERNO-ChatAlerts`.

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

Use `-AppsFolder` to target another `apps\lua` folder.

## Data from IsuChat Alert

Version 0.4.0 starts from scratch: it does not read the settings, backups or shared keyword lists of IsuChat Alert (`apps\lua\isuChatAlertLua`) or of earlier INFERNO test builds. Disable the old app in Custom Shaders Patch to avoid two alerts. To bring keywords over, write them in a `.txt` file (one keyword per line) in `apps\lua\INFERNO-ChatAlerts\ServerSharedKeywords\` (in the game folder) and use **Profiles > Keyword list from a saved server**.

## Tests

`tools\run-tests.ps1` runs a static check, compiles every file with LuaJIT and runs the app against stubbed CSP functions. One-time setup: install Node.js and LuaJIT (`winget install DEVCOM.LuaJIT`), then run `npm install` in `tools\`.

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run-tests.ps1
```

## Sounds

Sound files are not published here: most are copyrighted extracts. Put your own `.wav` or `.mp3` files in `sounds\` or in subfolders of it.

## Repository layout

- `INFERNO-ChatAlerts.lua`: entry point. Loads the modules and connects them to CSP.
- `core\`: logic (settings, keywords, sounds, chat handling, profiles, backups, sharing).
- `ui\`: windows and settings tabs.
- `dev\`: the INFERNO-DEV window.
- `tools\`: test tools (not deployed).
- `manifest.ini`: CSP app and window definitions.
- `deploy.ps1`: deployment to the Assetto Corsa apps folder.
- `icons\dev.png`, `icon.png`: UI assets (`icons\dev.png` is the INFERNO-DEV window icon).
- `*.md`: development notes.
