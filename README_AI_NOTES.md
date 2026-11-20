# AI Conversation Notes

## Changelog draft: 0.4.0-beta (not released yet)

First INFERNO-AC release, after IsuChat Alert 2.8.2 (0.3.0 was planned but never released). It starts from scratch: no data from IsuChat Alert or earlier test builds is read.

- Renamed IsuChat Alert to INFERNO-Chat Alerts (`apps\lua\INFERNO-ChatAlerts`), author INFERNO-SKA. Version shown as `0.4.0-beta` in Tools > Debug.
- No compatibility with old data: settings use a new storage prefix (`INFERNO_`), and old backups and shared keyword files are rejected with a message. Keywords can be brought over through a `.txt` list (one keyword per line).
- New file formats: settings backups `INFERNO-Settings` v2, shared keyword lists `INFERNO-KeywordList` v1. A file is read only if its format id and version match exactly.
- No default keywords: a new install or a keyword reset starts with only the built-in "your name" and "friends" entries. Default backup name: `My settings`.
- Shared keyword lists keep the server address and port (they identify the server; every player who joins knows the IP). They no longer contain the profile key, which only repeated the IP and port. The creator's driver name stays, because the import shows who shared a list.
- Code split from one 3 900-line script into `core/`, `ui/` and `dev/` modules.
- INFERNO-DEV (icon browser) is now a window of the app instead of a separate app.
- Fixed: debug log spam. Validating a keyword profile wrote one `[TRACE]` line to `debug_log.txt` per character while debug mode was on.
- Removed: the gear icon in the top-left corner of the alert window. It never worked: it showed `âš™` (double-encoded UTF-8, wrong `ui.drawText` arguments), and its click test compared screen coordinates (`ui.mousePos`) with a window-local rectangle. Open the settings from the CSP apps bar.
- Checked: `ac.setWindowOpen` is a valid CSP function. Its call in the test preview (opens the alert window) is kept.
- Test tools added in `tools\` (static check, LuaJIT harness with CSP stubs and targeted checks).

## File formats (0.4.0)

- Versions live in `core/paths.lua`: `App.version` (`0.4.0`, written into files), `App.channel` (`beta`), `App.versionLabel`. Update `manifest.ini` `VERSION` together with `App.version`.
- Settings backup (`Saves\<name>.json`, server auto-save `Saves\Servers\<ip>_<port>.json`): JSON envelope `{ format = 'INFERNO-Settings', formatVersion = 2, appVersion, payload, checksum }`, built by `encodeBackup()` and read by `decodeBackupData()` in `core/backup.lua`. `payload` is the JSON snapshot from `captureAllSettings()`; server files leave out the keys in `serverBackupExcludedKeys`.
- Shared keyword list (`SharedKeywords\*.json`, `ServerSharedKeywords\*.json`): envelope `{ format = 'INFERNO-KeywordList', formatVersion = 1, appVersion, payload, checksum }` (`core/sharing.lua`). `.txt` lists (one keyword per line) are also accepted.
- Rule: a file is read only if `format` and `formatVersion` match exactly; nothing is converted. When a format changes, bump its version and decide explicitly whether to read the previous one. The app version is informational only and is never compared. Removing a field does not bump the version: readers ignore unknown fields, so files written earlier still import.
- Keyword list in settings and profiles: `keywordRows` = `'v1:'` + `'=<encoded keyword>'` entries separated by `;`. Default: `settings.defaultKeywordRows` (`'v1:'`, empty).

## Session Update (INFERNO-AC rename)

- Mod renamed from "IsuChat Alert" to "INFERNO-AC". Release app: `INFERNO-ChatAlerts` (display name `INFERNO-Chat Alerts`).
- Source of truth is this repository (`Documents\Dev\INFERNO-AC`). The game folder only receives deployed copies.
- CSP only detects Lua apps directly in `apps\lua\<AppName>\` (`manifest.ini` + `<AppName>.lua`). A grouping subfolder such as `apps\lua\INFERNO-AC\...` hides the apps.
- `App.stateFolder` is `ExtCfgState\lua\app\<folderName>` (`Saves`, `SharedKeywords`). Settings (`ac.storage`) use the key prefix `INFERNO_`. Since 0.4.0 nothing is migrated from `isuChatAlertLua`.
- Window lookup matches the display name (`getAppWindow`, `getSettingsWindow`). If the manifest `NAME` changes, `displayName` must match it.
- Sounds are not in the repository (copyright). Only `sounds\DefaultAppSounds\00defaultALERT.wav` is tracked.
- Check in-game before release.

## Module layout (split from the single 3 900-line script)

- `INFERNO-ChatAlerts.lua` is the entry point: it `require`s every module in load order, holds `script.update` / `script.reset` and the `ac.onChatMessage` hook, and assigns the manifest callbacks `windowMain`, `windowConfig`, `windowDev`.
- `core/modules.lua` creates one empty table per module before anything loads. Each module fills its own table (`local Sounds = modules.sounds`) and reads the others from there, so modules can call each other without `require` cycles. Add a key there for a new module, and a `require` in the entry file.
- Values that never change after load (functions, tables) are imported as locals at the top of each module: `local settings = modules.settings.settings`. This only works for modules loaded earlier; a module loaded later is called through its table at call time (`Profiles.syncKeywordProfile()`).
- State that is reassigned and shared between modules lives on its owner's table, e.g. `Alert.alertTimeLeft`, `Profiles.profileStatus`, `Profiles.keywordProfiles`, `Sounds.alertSoundFileSet`. Never copy those into a local: the copy would go stale.
- `core/`: `paths` (identity, version, folders, file formats), `settings` (ac.storage), `debug`, `util`, `alert` (popup state), `history`, `sounds`, `keywords`, `friends`, `windows`, `profiles`, `backup`, `sharing`, `chat`. `ui/`: `widgets` (sliders, sound picker, colours; loaded early because core modules use `sliders.defaults`), the settings tabs, `config_window`, `alert_window`. `dev/icons.lua`: the INFERNO-DEV window.
- INFERNO-DEV is now a window of this app (manifest `ID=dev`, `FUNCTION_MAIN=windowDev`, icon `icons/dev.png`). The separate `apps\lua\INFERNO-DEV` app is no longer used.
- Each module has its own 200-local limit, so the old "main chunk is at 200 locals" constraint is gone. LuaJIT still limits a function to 60 upvalues.
- Tests: `tools\run-tests.ps1` (see README). `tools\check.js` (luaparse) reports unknown globals, e.g. a local that lost its import, and upvalue counts; LuaJIT (winget `DEVCOM.LuaJIT`) compiles every file; `tools\harness.lua` runs the app against deterministic CSP stubs (chat messages, windows, a "click every button" pass), then the targeted checks listed at the end of the file. Add a check for each behaviour change, and run it once against the previous commit (`git worktree add`) to be sure it fails there. The module split itself was verified by an identical harness trace for the old single file and the modules.

## Historical fixes (pre-rename, kept for context)

- `ac.getSessionID()` does not exist in the CSP Lua environment and used to crash the app. `getServerName()` now identifies the session: server name, else server IP, else `Solo_<driver>_<track>` for offline sessions.
- Older notes said the `ac.setWindowOpen('main'/'config', true)` calls crashed and were removed. Checked against the CSP SDK shipped with the game (`extension\internal\lua-sdk\ac_apps\lib.lua`): `ac.setWindowOpen(windowID, opened)` exists and opens a window by its manifest `ID`. The calls are correct; the one in the test preview (`ui/display_tab.lua`) is kept, the gear icon that used the other one was removed in 0.4.0. The SDK repository on GitHub is incomplete (it also lacks `ac.getAppWindows`), so check the installed SDK first.
- Sound queueing: the only queue in the code is `hiddenSoundQueue` (sounds of hidden keyword alerts, max 5, a full queue drops new sounds). Older notes described an `alertQueue` system with `addToAlertQueue()`/`initAlertSystem()` and an "Alert Queue" settings tab: none of that exists in the code and those notes were removed.

## Session Update (friends list, dev tools)

- **Slider helper** (`sliders.withDefault`, table `sliders` in `ui/widgets.lua`): wraps `ui.slider`. Right-click on release (`ui.itemClicked(Right, true)`) restores the default, the label is yellow (`sliders.modifiedColor`) while `|value - default| > 0.0001`, and the wheel (`ui.mouseWheel`, only while hovered) moves by `step`. Defaults live in `sliders.defaults`, which is also used by the reset functions. `sliders.checkbox(label, value, default)` does the same for checkboxes (yellow `FrameBg` box, black `CheckMark`, yellow label while `value ~= default`) and returns true on click, like `ui.checkbox`. The "I understand and want to overwrite" confirmation is not a setting and keeps a plain `ui.checkbox`.
- **Recent sounds** (`soundPicker.drawRecent`, block before `soundPicker.drawSelector`): `settings.recentSounds` stores base file names separated by `|`, most recent first, max 5 (`soundPicker.recentLimit`). `soundPicker.remember(fileName)` is called from `setSelectedSound`, so every picker feeds the list. The default sound is never stored. Durations come from `ac.AudioEvent.fromFile(...):getDuration()` and are cached in `soundPicker.durations`; a negative value means unavailable and the duration is hidden. `playAlertSound` is forward-declared near `currentSoundTestKey` for the preview button.
- **Sound list by sub-folder** (`soundPicker.groupedSounds`, `soundPicker.drawSoundRow`): `drawFile` shows Recent Sounds, then the default entry, then one title per sub-folder (root first) with a row per sound. The folder dropdown was removed. Rows use `drawSoundRow`, which also sets the default focus on the selected sound.
- **Used sounds** (`soundPicker.usedSounds`): mention, friend and keyword sound values, built in the keyword section and passed to `drawFile`, then `drawRecent` / `drawSoundRow`. Used rows are drawn with `ui.StyleColor.Text` in `soundPicker.usedColor()`: the `usedSound` entry of `debugColors` (yellow by default, stored in `settings.debugColorsData`) while Debug mode is on, otherwise the default yellow. The default entry is not coloured. In `drawSoundRow`, the row whose file is the alert's own sound (`selected`) uses `soundPicker.selectedColor()` (`selectedSound` entry, orange by default) instead, even if the file is used elsewhere.
- **Debug colour panel** (`drawToolsTab`, block under `if settings.debugModeEnabled`): Player color, Friend color, Settings theme colours 1 and 2 (`drawColorSetting` / `drawThemeColorSetting`), Used sound and Selected sound (`drawDebugColorSetting`). They were removed from `drawDisplayTab` so there is one copy. The former "Color button backing" entry (`buttonBacking`) is removed. `drawColorButton` draws a 4 px checkerboard over the `buttonOverflow` area (`ui.drawRectFilled`) before `ui.colorButton`. `ui.beginDisabled` does not exist in the CSP SDK, so the block is hidden when Debug mode is off rather than greyed out.
- **Sound dropdown height** (`soundPicker.drawSelector`): the combo uses `ComboFlags.NoPreview + ComboFlags.HeightLargest` (addition, because the flag bits do not overlap; LuaJIT has no `bit` operators) and `ui.setNextWindowSizeConstraints` (min width, max 480 px wide). `HeightLargest` lets the popup grow to the screen, so the list itself is a child window of height `soundPicker.listHeight()` = `soundPicker.listHeightRatio` (0.8) x `ac.getUI().windowSize.y`, which leaves a margin above and below. Change the ratio there. Not yet checked in game.
- **Friends list** (`friendList`, Tools > Debug): `friendList.names` holds the connected tagged friends, rebuilt every 2 s from `ac.isTaggedAsFriend`. `friendList.isFriend` uses it for message detection. Nothing is saved to disk (since 0.4.0): the tags belong to CSP and Content Manager, and a saved copy kept names after a tag was removed. `friendList.refresh()` must declare `local sim = ac.getSim()` (a bare `sim` is a nil global there).
- **Long messages in solo**: the first-scroll extension in `windowMain` no longer depends on `testMode`.
- **Dev apps** (not part of the mod, both in `apps\lua\`):
  - `FERNO-DEV`: Icons tab (filterable list of `ui.Icons`, click copies the name) and Info tab.
  - `DEBUG-CAPTURE`: screenshot for AI-driven debugging.
    - Keyword: `DEBUG-CAPTURE\request.txt` (created with `FERNOtest`, edited through the text field, not deleted after a capture)
    - Triggers: "Capturer" button, or create an empty file `DEBUG-CAPTURE\capture.now` (the script deletes it once handled)
    - Output: `shots\<yyyymmdd_hhmmss>_<keyword>.png` (`ac.makeSimpleScreenshot`, includes the HUD and CSP apps) and `.layout.txt` (`ac.getAppWindows()` positions and sizes, plus `sim_window_px`, `ui_scale`, `ui_window`)
    - Folder button opens `shots\` with `os.openInExplorer`
    - Crop a Windows screenshot with `tools\capture-screen.ps1 -App <name>` (`-Margin`, `-Rect`, `-Scale`, `-Process`)
    - Validated in game: two captures at 1920×1080 with `ui_scale=1`, where layout coordinates equal screen pixels. The `pixels = position × sim.windowWidth / ui.windowSize.x` conversion is not yet checked at another UI scale.
- **Tool note**: `create_file` can fail on `DEBUG-CAPTURE.lua` ("Could not get text view"). Workaround: write in `%TEMP%`, then `Move-Item -Force`.
- **Version**: see "File formats (0.4.0)" at the top. The default `backupName` (`My settings`) is only the default text of the Save field. Server backups are keyed by IP and port, not by this name.
- **Display panel background**: the solid blue background with red/green borders is the debug colour mode (`debugModeEnabled`, on by default). It is expected, not a bug.
- **Open point (keep in memory)**: the DEBUG-CAPTURE position to pixel conversion (`pixels = position × sim.windowWidth / ui.windowSize.x`) is only validated at `ui_scale=1`. Next test: capture with another UI scale, then compare `.layout.txt` with the cropped PNG (`capture-screen.ps1 -App`).
- **Test harness**: the old fengari scripts in `%TEMP%\friends-test` load the single-file mod and no longer apply to the module layout. Use the LuaJIT harness described under "Module layout".