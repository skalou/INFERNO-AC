-- INFERNO-Chat Alerts - Assetto Corsa Chat Alert Script
-- ==================================================
--
-- FIX: Removed ac.getSessionID() call that was causing crashes
-- ----------------------------------------------------------
-- The original script used ac.getSessionID() which is not supported in the Assetto Corsa Lua environment.
-- This caused crashes when running the script in any mode.
--
-- SOLUTION:
-- - Replaced ac.getSessionID() with a robust fallback mechanism
-- - For online sessions (server mode): Uses server name or IP address for unique identification
-- - For offline sessions (solo mode): Creates unique identifier using driver name and track
--
-- FEATURES MAINTAINED:
-- - Server-specific keyword profiles
-- - Solo session tracking  
-- - All existing alert functionality
-- - Sound notifications
-- - Chat message parsing and filtering
-- - Backup/restore functionality

-- New features implemented:
-- 1. UI redesign for alert rows with controls and numbering
-- 2. Enhanced sound management with queueing system
-- 3. Alert queuing system to prevent sound overlap

ac = ac

local defaultAlertSoundFile = '00defaultALERT.wav'

-- The deploy script rewrites folderName and displayName for the INFERNO-DEV copy.
-- Global on purpose: CSP gives each app its own Lua state, and this keeps the top-level local count at the 200 limit.
App = {
  folderName = 'INFERNO-ChatAlerts',
  displayName = 'INFERNO-Chat Alerts',
  migrateFrom = { 'INFERNO-ChatAlerts', 'isuChatAlertLua' },
}
App.stateFolder = ac.getFolder(ac.FolderID.ExtCfgState) .. '\\lua\\app\\' .. App.folderName

-- Settings and data used to live under the old folder names. Copy them once, only into empty locations.
do
  local function migrateAppData()
    local stateRoot = ac.getFolder(ac.FolderID.ExtCfgState) .. '\\lua\\app\\'
    local ownStorageFile = App.stateFolder .. '.ini'
    for _, oldName in ipairs(App.migrateFrom) do
      if oldName ~= App.folderName then
        local oldStorageFile = stateRoot .. oldName .. '.ini'
        if not io.fileExists(ownStorageFile) and io.fileExists(oldStorageFile) then
          io.copyFile(oldStorageFile, ownStorageFile, true)
          ac.log('INFERNO: settings migrated from ' .. oldName)
        end
        local oldStateFolder = stateRoot .. oldName
        if io.dirExists(oldStateFolder) then
          io.createDir(App.stateFolder)
          for _, sub in ipairs({ 'Saves', 'SharedKeywords', 'Friends' }) do
            local src, dst = oldStateFolder .. '\\' .. sub, App.stateFolder .. '\\' .. sub
            if io.dirExists(src) and not io.dirExists(dst) then
              io.createDir(dst)
              for _, fileName in ipairs(io.scanDir(src, '*')) do
                io.copyFile(src .. '\\' .. fileName, dst .. '\\' .. fileName, true)
              end
            end
          end
        end
      end
    end
  end
  migrateAppData()
end

local settings = ac.storage({

  keywords = 'ric,convoy,skalou',
  keywordRows = '',
  mentionMe = true,
  mentionSoundMuted = false,
  showAllChatMessages = false,
  textSize = 48,
  duration = 3.0,
  opacity = 75,
  soundEnabled = true,
  masterVolume = 100,
  mentionSound = defaultAlertSoundFile,
  friendSound = defaultAlertSoundFile,
  friendSoundMuted = false,
  keywordSoundAssignments = '',
  mutedKeywords = '',
  keywordOptions = '',
  savedSettings = '',
    recentSounds = '',
  backupName = 'isuchatalertversionv.2.8.1-5',
  settingsWindowHeightPercent = 75,
  settingsWindowPositionSaved = false,
  settingsWindowOffsetX = 0,
  settingsWindowOffsetY = 0,
  settingsWindowAbsoluteX = 0,
  settingsWindowAbsoluteY = 0,
  vehicleDisplayProfiles = '',
  keywordProfiles = '',
  keywordProfileFallback = '',
  useVehicleDisplayProfiles = false,
  useServerKeywordProfiles = false,
  autoSaveServerSettings = false,
  hideWhenNotHovered = false,
  backgroundEnabled = false,
  debugModeEnabled = true,
  debugColorsData = '',
  outlineThicknessPercent = 8,
  softOutline = false,
	themeColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1),
		themeBgColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1),
  textColor = rgbm(1, 102 / 255, 134 / 255, 242 / 255),
  authorColor = rgbm(1, 190 / 255, 80 / 255, 1),
  playerColor = rgbm(0.3, 1, 0.3, 1),
  friendColor = rgbm(0, 0.8, 1, 1),
  outlineColor = rgbm(20 / 255, 20 / 255, 20 / 255, 1),
  backgroundColor = rgbm(26 / 255, 26 / 255, 26 / 255, 1),
  accentColor = rgbm(97 / 255, 138 / 255, 81 / 255, 198 / 255)
-- Old key prefix kept so migrated settings still load.
}, 'IsuChatAlertLua_')
local Debug = {}
Debug.simulator = { text = 'Simulated chat message', author = 'Simulated driver', friend = false }
Debug.logFile = "debug_log.txt"
Debug.logFile_path = ac.getFolder(ac.FolderID.ACApps) .. '\\lua\\' .. App.folderName .. '\\debug_log.txt'

-- Clear/Create log file at startup
local f = io.open(Debug.logFile_path, "w")
if f then
    f:write("--- New Session Started: " .. os.date("%Y-%m-%d %H:%M:%S") .. " ---\n")
    f:close()
end

function Debug.log(level, message, ...)
    local args = {...}
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local formattedMessage = string.format("[%s] [%s] %s", timestamp, level, message)
    
    -- Print to AC Log
    ac.log(App.displayName .. " [" .. level .. "]: " .. message)
    
    -- Print to file
    local f = io.open(Debug.logFile_path, "a")
    if f then
        f:write(formattedMessage .. "\n")
        -- Handle extra arguments if any
        if #args > 0 then
            for _, arg in ipairs(args) do
                f:write(tostring(arg) .. " ")
            end
            f:write("\n")
        end
        f:close()
    end
end

function Debug.info(message, ...) Debug.log("INFO", message, ...) end
function Debug.warn(message, ...) Debug.log("WARN", message, ...) end
function Debug.error(message, ...) Debug.log("ERROR", message, ...) end
function Debug.trace(message, ...)
    if settings.debugModeEnabled then
        Debug.log("TRACE", message, ...)
    end
end


local latestMessage = ''
local latestAuthorColor = nil
local alertTimeLeft = 0
local alertDuration = 0
local testMode = nil
local textScrollElapsed = 0
local firstScrollRequired = false
local firstScrollComplete = false
local measuredMessage = nil
local measuredTextSize = nil
local measuredTextWidth = nil
local measuredFontSize = nil
local measuredTextHeight = 0
local measuredAuthorPrefix = nil
local measuredAuthorWidth = 0
local lastWindowPos = nil
local longPreviewMessage = 'This is a long chat preview to check how the alert wraps across multiple lines without extending beyond the chat window width. Keep resizing the chat window or change the text size in settings to verify that the entire message remains visible and the window grows vertically as needed. This final sentence helps test particularly long messages.'
local maxOutlineScale = 3
local draggingKeywordIndex = nil
-- Built-in list entries for player mentions and friend messages. Control characters cannot be typed into the keyword field.
local specialAlertKeys = { player = '\1player', friend = '\1friend' }
specialAlertKeys.labels = { [specialAlertKeys.player] = 'Your name is mentioned', [specialAlertKeys.friend] = 'Messages from friends' }
function specialAlertKeys.ensure(keywords)
  local changed = false
  for _, key in ipairs({ specialAlertKeys.player, specialAlertKeys.friend }) do
    local found = false
    for _, keyword in ipairs(keywords) do
      if keyword == key then found = true; break end
    end
    if not found then
      keywords[#keywords + 1] = key
      changed = true
    end
  end
  return changed
end
local activeVehicleProfileKey = nil
local activeKeywordProfileKey = nil
local keywordProfiles
local keywordProfileContextInitialized = false
local profileStatus = ''
local backupFolderStatus = ''
local soundFolderStatus = ''
local confirmOverwriteAllCars = false
local overwriteAllCarsConfirmed = false
local availableBackups = {}
local selectedBackupToLoad = ''
local getMainAppWindow
local resetMainWindowGeometry
local applyBackupWindowGeometry
local applyDefaultSettings
local backupFolder = App.stateFolder .. '\\Saves'
local sharedKeywordFolder = App.stateFolder .. '\\SharedKeywords'
local testMessagePending = nil
local sharedKeywordFiles = {}
local selectedSharedKeywordFile = ''
local pendingSharedKeywordImport = nil
local pendingOverwrite = {}
local comboWasOpen = {}
local appFolder = ac.getFolder(ac.FolderID.ACApps) .. '\\lua\\' .. App.folderName
local soundFolder = appFolder .. '\\sounds'
local serverKeywordFolder = appFolder .. '\\ServerSharedKeywords'
local serverKeywordSources = {}
local selectedServerKeywordSource = nil
local appVersion = '2.8.2'
local backupFormatVersion = 1
-- Format id is part of shared files, so it stays unchanged for compatibility.
local sharedKeywordFormat = 'IsuChatAlertServerKeywords'
local sharedKeywordFormatVersion = 1
local maximumBackupSize = 5 * 1024 * 1024
local alertSoundFiles = {}
local alertSoundFileSet = {}
local soundWarningsLogged = {}
local currentSoundEvent = nil
local currentSoundTestKey = nil
local playAlertSound -- assigned below; the recent sounds list previews through it

local function stopCurrentSound()
  local sound = currentSoundEvent
  currentSoundEvent = nil
  currentSoundTestKey = nil
  if sound then
	pcall(function() sound:stop() end)
	pcall(function() sound:dispose() end)
  end

end

local function isSoundTestPlaying(testKey)
  if not testKey or currentSoundTestKey ~= testKey or not currentSoundEvent then return false end
  local ok, playing = pcall(function() return currentSoundEvent:isPlaying() end)
  return ok and playing
end

local function resetAudioSettings()
  settings.soundEnabled = true
  settings.mentionMe = true
  settings.mentionSoundMuted = false
  settings.mentionSound = defaultAlertSoundFile
  settings.friendSound = defaultAlertSoundFile
  settings.friendSoundMuted = false
  settings.keywordSoundAssignments = ''
  settings.mutedKeywords = ''
  settings.keywordOptions = ''
  stopCurrentSound()
  profileStatus = 'Audio settings reset to defaults.'
end

-- Slider and checkbox defaults and helpers, grouped in one table because Lua allows only 200 locals per chunk.
local sliders = {
  defaults = {
    masterVolume = 100,
    keywordVolume = 100,
    textSize = 48,
    duration = 3.0,
    opacity = 75,
    outlineThicknessPercent = 8,
    buttonOverflow = 5,
    soundEnabled = true,
    mentionMe = true,
    showAllChatMessages = false,
    hideWhenNotHovered = false,
    backgroundEnabled = false,
    softOutline = false,
    useVehicleDisplayProfiles = false,
    useServerKeywordProfiles = false,
    autoSaveServerSettings = false,
    debugModeEnabled = true,
    simulatorFriend = false,
  },
  modifiedColor = rgbm(1, 1, 0.4, 1),
  modifiedCheckMark = rgbm(0, 0, 0, 1),
}

-- Right-click (on release) restores the default, the label turns yellow while the value differs, the mouse wheel moves by `step`.
function sliders.withDefault(label, value, min, max, format, default, step)
  local modified = math.abs(value - default) > 0.0001
  if modified then ui.pushStyleColor(ui.StyleColor.Text, sliders.modifiedColor) end
  local newValue = ui.slider(label, value, min, max, format)
  if modified then ui.popStyleColor(1) end
  if ui.itemHovered() then
    local wheel = ui.mouseWheel()
    if wheel ~= 0 then
      newValue = math.clamp(math.floor(newValue / step + wheel + 0.5) * step, min, max)
    end
  end
  if ui.itemClicked(ui.MouseButton.Right, true) then newValue = default end
  return newValue
end

-- Checkbox whose box and label turn yellow while its value differs from the default; returns true when clicked, like ui.checkbox.
function sliders.checkbox(label, value, default)
  local modified = value ~= default
  if modified then
    ui.pushStyleColor(ui.StyleColor.FrameBg, sliders.modifiedColor)
    ui.pushStyleColor(ui.StyleColor.FrameBgHovered, sliders.modifiedColor)
    ui.pushStyleColor(ui.StyleColor.FrameBgActive, sliders.modifiedColor)
    ui.pushStyleColor(ui.StyleColor.CheckMark, sliders.modifiedCheckMark)
    ui.pushStyleColor(ui.StyleColor.Text, sliders.modifiedColor)
  end
  local clicked = ui.checkbox(label, value)
  if modified then ui.popStyleColor(5) end
  return clicked
end

local function resetAlertAppearanceSettings()
  settings.textSize = sliders.defaults.textSize
  settings.duration = sliders.defaults.duration
  settings.opacity = sliders.defaults.opacity
  settings.hideWhenNotHovered = false
  settings.backgroundEnabled = false
  settings.outlineThicknessPercent = 8
  settings.softOutline = false
  settings.textColor = rgbm(1, 102 / 255, 134 / 255, 242 / 255)
  settings.authorColor = rgbm(1, 190 / 255, 80 / 255, 1)
  settings.playerColor = rgbm(0.3, 1, 0.3, 1)
  settings.friendColor = rgbm(0, 0.8, 1, 1)
  settings.outlineColor = rgbm(20 / 255, 20 / 255, 20 / 255, 1)
  settings.backgroundColor = rgbm(26 / 255, 26 / 255, 26 / 255, 1)
  settings.accentColor = rgbm(97 / 255, 138 / 255, 81 / 255, 198 / 255)
  settings.themeColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1)
  settings.themeBgColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1)
  profileStatus = 'Alert appearance reset to defaults.'
end

local invalidateKeywordCaches

local function resetKeywordSettings()
  if activeKeywordProfileKey then
    keywordProfiles[activeKeywordProfileKey] = nil
    settings.keywordProfiles = stringify(keywordProfiles, true)
  end
  settings.keywords = 'ric,convoy,skalou'
  settings.keywordRows = 'v1:=ric;=convoy;=skalou'
  settings.keywordSoundAssignments = ''
  settings.mutedKeywords = ''
  settings.keywordOptions = ''
  settings.keywordProfileFallback = ''
  activeKeywordProfileKey = nil
  keywordProfileContextInitialized = false
  invalidateKeywordCaches()
  profileStatus = 'Keyword settings reset to defaults.'
end

local function refreshAlertSoundFiles()
Debug.info('Refreshing alert sound files...')
  local soundFiles = {}
  local soundFileSet = {}
  -- Files in the sounds folder win over files with the same name in subfolders. The stored value is the path relative to soundFolder.
  local function scanFolder(folder, prefix)
	local subFolders = {}
	io.scanDir(folder, '*', function(fileName, attributes)
	  if attributes.isDirectory then
		subFolders[#subFolders + 1] = fileName
		return
	  end
	  local extension = fileName:match('%.([^%.]+)$')
	  if extension then
		extension = extension:lower()
		if (extension == 'wav' or extension == 'mp3') and not soundFileSet[fileName] then
		  soundFileSet[fileName] = prefix .. fileName
		  soundFiles[#soundFiles + 1] = fileName
		end
	  end
	end)
	for _, subFolder in ipairs(subFolders) do
	  scanFolder(folder .. '\\' .. subFolder, prefix .. subFolder .. '\\')
	end
  end
  scanFolder(soundFolder, '')
  table.sort(soundFiles)
  alertSoundFiles = soundFiles
  alertSoundFileSet = soundFileSet
end

-- Shows a stored sound name that is no longer in the sounds folder, so the player can see it is replaced by the default.
local function describeAlertSound(fileName)
  if not fileName or fileName == '' then return defaultAlertSoundFile end
  if alertSoundFileSet[fileName] then return fileName end
  return fileName .. ' (missing)'
end

refreshAlertSoundFiles()
-- Older versions used alert.wav as the default name; the built-in sound now replaces it.
if settings.mentionSound == 'alert.wav' then settings.mentionSound = defaultAlertSoundFile end

local soundPicker = {}

-- Recently chosen sounds, most recent first. Stored as file names separated by '|', which Windows does not allow in file names.
soundPicker.recentLimit = 5
soundPicker.durations = {}

function soundPicker.recentNames()
  local names = {}
  for fileName in (settings.recentSounds or ''):gmatch('[^|]+') do
	if alertSoundFileSet[fileName] and fileName ~= defaultAlertSoundFile then
	  names[#names + 1] = fileName
	end
  end
  return names
end

-- The default is not recorded, because it always has its own entry in the list.
function soundPicker.remember(fileName)
  if not fileName or fileName == defaultAlertSoundFile or not alertSoundFileSet[fileName] then return end
  local names = { fileName }
  for _, name in ipairs(soundPicker.recentNames()) do
	if name ~= fileName and #names < soundPicker.recentLimit then names[#names + 1] = name end
  end
  settings.recentSounds = table.concat(names, '|')
end

-- Length in seconds, read once per file. Not cached while audio is unavailable, so it is retried later.
function soundPicker.durationOf(fileName)
  local cached = soundPicker.durations[fileName]
  if cached == nil then
	if not ac.isAudioReady() then return nil end
	local ok, sound = pcall(ac.AudioEvent.fromFile, {
	  filename = soundFolder .. '\\' .. alertSoundFileSet[fileName],
	  use3D = false,
	  loop = false
	})
	cached = -1
	if ok and sound then
	  local read, duration = pcall(function() return sound:getDuration() end)
	  if read and type(duration) == 'number' and duration >= 0 then cached = duration end
	  pcall(function() sound:dispose() end)
	end
	soundPicker.durations[fileName] = cached
  end
  return cached >= 0 and cached or nil
end

-- Sounds already used by an alert (mention, friend and keyword assignments). They are drawn in another colour in the lists.
function soundPicker.usedSounds(keywordAssignments)
  local used = {}
  if settings.mentionSound then used[settings.mentionSound] = true end
  if settings.friendSound then used[settings.friendSound] = true end
  for _, fileName in pairs(keywordAssignments) do used[fileName] = true end
  return used
end

function soundPicker.drawRecent(selectedSound, usedSounds, onPick)
  local names = soundPicker.recentNames()
  ui.textColored('Recent Sounds', rgbm(0.6, 0.6, 0.6, 1))
  if #names == 0 then
	ui.textColored('No recent sounds yet, pick one below', rgbm(0.45, 0.45, 0.45, 1))
	ui.separator()
	return
  end
  for index, fileName in ipairs(names) do
	soundPicker.drawSoundRow('recent' .. index, fileName, '\\' .. alertSoundFileSet[fileName], selectedSound == fileName, usedSounds, onPick)
  end
  ui.separator()
end

-- One sound in a dropdown: play/stop button, then the name and duration. Clicking the name picks the sound.
function soundPicker.drawSoundRow(rowId, fileName, label, selected, usedSounds, onPick)
  ui.pushID(rowId)
  local testKey = 'sound:' .. fileName
  if ui.iconButton(isSoundTestPlaying(testKey) and ui.Icons.Stop or ui.Icons.Play, vec2(16, 16)) then
	playAlertSound(fileName, true, testKey, 100)
  end
  ui.sameLine(0, 8)
  local duration = soundPicker.durationOf(fileName)
  if duration then label = label .. '  ' .. string.format('%.1fs', duration) end
  local color = nil
  if selected then
    color = soundPicker.selectedColor()
  elseif usedSounds[fileName] == true then
    color = soundPicker.usedColor()
  end
  if color then ui.pushStyleColor(ui.StyleColor.Text, color) end
  local picked = ui.selectable(label, selected)
  if color then ui.popStyleColor() end
  if picked then
	onPick(fileName)
  end
  if selected then ui.setItemDefaultFocus() end
  ui.popID()
end

-- Sounds other than the default, grouped by sub-folder (the root first), in the same order as the folder dropdown.
function soundPicker.groupedSounds()
  local groups = {}
  local byFolder = {}
  for _, fileName in ipairs(alertSoundFiles) do
	if fileName ~= defaultAlertSoundFile then
	  local folder = soundPicker.folderOf(fileName)
	  if not byFolder[folder] then
		byFolder[folder] = { folder = folder, files = {} }
		groups[#groups + 1] = byFolder[folder]
	  end
	  table.insert(byFolder[folder].files, fileName)
	end
  end
  table.sort(groups, function(a, b) return a.folder:lower() < b.folder:lower() end)
  return groups
end

-- The sound list may use this share of the screen height, leaving a margin above and below.
soundPicker.listHeightRatio = 0.8

function soundPicker.listHeight()
  return math.floor(ac.getUI().windowSize.y * soundPicker.listHeightRatio)
end

function soundPicker.drawSelector(id, text, width, phase, drawOptions)
  local arrowWidth = 24
  local previewWidth = math.max(20, width - arrowWidth - 4)
  local contentWidth = math.max(previewWidth, ui.measureText(text).x + 12)
  ui.pushStyleVar(ui.StyleVar.WindowPadding, vec2(0, 0))
  ui.setNextWindowContentSize(vec2(contentWidth, 0))
  if ui.beginChild(id .. 'Preview', vec2(previewWidth, 22), true, ui.WindowFlags.NoScrollbar) then
    ui.text(text)
    local maxScroll = ui.getScrollMaxX()
    if maxScroll > 0 and not ui.itemHovered() then
      local speed = 35
      local pause = 0.8
      local travel = maxScroll / speed
      local cycle = 2 * (pause + travel)
      local elapsed = (ui.time() + phase) % cycle
      local offset = 0
      if elapsed > pause and elapsed <= pause + travel then
        offset = (elapsed - pause) * speed
      elseif elapsed > pause + travel and elapsed <= 2 * pause + travel then
        offset = maxScroll
      elseif elapsed > 2 * pause + travel then
        offset = maxScroll - (elapsed - 2 * pause - travel) * speed
      end
      ui.setScrollX(offset, false, false)
    else
      ui.setScrollX(0, false, false)
    end
  end
  ui.endChild()
  ui.popStyleVar()
  ui.sameLine(0, 0)
  ui.setNextItemWidth(arrowWidth)
  -- Keyword rows share the same id, so the phase (row index) is part of the key.
  local openKey = id .. ':' .. tostring(phase)
  -- The combo flags are separate bits, so adding them works like OR. The width is kept between the selector width and 480 px.
  ui.setNextWindowSizeConstraints(vec2(width, 0), vec2(math.max(width, 480), 100000))
  if ui.beginCombo(id .. 'Dropdown', '', ui.ComboFlags.NoPreview + ui.ComboFlags.HeightLargest) then
	-- Rebuild the sound list once per opening, so files and folders added while settings are open show up.
	if not comboWasOpen[openKey] then
	  refreshAlertSoundFiles()
	  comboWasOpen[openKey] = true
	end
	if ui.beginChild(id .. 'List', vec2(0, soundPicker.listHeight()), false) then
	  drawOptions()
	end
	ui.endChild()
	ui.endCombo()
  else
	comboWasOpen[openKey] = false
  end
end

function soundPicker.folderOf(fileName)
  return (alertSoundFileSet[fileName] or fileName):match('^(.*)\\[^\\]+$') or ''
end

function soundPicker.folderLabel(folder)
  return folder == '' and '(sounds root)' or folder
end

-- Sound dropdown: recent sounds, the default, then every sub-folder with its sounds. defaultValue is stored for the default entry.
function soundPicker.drawFile(id, selectedSound, width, phase, defaultValue, usedSounds, onPick)
  local isDefault = not selectedSound or selectedSound == defaultAlertSoundFile
  local defaultLabel = 'Default (' .. defaultAlertSoundFile .. ')'
  soundPicker.drawSelector(id, isDefault and defaultLabel or describeAlertSound(selectedSound), width, phase, function()
	  soundPicker.drawRecent(selectedSound, usedSounds, onPick)
	if ui.selectable(defaultLabel, isDefault) then
	  onPick(defaultValue)
	end
	if isDefault then ui.setItemDefaultFocus() end
	for _, group in ipairs(soundPicker.groupedSounds()) do
	  ui.textColored(soundPicker.folderLabel(group.folder), rgbm(0.6, 0.6, 0.6, 1))
	  for _, fileName in ipairs(group.files) do
		soundPicker.drawSoundRow('list' .. fileName, fileName, fileName, selectedSound == fileName, usedSounds, onPick)
	  end
	  ui.separator()
	end
  end)
end

local function escapePattern(value)
  return value:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])', '%%%1')
end

-- string.lower only folds ASCII. This also folds Latin-1 capitals in UTF-8 (C3 80-C3 9E, except the multiplication sign C3 97).
local function lowerText(text)
  return (string.lower(text):gsub('\195([\128-\158])', function(second)
    if second == '\151' then return nil end
    return '\195' .. string.char(second:byte() + 32)
  end))
end

-- Word boundaries only apply to alphanumeric edges (UTF-8 bytes 128-255 count as letters), so keywords like '.' or 'why?' still match.
local function buildKeywordPattern(keyword)
  local pattern = escapePattern(keyword)
  if keyword:match('^[%w_\128-\255]') then pattern = '%f[%w_\128-\255]' .. pattern end
  if keyword:match('[%w_\128-\255]$') then pattern = pattern .. '%f[^%w_\128-\255]' end
  return pattern
end

local function containsWord(text, word)
  return text:find(buildKeywordPattern(word)) ~= nil
end

local cachedPlayerName = nil
local cachedPlayerNameValid = false

local function invalidatePlayerNameCache()
  cachedPlayerNameValid = false
end

local function isPlayerMentioned(message)
  if not settings.mentionMe then return false end
  if not message or message == '' then return false end

  if not cachedPlayerNameValid then
    cachedPlayerName = ac.getDriverName(0)
    cachedPlayerNameValid = true
  end

  return cachedPlayerName ~= nil and cachedPlayerName ~= '' and containsWord(lowerText(message), lowerText(cachedPlayerName))
end

-- Escape delimiters so assignments can be stored in a single settings string.
local function encodeAssignmentValue(value)
  return value:gsub('%%', '%%25'):gsub(',', '%%2C'):gsub(';', '%%3B'):gsub('|', '%%7C')
	:gsub('\r', '%%0D'):gsub('\n', '%%0A')
end

local function decodeAssignmentValue(value)
  if type(value) ~= 'string' then return '' end
  local ok, result = pcall(function()
    return value:gsub('%%(%x%x)', function(hex)
      local code = tonumber(hex, 16)
      return code and string.char(code) or '?'
    end)
  end)
  if not ok then
    Debug.error('Decoding error in value')
    return ''
  end
  return result
end

local function saveKeywords(keywords)
  local entries = {}
  for _, keyword in ipairs(keywords) do
    entries[#entries + 1] = '=' .. encodeAssignmentValue(keyword)
  end
  settings.keywordRows = 'v1:' .. table.concat(entries, ';')
  invalidateKeywordCaches()
end

local function decodeKeywordRows(keywordRows)
  local keywords = {}
  local encodedRows = keywordRows:sub(4)
  local startIndex = 1
  while encodedRows ~= '' and #keywords < 256 do
    local separator = encodedRows:find(';', startIndex, true)
    local entry = separator and encodedRows:sub(startIndex, separator - 1) or encodedRows:sub(startIndex)
    if entry:sub(1, 1) == '=' then
      keywords[#keywords + 1] = decodeAssignmentValue(entry:sub(2))
    end
    if not separator then break end
    startIndex = separator + 1
  end
  return keywords
end

local cachedKeywords = nil
local cachedKeywordProfileKey = nil

local function parseKeywords()
  if cachedKeywords and cachedKeywordProfileKey == activeKeywordProfileKey then
    return cachedKeywords
  end

  if type(settings.keywordRows) ~= 'string' then
    settings.keywordRows = 'v1:'
  end

  if settings.keywordRows:sub(1, 3) ~= 'v1:' then
    local keywords = {}
    if type(settings.keywords) == 'string' then
      for keyword in settings.keywords:gmatch('[^,]+') do
        keyword = keyword:match('^%s*(.-)%s*$')
        if keyword ~= '' and #keywords < 256 then
          keywords[#keywords + 1] = keyword
        end
      end
    end
    specialAlertKeys.ensure(keywords)
    saveKeywords(keywords)
    cachedKeywords = keywords
    cachedKeywordProfileKey = activeKeywordProfileKey
    return keywords
  end

  local keywords = decodeKeywordRows(settings.keywordRows)
  if specialAlertKeys.ensure(keywords) then saveKeywords(keywords) end
  cachedKeywords = keywords
  cachedKeywordProfileKey = activeKeywordProfileKey
  return keywords
end

local cachedPatterns = {}
-- Returns the first list entry that matches, in list order: a keyword, the player mention entry or the friend entry.
local function findMatchedAlert(message, playerMentioned, friendMessage)
  if not message or message == '' then return nil end
  local lowerMessage = lowerText(message)
  for _, keyword in ipairs(parseKeywords()) do
    if keyword == specialAlertKeys.player then
      if playerMentioned then return keyword end
    elseif keyword == specialAlertKeys.friend then
      if friendMessage then return keyword end
    else
      local normalizedKeyword = keyword:match('^%s*(.-)%s*$')
      if normalizedKeyword ~= '' then
        local lowerKeyword = lowerText(normalizedKeyword)
        if not cachedPatterns[lowerKeyword] then
          cachedPatterns[lowerKeyword] = buildKeywordPattern(lowerKeyword)
        end
        if lowerMessage:find(cachedPatterns[lowerKeyword]) then return normalizedKeyword end
      end
    end
  end
  return nil
end

local cachedSoundAssignments = nil
local cachedSoundAssignmentProfileKey = nil

local function loadKeywordSoundAssignments()
  if cachedSoundAssignments and cachedSoundAssignmentProfileKey == activeKeywordProfileKey then
	return cachedSoundAssignments
  end

  local assignments = {}
  if type(settings.keywordSoundAssignments) == 'string' and settings.keywordSoundAssignments ~= '' then
	for entry in settings.keywordSoundAssignments:gmatch('[^;]+') do
	  local separator = entry:find('|', 1, true)
	  if separator then
		local keyword = decodeAssignmentValue(entry:sub(1, separator - 1))
		local fileName = decodeAssignmentValue(entry:sub(separator + 1))
		if keyword ~= '' and fileName ~= '' then
		  assignments[lowerText(keyword)] = fileName
		end
	  end
	end
  end
  cachedSoundAssignments = assignments
  cachedSoundAssignmentProfileKey = activeKeywordProfileKey
  return assignments
end

local function saveKeywordSoundAssignments(assignments)
  local entries = {}
  for keyword, fileName in pairs(assignments) do
	if fileName and fileName ~= '' then
	  entries[#entries + 1] = encodeAssignmentValue(keyword) .. '|' .. encodeAssignmentValue(fileName)
	end
  end
  table.sort(entries)
  settings.keywordSoundAssignments = table.concat(entries, ';')
  cachedSoundAssignments = nil
end

local cachedMutedKeywords = nil
local cachedMutedKeywordProfileKey = nil

local function loadMutedKeywords()
  if cachedMutedKeywords and cachedMutedKeywordProfileKey == activeKeywordProfileKey then
	return cachedMutedKeywords
  end

  local muted = {}
  if type(settings.mutedKeywords) == 'string' and settings.mutedKeywords ~= '' then
	for entry in settings.mutedKeywords:gmatch('[^;]+') do
	  local keyword = decodeAssignmentValue(entry)
	  if keyword ~= '' then
		muted[lowerText(keyword)] = true
	  end
	end
  end
  cachedMutedKeywords = muted
  cachedMutedKeywordProfileKey = activeKeywordProfileKey
  return muted
end

local function saveMutedKeywords(mutedKeywords)
  local entries = {}
  for keyword, isMuted in pairs(mutedKeywords) do
	if isMuted then
	  entries[#entries + 1] = encodeAssignmentValue(keyword)
	end
  end
  table.sort(entries)
  settings.mutedKeywords = table.concat(entries, ';')
  cachedMutedKeywords = nil
end

-- Per-keyword volume (0-300%) and hidden flag, stored as encKey|volume|hidden entries in settings.keywordOptions.
local keywordOptionStore = { cache = nil, cacheProfileKey = nil }

function keywordOptionStore.load()
  if keywordOptionStore.cache and keywordOptionStore.cacheProfileKey == activeKeywordProfileKey then
    return keywordOptionStore.cache
  end
  local options = {}
  if type(settings.keywordOptions) == 'string' and settings.keywordOptions ~= '' then
    for entry in settings.keywordOptions:gmatch('[^;]+') do
      local encodedKeyword, volume, hidden = entry:match('^([^|]+)|(%d+)|([01])$')
      local keyword = encodedKeyword and decodeAssignmentValue(encodedKeyword) or ''
      if keyword ~= '' then
        options[lowerText(keyword)] = { volume = math.min(300, tonumber(volume)), hidden = hidden == '1' }
      end
    end
  end
  keywordOptionStore.cache = options
  keywordOptionStore.cacheProfileKey = activeKeywordProfileKey
  return options
end

function keywordOptionStore.get(lowerKeyword)
  return keywordOptionStore.load()[lowerKeyword] or { volume = sliders.defaults.keywordVolume, hidden = false }
end

function keywordOptionStore.save(options)
  local entries = {}
  for keyword, option in pairs(options) do
    local volume = math.max(0, math.min(300, math.floor(option.volume + 0.5)))
    if volume ~= 100 or option.hidden then
      entries[#entries + 1] = encodeAssignmentValue(keyword) .. '|' .. string.format('%d', volume) .. '|' .. (option.hidden and '1' or '0')
    end
  end
  table.sort(entries)
  settings.keywordOptions = table.concat(entries, ';')
  keywordOptionStore.cache = nil
end

invalidateKeywordCaches = function()
  keywordOptionStore.cache = nil
  cachedKeywords = nil
  cachedKeywordProfileKey = nil
  cachedPatterns = {}
  cachedSoundAssignments = nil
  cachedMutedKeywords = nil
  cachedMutedKeywordProfileKey = nil
end

local function unpackStoredTable(serialized, label)
  if serialized == '' then return {} end
  local parsed = stringify.tryParse(serialized, nil, nil)
  if type(parsed) ~= 'table' then
	Debug.error('Could not read stored ' .. label .. '.')
	return {}
  end
  return parsed
end

local vehicleDisplayProfiles = unpackStoredTable(settings.vehicleDisplayProfiles, 'vehicle display profiles')
keywordProfiles = unpackStoredTable(settings.keywordProfiles, 'keyword profiles')
local removedModeProfiles = false
for profileKey in pairs(keywordProfiles) do
  if type(profileKey) == 'string' and profileKey:match('^mode:') then
	keywordProfiles[profileKey] = nil
	removedModeProfiles = true
  end
end
if removedModeProfiles then
  settings.keywordProfiles = stringify(keywordProfiles, true)
end

local function packColor(color)
  return { color.r, color.g, color.b, color.mult }
end

local function isFiniteNumber(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function unpackColor(color)
  if type(color) ~= 'table' then return nil end
  for index = 1, 4 do
	if not isFiniteNumber(color[index]) or color[index] < 0 or color[index] > 1 then return nil end
  end
  return rgbm(color[1], color[2], color[3], color[4])
end

local function captureAllSettings()
  local profile = {
	keywords = settings.keywords,
	keywordRows = settings.keywordRows,
	mentionMe = settings.mentionMe,
	mentionSoundMuted = settings.mentionSoundMuted,
	showAllChatMessages = settings.showAllChatMessages,
	textSize = settings.textSize,
	duration = settings.duration,
	opacity = settings.opacity,
	soundEnabled = settings.soundEnabled,
	mentionSound = settings.mentionSound,
	friendSound = settings.friendSound,
	friendSoundMuted = settings.friendSoundMuted,
	keywordSoundAssignments = settings.keywordSoundAssignments,
	mutedKeywords = settings.mutedKeywords,
		keywordOptions = settings.keywordOptions,
	useVehicleDisplayProfiles = settings.useVehicleDisplayProfiles,
	useServerKeywordProfiles = settings.useServerKeywordProfiles,
	vehicleDisplayProfiles = settings.vehicleDisplayProfiles,
	keywordProfiles = settings.keywordProfiles,
	keywordProfileFallback = settings.keywordProfileFallback,
	settingsWindowHeightPercent = settings.settingsWindowHeightPercent,
	settingsWindowPositionSaved = settings.settingsWindowPositionSaved,
	settingsWindowOffsetX = settings.settingsWindowOffsetX,
	settingsWindowOffsetY = settings.settingsWindowOffsetY,
	settingsWindowAbsoluteX = settings.settingsWindowAbsoluteX,
	settingsWindowAbsoluteY = settings.settingsWindowAbsoluteY,
	hideWhenNotHovered = settings.hideWhenNotHovered,
	backgroundEnabled = settings.backgroundEnabled,
	outlineThicknessPercent = settings.outlineThicknessPercent,
	softOutline = settings.softOutline,
  themeColor = packColor(settings.themeColor),
	themeBgColor = packColor(settings.themeBgColor),
	textColor = packColor(settings.textColor),
	authorColor = packColor(settings.authorColor),
	playerColor = packColor(settings.playerColor),
	friendColor = packColor(settings.friendColor),
	outlineColor = packColor(settings.outlineColor),
	backgroundColor = packColor(settings.backgroundColor),
	accentColor = packColor(settings.accentColor)
  }
  local window = getMainAppWindow()
  if window then
	local position = window:position()
	local size = window:size()
	profile.mainWindowPosition = { position.x, position.y }
	profile.mainWindowSize = { size.x, size.y }
  end
  return profile
end

local function applyAllSettings(profile, validateOnly)
  if type(profile) ~= 'table' then return false end
  local colors = {
	themeColor = unpackColor(profile.themeColor),
		themeBgColor = unpackColor(profile.themeBgColor),
	textColor = unpackColor(profile.textColor),
	authorColor = unpackColor(profile.authorColor),
	playerColor = unpackColor(profile.playerColor) or settings.playerColor,
	friendColor = unpackColor(profile.friendColor) or settings.friendColor,
	outlineColor = unpackColor(profile.outlineColor),
	backgroundColor = unpackColor(profile.backgroundColor),
	accentColor = unpackColor(profile.accentColor)
  }
	if not colors.themeColor then colors.themeColor = settings.themeColor end
		if not colors.themeBgColor then colors.themeBgColor = settings.themeBgColor end
  for key, color in pairs(colors) do
	if not color then return false end
  end
	for _, key in ipairs({ 'mentionSound' }) do
	if type(profile[key]) ~= 'string' then return false end
  end
  for _, key in ipairs({ 'mentionMe', 'mentionSoundMuted', 'showAllChatMessages', 'soundEnabled', 'hideWhenNotHovered', 'backgroundEnabled', 'softOutline', 'useVehicleDisplayProfiles' }) do
	if type(profile[key]) ~= 'boolean' then return false end
  end
	for _, key in ipairs({ 'textSize', 'duration', 'opacity', 'outlineThicknessPercent' }) do
	if not isFiniteNumber(profile[key]) then return false end
  end
  if profile.textSize < 8 or profile.textSize > 96
	  or profile.duration < 1 or profile.duration > 10
	  or profile.opacity < 0 or profile.opacity > 100
	  or profile.outlineThicknessPercent < 0
	  or profile.outlineThicknessPercent > maxOutlineScale * 100 / 8 then
	return false
  end
  for _, key in ipairs({ 'vehicleDisplayProfiles', 'keywordProfiles', 'keywordProfileFallback', 'keywords', 'keywordRows', 'keywordSoundAssignments', 'mutedKeywords', 'keywordOptions', 'friendSound' }) do
	if profile[key] ~= nil and type(profile[key]) ~= 'string' then return false end
  end
  for _, key in ipairs({ 'settingsWindowPositionSaved', 'useServerKeywordProfiles', 'friendSoundMuted' }) do
	if profile[key] ~= nil and type(profile[key]) ~= 'boolean' then return false end
  end
  if profile.settingsWindowHeightPercent ~= nil and (not isFiniteNumber(profile.settingsWindowHeightPercent)
	  or profile.settingsWindowHeightPercent < 25 or profile.settingsWindowHeightPercent > 100) then
	return false
  end
	for _, key in ipairs({ 'settingsWindowOffsetX', 'settingsWindowOffsetY', 'settingsWindowAbsoluteX', 'settingsWindowAbsoluteY' }) do
	if profile[key] ~= nil and not isFiniteNumber(profile[key]) then return false end
  end
  for _, key in ipairs({ 'mainWindowPosition', 'mainWindowSize' }) do
	local value = profile[key]
	if value ~= nil and (type(value) ~= 'table' or not isFiniteNumber(value[1]) or not isFiniteNumber(value[2])) then
	  return false
	end
  end
  if profile.mainWindowSize and (profile.mainWindowSize[1] <= 0 or profile.mainWindowSize[2] <= 0) then
	return false
  end
  for _, key in ipairs({ 'vehicleDisplayProfiles', 'keywordProfiles' }) do
	if type(profile[key]) == 'string' and profile[key] ~= ''
		and type(stringify.tryParse(profile[key], nil, nil)) ~= 'table' then
	  return false
	end
  end
	if validateOnly then return true end
  for key, value in pairs(profile) do
	if key ~= 'textColor' and key ~= 'authorColor' and key ~= 'playerColor' and key ~= 'friendColor' and key ~= 'outlineColor'
		and key ~= 'backgroundColor' and key ~= 'accentColor' and settings[key] ~= nil then
	  settings[key] = value
	end
  end
  for key, color in pairs(colors) do
	settings[key] = color
  end
  invalidateKeywordCaches()
    if profile.vehicleDisplayProfiles then
	vehicleDisplayProfiles = unpackStoredTable(profile.vehicleDisplayProfiles, 'vehicle display profiles')
  end
  if profile.keywordProfiles then
	keywordProfiles = unpackStoredTable(profile.keywordProfiles, 'keyword profiles')
	for profileKey in pairs(keywordProfiles) do
	  if type(profileKey) == 'string' and profileKey:match('^mode:') then
		keywordProfiles[profileKey] = nil
	  end
	end
	settings.keywordProfiles = stringify(keywordProfiles, true)
  end
  if profile.keywordProfileFallback == nil and profile.keywords ~= nil then
	settings.keywordProfileFallback = profile.useServerKeywordProfiles and stringify({
	  keywords = profile.keywords,
	  keywordRows = profile.keywordRows,
	  keywordSoundAssignments = profile.keywordSoundAssignments,
	  mutedKeywords = profile.mutedKeywords,
		  keywordOptions = profile.keywordOptions
	}, true) or ''
  end
  return true
end

local defaultSettingsProfile = {
  keywords = 'ric,convoy,skalou',
  keywordRows = 'v1:=ric;=convoy;=skalou',
  mentionMe = true,
  mentionSoundMuted = false,
  showAllChatMessages = false,
  textSize = 48,
  duration = 3.0,
  opacity = 75,
  soundEnabled = true,
  masterVolume = 100,
  mentionSound = defaultAlertSoundFile,
  keywordSoundAssignments = '',
  mutedKeywords = '',
  keywordOptions = '',
  friendSound = defaultAlertSoundFile,
  friendSoundMuted = false,
  useVehicleDisplayProfiles = false,
  useServerKeywordProfiles = false,
  vehicleDisplayProfiles = '',
  keywordProfiles = '',
  keywordProfileFallback = '',
  settingsWindowHeightPercent = 75,
  settingsWindowPositionSaved = false,
  settingsWindowOffsetX = 0,
  settingsWindowOffsetY = 0,
  settingsWindowAbsoluteX = 0,
  settingsWindowAbsoluteY = 0,
  hideWhenNotHovered = false,
  backgroundEnabled = false,
  outlineThicknessPercent = 8,
  softOutline = false,
	themeColor = { 97 / 255, 138 / 255, 81 / 255, 1 },
		themeBgColor = { 97 / 255, 138 / 255, 81 / 255, 1 },
  textColor = { 1, 102 / 255, 134 / 255, 242 / 255 },
  authorColor = { 1, 190 / 255, 80 / 255, 1 },
  playerColor = { 0.3, 1, 0.3, 1 },
  friendColor = { 0, 0.8, 1, 1 },
  outlineColor = { 20 / 255, 20 / 255, 20 / 255, 1 },
  backgroundColor = { 26 / 255, 26 / 255, 26 / 255, 1 },
  accentColor = { 97 / 255, 138 / 255, 81 / 255, 198 / 255 }
}

local function normalizeBackupName(name)
  local normalized = (name or ''):gsub('%.[jJ][sS][oO][nN]$', ''):gsub('[^%w _%-]', '')
  normalized = normalized:match('^%s*(.-)%s*$') or ''
  return normalized
end

local function ensureBackupFolder(folder)
  folder = folder or backupFolder
  if io.dirExists(folder) then return true end
  if io.createDir(folder) and io.dirExists(folder) then
	backupFolderStatus = 'Settings backup folder created.'
	return true
  end
  backupFolderStatus = 'Could not create the settings backup folder.'
  ac.log(App.displayName .. ': ' .. backupFolderStatus .. ' ' .. folder)
  return false
end

local function refreshBackupList()
  availableBackups = { 'Default' }
	if not ensureBackupFolder() then return end
  local backupCount = 0
  for _, fileName in ipairs(io.scanDir(backupFolder, '*.json') or {}) do
	local backupName = fileName:gsub('%.json$', '')
	if not fileName:match('^%.') and #backupName <= 64
		and normalizeBackupName(backupName) == backupName and backupName:lower() ~= 'default' then
	  availableBackups[#availableBackups + 1] = backupName
	  backupCount = backupCount + 1
	end
  end
  table.sort(availableBackups, function(a, b)
	if a == b then return false end
	if a == 'Default' then return true end
	if b == 'Default' then return false end
	return a:lower() < b:lower()
  end)
  if backupCount == 0 then
	backupFolderStatus = 'No settings backups found. Save current settings to create one.'
  else
	backupFolderStatus = backupCount .. ' settings backup(s) found.'
  end
end

local function backupFilePath(name, serverScope)
  if serverScope then
    local safeServerName = (name or ''):gsub('[^%w%-_]', '_'):sub(1, 64)
    if safeServerName == '' then return nil end
    return backupFolder .. '\\Servers\\' .. safeServerName .. '.json'
  end
  local safeName = normalizeBackupName(name)
  if safeName == '' then return nil end
  return backupFolder .. '\\' .. safeName .. '.json'
end

local function makeBackupChecksum(version, formatVersion, payload)
  local ok, digest = pcall(function()
	local hash = ac.checksumSHA256(version .. '\n' .. tostring(formatVersion) .. '\n' .. payload)
	if type(hash) ~= 'string' then return nil end
	return ac.encodeBase64(hash, true)
  end)
  return ok and type(digest) == 'string' and digest or nil
end

local function parseBackupVersion(version)
  if type(version) ~= 'string' or #version > 32 then return nil end
  local major, minor, patch = version:match('^(%d+)%.(%d+)%.(%d+)$')
  if not major then return nil end
  return { tonumber(major), tonumber(minor), tonumber(patch) }
end

local function validateBackupVersion(profile)
  if profile.appVersion == nil and profile.backupFormatVersion == nil then
	return true, 'Legacy backup loaded successfully.'
  end
  if type(profile.appVersion) ~= 'string' or profile.backupFormatVersion ~= backupFormatVersion then
	return false, 'Unsupported backup version or format.'
  end
  local savedVersion = parseBackupVersion(profile.appVersion)
  local currentVersion = parseBackupVersion(appVersion)
  if not savedVersion or not currentVersion then return false, 'Backup contains an invalid app version.' end
  for index = 1, 3 do
	if savedVersion[index] > currentVersion[index] then
	  return false, 'This backup was created by a newer app version (' .. profile.appVersion .. ').'
	elseif savedVersion[index] < currentVersion[index] then
	  return true, 'Older app version ' .. profile.appVersion .. ' backup loaded successfully.'
	end
  end
  return true, nil
end

local function decodeBackupData(data)
  local parsedOk, parsed = pcall(JSON.parse, data)
  if not parsedOk or type(parsed) ~= 'table' or (parsed.payload == nil and parsed.checksum == nil) then
	local legacy = stringify.tryParse(data, nil, nil)
	if type(legacy) ~= 'table' then return nil, 'Backup is not a valid settings file.' end
	if legacy.appVersion ~= nil or legacy.backupFormatVersion ~= nil then
	  return nil, 'Versioned backup is missing its integrity envelope.'
	end
	return legacy
  end
  if type(parsed.appVersion) ~= 'string' or type(parsed.backupFormatVersion) ~= 'number'
	  or type(parsed.payload) ~= 'string' or #parsed.payload == 0
	  or #parsed.payload > maximumBackupSize or type(parsed.checksum) ~= 'string' then
	return nil, 'Backup integrity metadata is invalid.'
  end
  local expectedChecksum = makeBackupChecksum(parsed.appVersion, parsed.backupFormatVersion, parsed.payload)
  if not expectedChecksum or expectedChecksum ~= parsed.checksum then
	return nil, 'Backup integrity check failed; the file may be damaged.'
  end
  local payloadOk, profile = pcall(JSON.parse, parsed.payload)
  if not payloadOk or type(profile) ~= 'table' then return nil, 'Backup payload is damaged or invalid.' end
  profile.appVersion = parsed.appVersion
  profile.backupFormatVersion = parsed.backupFormatVersion
  return profile
end

-- Function to get a unique server identifier for session tracking
-- This function handles both online (server) and offline (solo) modes:
-- - Online mode: Uses server name or IP address for identification  
-- - Solo mode: Creates a unique identifier based on driver name and track
local function getServerName()
  -- First check if we're in a server session (online mode)
  local serverName = ac.getServerName()
  local serverAddress = ac.getServerIP()
  
  -- Handle potential nil returns from AC API functions
  if serverName ~= nil and serverName ~= '' then
    -- If we have a server name, use it for session identification
    return serverName
  elseif serverAddress ~= nil and serverAddress ~= '' then
    -- If we have an IP address but no server name, use it instead
    return serverAddress
  else
    -- Fallback for solo mode or when no server info is available
    -- Try to get driver name as unique identifier for solo sessions
    local driverName = ac.getDriverName(0) or 'Player'
    local trackId = ac.getTrackID() or 'unknown'
    
    -- For solo sessions, create a unique identifier based on driver and track
    return string.format('Solo_%s_%s', driverName:gsub('[^%w]', '_'), trackId:gsub('[^%w]', '_'))
  end
end

local function getMissingMusicFiles(configData)
  if not configData then return {} end
  local missingFiles = {}

  if configData.mentionSound and not alertSoundFileSet[configData.mentionSound] then
    table.insert(missingFiles, configData.mentionSound)
  end
  if configData.friendSound and not alertSoundFileSet[configData.friendSound] then
    table.insert(missingFiles, configData.friendSound)
  end

  local assignments = configData.keywordSoundAssignments
  if type(assignments) == 'string' then
    local parsed = stringify.tryParse(assignments, nil, nil)
    if type(parsed) == 'table' then
      for keyword, soundFile in pairs(parsed) do
        if soundFile and not alertSoundFileSet[soundFile] then
          table.insert(missingFiles, soundFile)
        end
      end
    end
  end

  return missingFiles
end

-- Keyword and per-context profile data stay in their own profile maps, so a server file never carries them.
local serverBackupExcludedKeys = {
  keywords = true,
  keywordRows = true,
  keywordSoundAssignments = true,
  mutedKeywords = true,
  keywordOptions = true,
  useServerKeywordProfiles = true,
  keywordProfileFallback = true,
  keywordProfiles = true,
  vehicleDisplayProfiles = true
}
local lastServerBackupData = {}

local function saveServerBackup(serverName, onlyIfChanged)
  serverName = serverName or getServerName()
  if not serverName then
    profileStatus = 'No active server session. Server backups are only available during races.'
    return false
  end

  if not ensureBackupFolder() or not ensureBackupFolder(backupFolder .. '\\Servers') then
    profileStatus = backupFolderStatus
    return false
  end

  local snapshot = captureAllSettings()
  for key in pairs(serverBackupExcludedKeys) do
    snapshot[key] = nil
  end
  if not applyAllSettings(snapshot, true) then
    profileStatus = 'Current settings failed validation; no file was written.'
    return false
  end

  local payload = JSON.stringify(snapshot)
  local checksum = type(payload) == 'string' and makeBackupChecksum(appVersion, backupFormatVersion, payload) or nil
  local data = checksum and JSON.stringify({
    appVersion = appVersion,
    backupFormatVersion = backupFormatVersion,
    payload = payload,
    checksum = checksum
  }) or nil

  if type(data) ~= 'string' or #data > maximumBackupSize then
    profileStatus = 'Server backup could not be prepared or exceeds the size limit.'
    return false
  end

  if onlyIfChanged and lastServerBackupData[serverName] == data then return true end

  local serverAddress = ac.getServerIP()
  local serverKey = (serverAddress and serverAddress ~= '') and (serverAddress .. '_' .. tostring(ac.getServerPortTCP())) or serverName
  local filePath = backupFilePath(serverKey, true)
  if not io.save(filePath, data, true) then
    profileStatus = 'Could not write server backup for "' .. serverName .. '".'
    return false
  end

  lastServerBackupData[serverName] = data
  profileStatus = 'Settings auto-saved for server: ' .. serverName
  return true
end

local function loadServerBackup(serverName)
  serverName = serverName or getServerName()
  if not serverName then
    profileStatus = 'No active server session. Cannot load server-specific settings.'
    return false
  end

  local serverAddress = ac.getServerIP()
  local serverKey = (serverAddress and serverAddress ~= '') and (serverAddress .. '_' .. tostring(ac.getServerPortTCP())) or serverName
  local filePath = backupFilePath(serverKey, true)
  if not filePath or not io.fileExists(filePath) then
    filePath = backupFilePath(serverName, true)
  end
  if not filePath or not io.fileExists(filePath) then
    filePath = backupFilePath(serverName)
  end
  if not filePath or not io.fileExists(filePath) then
    profileStatus = 'No saved settings found for this server.'
    return false
  end

  local data = io.load(filePath)
  if type(data) ~= 'string' or #data == 0 then
    profileStatus = 'Could not load server backup file.'
    return false
  end

  local profile, decodeError = decodeBackupData(data)
  if not profile then
    profileStatus = 'Server backup decoding failed: ' .. (decodeError or 'unknown error')
    return false
  end

  for key in pairs(serverBackupExcludedKeys) do
    profile[key] = nil
  end
  local versionOk, versionError = validateBackupVersion(profile)
  if not versionOk then
    profileStatus = 'Version check failed: ' .. (versionError or 'unknown error')
    return false
  end

  local missingFiles = getMissingMusicFiles(profile)
  if #missingFiles > 0 then
    profileStatus = 'Warning: Missing sound files in server config: ' .. table.concat(missingFiles, ', ')
  else
    profileStatus = 'Server settings loaded successfully.'
  end

  if applyAllSettings(profile, false) then
    return true
  else
    profileStatus = 'Server settings failed to apply.'
    return false
  end
end

local function saveSettingsBackup()
  local safeName = normalizeBackupName(settings.backupName)
  if safeName:lower() == 'default' then
    profileStatus = 'The built-in Default profile cannot be overwritten.'
    return false
  end
  if safeName == '' then
	profileStatus = 'Enter a valid backup name.'
	return false
  end
	if #safeName > 64 then
	profileStatus = 'Backup name is empty or longer than 64 safe characters.'
	return false
	end
	if not ensureBackupFolder() then
	profileStatus = backupFolderStatus
	return false
  end
  local snapshot = captureAllSettings()
	if not applyAllSettings(snapshot, true) then
	  profileStatus = 'Current settings failed validation; no file was written.'
    return false
  end
	local payload = JSON.stringify(snapshot)
	local checksum = type(payload) == 'string' and makeBackupChecksum(appVersion, backupFormatVersion, payload) or nil
	local data = checksum and JSON.stringify({
	appVersion = appVersion,
	backupFormatVersion = backupFormatVersion,
	payload = payload,
	checksum = checksum
  }) or nil
	if type(data) ~= 'string' or #data > maximumBackupSize then
	profileStatus = 'Backup could not be prepared or exceeds the size limit.'
	return false
  end
	local filePath = backupFilePath(safeName)
	if io.fileExists(filePath) and pendingOverwrite.backup ~= safeName then
	  pendingOverwrite.backup = safeName
	  profileStatus = 'A backup named "' .. safeName .. '" already exists. Confirm to overwrite it.'
	  return false
	end
	pendingOverwrite.backup = nil
	local temporaryPath = filePath .. '.tmp'
	if not io.save(temporaryPath, data, true) then
	profileStatus = 'Could not write temporary backup file for "' .. safeName .. '".'
	return false
	end
	if io.fileSize(temporaryPath) ~= #data or io.load(temporaryPath) ~= data then
	if io.fileExists(temporaryPath) then io.deleteFile(temporaryPath) end
	profileStatus = 'Backup readback verification failed; previous backup preserved.'
	return false
	end
	if not io.move(temporaryPath, filePath, true) then
	if io.fileExists(temporaryPath) then io.deleteFile(temporaryPath) end
	profileStatus = 'Could not install the verified backup; previous backup preserved.'
	return false
	end
  settings.backupName = safeName
  selectedBackupToLoad = safeName
  settings.savedSettings = data
  refreshBackupList()
	profileStatus = 'Backup saved and verified: ' .. safeName .. ' (app ' .. appVersion .. ').'
	if not snapshot.mainWindowPosition or not snapshot.mainWindowSize then
	profileStatus = profileStatus .. ' Window geometry was unavailable and was not included.'
	end
  return true
end

local function loadSettingsBackup()
  local safeName = normalizeBackupName(selectedBackupToLoad)
  if safeName == '' then
    profileStatus = 'Select a backup in the list first.'
    return false
  end
  if safeName:lower() == 'default' then
    if applyDefaultSettings() then
      profileStatus = 'Built-in Default profile applied. User backup files were kept.'
    else
      profileStatus = 'Default profile applied, but the chat window could not be repositioned.'
    end
    return true
  end
	local filePath = backupFilePath(safeName)
  local data = filePath and io.fileExists(filePath) and io.load(filePath) or nil
  if not data and safeName == 'My settings' then
    data = settings.savedSettings ~= '' and settings.savedSettings or nil
  end
	if type(data) ~= 'string' or #data == 0 or #data > maximumBackupSize then
	profileStatus = 'No valid backup is available for this name.'
	return false
  end
	local saved, decodeError = decodeBackupData(data)
	if not saved then
	profileStatus = decodeError
	return false
	end
	local versionValid, versionStatus = validateBackupVersion(saved)
	if not versionValid or not applyAllSettings(saved, true) then
	profileStatus = versionStatus or 'Backup failed settings validation; no settings were changed.'
	return false
	end
	if not applyAllSettings(saved) then
	profileStatus = 'Backup could not be applied.'
	return false
	end
  applyBackupWindowGeometry(saved)
  activeVehicleProfileKey = nil
  activeKeywordProfileKey = nil
  keywordProfileContextInitialized = false
	profileStatus = versionStatus and (versionStatus .. ' ' .. safeName .. '.')
		or ('Backup loaded and validated: ' .. safeName .. ' (app ' .. appVersion .. ').')
  return true
end

local function getAppWindow(suffix)
  for _, window in ipairs(ac.getAppWindows()) do
	local windowName = type(window.name) == 'string' and window.name or ''
	local windowTitle = type(window.title) == 'string' and window.title or ''
	if windowName:find(App.displayName, 1, true) and windowName:match(suffix .. '$')
		and (windowTitle == '' or windowTitle:find(App.displayName, 1, true) == 1) then
	  local accessor = ac.accessAppWindow(window.name)
	  if accessor and accessor:valid() then return accessor end
	end
  end
  return nil
end

local function getSettingsWindow()
Debug.trace('Capturing current keyword profile')
  for _, window in ipairs(ac.getAppWindows()) do
	if type(window.name) == 'string' and window.name:match('_settings$')
		and type(window.title) == 'string' and window.title:find(App.displayName, 1, true) == 1 then
	  local accessor = ac.accessAppWindow(window.name)
	  if accessor and accessor:valid() then return accessor end
	end
  end
  return getAppWindow('_settings')
end

getMainAppWindow = function()
  return getAppWindow('_main')
end

local function getVehicleProfileKey()
  local carID = ac.getCarID(0)
  return carID and ('vehicle:' .. carID) or nil
end

local function getKeywordProfileContext()
  local serverName = ac.getServerName()
  local serverAddress = ac.getServerIP()
  if (serverAddress and serverAddress ~= '') or (serverName and serverName ~= '') then
    local serverID = serverAddress and serverAddress ~= '' and serverAddress or serverName
    local serverLabel = serverName and serverName ~= '' and serverName or serverAddress
    local serverPort = ac.getServerPortTCP()
    return 'server:' .. serverID:lower() .. ':' .. tostring(serverPort), 'Server: ' .. serverLabel
  end
  return nil, 'No active server session'
end

local function getKeywordProfileKey()
  local key = getKeywordProfileContext()
  return key
end

local function getActiveKeywordProfileKey()
  if settings.useServerKeywordProfiles then
	return getKeywordProfileKey()
  end
  return nil
end

local function captureKeywordProfile()
  return {
	keywords = settings.keywords,
	keywordRows = settings.keywordRows,
	keywordSoundAssignments = settings.keywordSoundAssignments,
	mutedKeywords = settings.mutedKeywords,
	keywordOptions = settings.keywordOptions
  }
end

local function isValidEncodedValue(value)
  local index = 1
  while index <= #value do
	if value:sub(index, index) == '%' then
	  if not value:sub(index + 1, index + 2):match('^%x%x$') then return false end
	  index = index + 3
	else
Debug.trace('Applying keyword profile: ' .. tostring(profile))
	  index = index + 1
	end
  end
  return true
end

local function validateKeywordProfile(profile)
  if type(profile) ~= 'table' or type(profile.keywords) ~= 'string'
	  or type(profile.keywordRows) ~= 'string' or type(profile.keywordSoundAssignments) ~= 'string'
	  or type(profile.mutedKeywords) ~= 'string' or #profile.keywords > 65536
	  or (profile.keywordOptions ~= nil and (type(profile.keywordOptions) ~= 'string' or #profile.keywordOptions > 262144))
	  or #profile.keywordRows > 262144 or #profile.keywordSoundAssignments > 262144
	  or #profile.mutedKeywords > 262144 or profile.keywordRows:sub(1, 3) ~= 'v1:' then
	return false
  end
  local rows = profile.keywordRows:sub(4)
  local rowCount = 0
  if rows ~= '' then
	for entry in (rows .. ';'):gmatch('(.-);') do
	  rowCount = rowCount + 1
	  if rowCount > 256 or entry:sub(1, 1) ~= '=' or not isValidEncodedValue(entry:sub(2)) then return false end
	end
  end
  for entry in profile.keywordSoundAssignments:gmatch('[^;]+') do
	local separator = entry:find('|', 1, true)
	if not separator then return false end
	local encodedKeyword = entry:sub(1, separator - 1)
	local encodedFileName = entry:sub(separator + 1)
	if not isValidEncodedValue(encodedKeyword) or not isValidEncodedValue(encodedFileName) then return false end
	local fileName = decodeAssignmentValue(encodedFileName)
	local extension = fileName:match('%.([^%.]+)$')
	if fileName == '' or fileName:find('/', 1, true) or fileName:find('\\', 1, true)
		or fileName:find(':', 1, true) or fileName:find('..', 1, true) or fileName:find('%c')
		or not extension or (extension:lower() ~= 'wav' and extension:lower() ~= 'mp3') then
	  return false
	end
  end
  for entry in profile.mutedKeywords:gmatch('[^;]+') do
	if not isValidEncodedValue(entry) then return false end
  end
  for entry in (profile.keywordOptions or ''):gmatch('[^;]+') do
	local encodedKeyword = entry:match('^([^|]+)|%d+|[01]$')
	if not encodedKeyword or not isValidEncodedValue(encodedKeyword) then return false end
  end
  return true
end

local function applyKeywordProfile(profile)
  if not validateKeywordProfile(profile) then return false end
  settings.keywords = profile.keywords
  settings.keywordRows = profile.keywordRows
  settings.keywordSoundAssignments = profile.keywordSoundAssignments
  settings.mutedKeywords = profile.mutedKeywords
  settings.keywordOptions = profile.keywordOptions or ''
  invalidateKeywordCaches()
  return true
end

local function applyKeywordProfileFallback()
  if settings.keywordProfileFallback ~= '' then
	local fallback = stringify.tryParse(settings.keywordProfileFallback, nil, nil)
	if applyKeywordProfile(fallback) then return true end
	Debug.warn('Stored keyword profile fallback is invalid; using built-in keywords.')
  end
  settings.keywords = 'ric,convoy,skalou'
  settings.keywordRows = 'v1:=ric;=convoy;=skalou'
  settings.keywordSoundAssignments = ''
  settings.mutedKeywords = ''
  settings.keywordOptions = ''
  invalidateKeywordCaches()
    return settings.keywordProfileFallback == ''
end

local function cleanProfileText(value, maxLength)
  if type(value) ~= 'string' then return '' end
  return (value:gsub('%c', ''):sub(1, maxLength))
end

local function sanitizeProfileInfo(info)
  if type(info) ~= 'table' then return nil end
  local createdAt = info.createdAt
  if type(createdAt) ~= 'number' or createdAt < 0 or createdAt > 4102444800 then return nil end
  return {
    serverName = cleanProfileText(info.serverName, 256),
    createdBy = cleanProfileText(info.createdBy, 64),
    createdAt = createdAt
  }
end

local function newProfileInfo()
  return {
    serverName = cleanProfileText(ac.getServerName(), 256),
    createdBy = cleanProfileText(ac.getDriverName(0), 64),
    createdAt = os.time()
  }
end

local function saveKeywordProfile(key)
  if not key then return false end
  local profile = captureKeywordProfile()
  local existing = keywordProfiles[key]
  profile.info = sanitizeProfileInfo(existing and existing.info) or newProfileInfo()
  keywordProfiles[key] = profile
  settings.keywordProfiles = stringify(keywordProfiles, true)
  return true
end

local function ensureSharedKeywordFolder()
  if io.dirExists(sharedKeywordFolder) then return true end
  if io.createDir(sharedKeywordFolder) and io.dirExists(sharedKeywordFolder) then return true end
  profileStatus = 'Could not create the shared keyword profiles folder.'
  ac.log(App.displayName .. ': ' .. profileStatus .. ' ' .. sharedKeywordFolder)
  return false
end

local function refreshSharedKeywordFiles()
  sharedKeywordFiles = {}
  if not ensureSharedKeywordFolder() then return end
  for _, fileName in ipairs(io.scanDir(sharedKeywordFolder, '*.json') or {}) do
    if fileName:match('%.json$') and not fileName:find('..', 1, true)
        and not fileName:find('/', 1, true) and not fileName:find('\\', 1, true)
        and not fileName:find('%c') then
      sharedKeywordFiles[#sharedKeywordFiles + 1] = fileName
    end
  end
  table.sort(sharedKeywordFiles, function(a, b) return a:lower() < b:lower() end)
  local stillAvailable = false
  for _, fileName in ipairs(sharedKeywordFiles) do
    if fileName == selectedSharedKeywordFile then stillAvailable = true end
  end
  if not stillAvailable then selectedSharedKeywordFile = sharedKeywordFiles[1] or '' end
end

local function exportSharedKeywordProfile(key, serverLabel, exportName)
  if not key then
    profileStatus = 'Connect to a server before exporting its keyword profile.'
    return false
  end
  if not ensureSharedKeywordFolder() then return false end
  local profile = captureKeywordProfile()
  profile.info = sanitizeProfileInfo(keywordProfiles[key] and keywordProfiles[key].info) or newProfileInfo()
  if not validateKeywordProfile(profile) then
    profileStatus = 'Current keyword settings failed validation; no export was written.'
    return false
  end
  local serverName = ac.getServerName() or ''
  local serverAddress = ac.getServerIP() or ''
  local serverPort = ac.getServerPortTCP()
  local payload = JSON.stringify({
    serverProfileKey = key,
    serverLabel = serverLabel,
    serverName = serverName,
    serverAddress = serverAddress,
    serverPort = serverPort,
    profile = profile
  })
  local checksum = type(payload) == 'string' and makeBackupChecksum(appVersion, sharedKeywordFormatVersion, payload) or nil
  local data = checksum and JSON.stringify({
    format = sharedKeywordFormat,
    formatVersion = sharedKeywordFormatVersion,
    appVersion = appVersion,
    payload = payload,
    checksum = checksum
  }) or nil
  if type(data) ~= 'string' or #data > maximumBackupSize then
    profileStatus = 'Shared keyword profile could not be prepared or exceeds the size limit.'
    return false
  end
  local safeBaseName = normalizeBackupName(exportName or '')
  if safeBaseName == '' then
    profileStatus = 'Enter a valid name for the shared file.'
    return false
  end
  safeBaseName = safeBaseName:sub(1, 80)
  local filePath = sharedKeywordFolder .. '\\' .. safeBaseName .. '.json'
  if io.fileExists(filePath) and pendingOverwrite.export ~= safeBaseName then
    pendingOverwrite.export = safeBaseName
    profileStatus = 'A shared file named "' .. safeBaseName .. '.json" already exists. Confirm to overwrite it.'
    return false
  end
  pendingOverwrite.export = nil
  local temporaryPath = filePath .. '.tmp'
  if not io.save(temporaryPath, data, true) then
    profileStatus = 'Could not write temporary shared keyword profile.'
    return false
  end
  if io.fileSize(temporaryPath) ~= #data or io.load(temporaryPath) ~= data then
    if io.fileExists(temporaryPath) then io.deleteFile(temporaryPath) end
    profileStatus = 'Shared keyword profile readback verification failed.'
    return false
  end
  if not io.move(temporaryPath, filePath, true) then
    if io.fileExists(temporaryPath) then io.deleteFile(temporaryPath) end
    profileStatus = 'Could not install the verified shared keyword profile.'
    return false
  end
  selectedSharedKeywordFile = safeBaseName .. '.json'
  refreshSharedKeywordFiles()
  profileStatus = 'Keyword profile exported for sharing: ' .. selectedSharedKeywordFile
  return true
end

local function readSharedKeywordFile(filePath)
  local data = io.fileExists(filePath) and io.load(filePath) or nil
  if type(data) ~= 'string' or #data == 0 or #data > maximumBackupSize then
    return nil, 'Shared keyword file is missing, empty, or too large.'
  end
  local parsedOk, envelope = pcall(JSON.parse, data)
  if not parsedOk or type(envelope) ~= 'table' or envelope.format ~= sharedKeywordFormat
      or envelope.formatVersion ~= sharedKeywordFormatVersion or type(envelope.appVersion) ~= 'string'
      or type(envelope.payload) ~= 'string' or type(envelope.checksum) ~= 'string' then
    return nil, 'Shared keyword file has an unsupported or invalid format.'
  end
  local expectedChecksum = makeBackupChecksum(envelope.appVersion, envelope.formatVersion, envelope.payload)
  if not expectedChecksum or expectedChecksum ~= envelope.checksum then
    return nil, 'Shared keyword file failed its integrity check.'
  end
  local payloadOk, payload = pcall(JSON.parse, envelope.payload)
  if not payloadOk or type(payload) ~= 'table' or type(payload.serverLabel) ~= 'string'
      or #payload.serverLabel > 256 or payload.serverLabel:find('%c')
      or not validateKeywordProfile(payload.profile) then
    return nil, 'Shared keyword file contains invalid keyword settings.'
  end
  return payload
end

local function stageSharedKeywordImport(fileName, targetKey, targetLabel)
  pendingSharedKeywordImport = nil
  refreshSharedKeywordFiles()
  local isListedFile = false
  for _, availableFile in ipairs(sharedKeywordFiles) do
    if availableFile == fileName then isListedFile = true end
  end
  if not targetKey or not isListedFile or not fileName:match('%.json$')
      or fileName:find('..', 1, true) or fileName:find('/', 1, true)
      or fileName:find('\\', 1, true) then
    profileStatus = 'Select a valid shared keyword file and connect to a server.'
    return false
  end
  local filePath = sharedKeywordFolder .. '\\' .. fileName
  local payload, readError = readSharedKeywordFile(filePath)
  if not payload then
    profileStatus = readError
    return false
  end
  pendingSharedKeywordImport = {
    fileName = fileName,
    serverLabel = payload.serverLabel,
    targetKey = targetKey,
    targetLabel = targetLabel,
    profile = payload.profile
  }
  profileStatus = 'Shared file validated. Confirm to replace the keyword profile for the current server.'
  return true
end

local function applyStagedSharedKeywordImport(targetKey)
  if not targetKey or not pendingSharedKeywordImport then return false end
  if targetKey ~= pendingSharedKeywordImport.targetKey then
    pendingSharedKeywordImport = nil
    profileStatus = 'Server context changed; prepare the import again for the current server.'
    return false
  end
  if not settings.useServerKeywordProfiles then
    settings.keywordProfileFallback = stringify(captureKeywordProfile(), true)
    settings.useServerKeywordProfiles = true
  end
  local importedProfile = pendingSharedKeywordImport.profile
  importedProfile.info = sanitizeProfileInfo(importedProfile.info) or newProfileInfo()
  keywordProfiles[targetKey] = importedProfile
  settings.keywordProfiles = stringify(keywordProfiles, true)
  if not applyKeywordProfile(importedProfile) then
    profileStatus = 'Shared keyword profile could not be applied.'
    return false
  end
  activeKeywordProfileKey = targetKey
  keywordProfileContextInitialized = true
  profileStatus = 'Imported ' .. pendingSharedKeywordImport.fileName .. ' into the current server profile.'
  pendingSharedKeywordImport = nil
  return true
end

local function resetKeywordProfile(key)
  if not key then return false end
  keywordProfiles[key] = nil
  settings.keywordProfiles = stringify(keywordProfiles, true)
  if activeKeywordProfileKey == key then
    applyKeywordProfileFallback()
    activeKeywordProfileKey = nil
  end
  return true
end

local function loadKeywordProfile(key)
  return applyKeywordProfile(key and keywordProfiles[key])
end

local function captureVehicleDisplayProfile()
  local profile = {
	textSize = settings.textSize,
	duration = settings.duration,
	opacity = settings.opacity,
	hideWhenNotHovered = settings.hideWhenNotHovered,
	backgroundEnabled = settings.backgroundEnabled,
	outlineThicknessPercent = settings.outlineThicknessPercent,
	softOutline = settings.softOutline,
	textColor = packColor(settings.textColor),
	authorColor = packColor(settings.authorColor),
	playerColor = packColor(settings.playerColor),
	friendColor = packColor(settings.friendColor),
	outlineColor = packColor(settings.outlineColor),
	backgroundColor = packColor(settings.backgroundColor),
	accentColor = packColor(settings.accentColor)
  }
  local window = getMainAppWindow()
  if window then
	local position = window:position()
	local size = window:size()
	profile.windowPosition = { position.x, position.y }
	profile.windowSize = { size.x, size.y }
  end
  return profile
end

local function saveVehicleDisplayProfile(key)
  if not key then return false end
  vehicleDisplayProfiles[key] = captureVehicleDisplayProfile()
  settings.vehicleDisplayProfiles = stringify(vehicleDisplayProfiles, true)
  return true
end

resetMainWindowGeometry = function()
  local window = getMainAppWindow()
  if not window then
    Debug.error('Cannot reset chat window geometry because its app window is unavailable.')
    return false
  end
  local sim = ac.getSim()
  local uiScale = ac.getUI().uiScale
  if type(uiScale) ~= 'number' or uiScale <= 0 then
    Debug.error('Cannot reset chat window geometry because CSP returned an invalid UI scale.')
    return false
  end
  local screenSize = vec2(sim.windowWidth, sim.windowHeight)
  local defaultSize = vec2(
    math.min(680 * uiScale, math.max(1, screenSize.x - 100)),
    math.min(260 * uiScale, math.max(1, screenSize.y - 113))
  )
  window:resize(defaultSize)
  window:move(vec2(
    math.max(0, math.min(50, screenSize.x - defaultSize.x)),
    math.max(0, math.min(63, screenSize.y - defaultSize.y))
  ))
  return true
end

local function applyWindowGeometry(position, size)
  if type(position) ~= 'table' or type(size) ~= 'table'
      or not isFiniteNumber(position[1]) or not isFiniteNumber(position[2])
      or not isFiniteNumber(size[1]) or not isFiniteNumber(size[2])
      or size[1] <= 0 or size[2] <= 0 then
    return false
  end
  local window = getMainAppWindow()
  if not window then return false end
  local sim = ac.getSim()
  local uiScale = ac.getUI().uiScale
  if type(uiScale) ~= 'number' or uiScale <= 0 then return false end
  local screenSize = vec2(sim.windowWidth, sim.windowHeight)
  local boundedSize = vec2(
    math.min(size[1], math.max(1, screenSize.x - 100)),
    math.min(size[2], math.max(1, screenSize.y - 113))
  )
  window:resize(boundedSize)
  window:move(vec2(
    math.max(0, math.min(position[1], math.max(0, screenSize.x - boundedSize.x))),
    math.max(0, math.min(position[2], math.max(0, screenSize.y - boundedSize.y)))
  ))
  return true
end

applyBackupWindowGeometry = function(profile)
  if type(profile) ~= 'table' then return end
  applyWindowGeometry(profile.mainWindowPosition, profile.mainWindowSize)
end

applyDefaultSettings = function()
  if not applyAllSettings(defaultSettingsProfile) then return false end
  activeVehicleProfileKey = nil
  activeKeywordProfileKey = nil
  settings.settingsWindowPositionSaved = false
  settings.settingsWindowOffsetX = 0
  settings.settingsWindowOffsetY = 0
  settings.settingsWindowAbsoluteX = 0
  settings.settingsWindowAbsoluteY = 0
  settings.backupName = 'Default'
  selectedBackupToLoad = 'Default'
  return resetMainWindowGeometry()
end

local function resetVehicleDisplayProfile(key)
  if key then
    vehicleDisplayProfiles[key] = nil
    settings.vehicleDisplayProfiles = stringify(vehicleDisplayProfiles, true)
  end
  settings.textSize = sliders.defaults.textSize
  settings.duration = sliders.defaults.duration
  settings.opacity = sliders.defaults.opacity

  settings.hideWhenNotHovered = false
  settings.backgroundEnabled = false
  settings.outlineThicknessPercent = 8
  settings.softOutline = false
  settings.textColor = rgbm(1, 102 / 255, 134 / 255, 242 / 255)
  settings.authorColor = rgbm(1, 190 / 255, 80 / 255, 1)
  settings.playerColor = rgbm(0.3, 1, 0.3, 1)
  settings.friendColor = rgbm(0, 0.8, 1, 1)
  settings.outlineColor = rgbm(20 / 255, 20 / 255, 20 / 255, 1)
  settings.backgroundColor = rgbm(26 / 255, 26 / 255, 26 / 255, 1)
  settings.accentColor = rgbm(97 / 255, 138 / 255, 81 / 255, 198 / 255)
  settings.themeColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1)
  settings.themeBgColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1)
  local geometryReset = resetMainWindowGeometry()
  if key then
    vehicleDisplayProfiles[key] = captureVehicleDisplayProfile()
    settings.vehicleDisplayProfiles = stringify(vehicleDisplayProfiles, true)
  end
  activeVehicleProfileKey = settings.useVehicleDisplayProfiles and key or nil
  return geometryReset
end

local function saveDisplayForAllCars()
  if not getMainAppWindow() then return false end
  local profile = captureVehicleDisplayProfile()
  if not profile.windowPosition or not profile.windowSize then return false end
  vehicleDisplayProfiles['all:default'] = profile
  for profileKey in pairs(vehicleDisplayProfiles) do
    if profileKey ~= 'all:default' then
      vehicleDisplayProfiles[profileKey] = profile
    end
  end
  local currentVehicleKey = getVehicleProfileKey()
  if currentVehicleKey then vehicleDisplayProfiles[currentVehicleKey] = profile end
  settings.vehicleDisplayProfiles = stringify(vehicleDisplayProfiles, true)
  return true
end

local function applyVehicleDisplayProfile(key)
  local profile = key and vehicleDisplayProfiles[key]
  if type(profile) ~= 'table' then return false end
  for _, field in ipairs({ 'textSize', 'duration', 'opacity', 'outlineThicknessPercent' }) do
	if not isFiniteNumber(profile[field]) then return false end
  end
  if profile.textSize < 8 or profile.textSize > 96
	  or profile.duration < 1 or profile.duration > 10
	  or profile.opacity < 0 or profile.opacity > 100
	  or profile.outlineThicknessPercent < 0
	  or profile.outlineThicknessPercent > maxOutlineScale * 100 / 8 then
	return false
  end
  for _, field in ipairs({ 'hideWhenNotHovered', 'backgroundEnabled', 'softOutline' }) do
	if type(profile[field]) ~= 'boolean' then return false end
  end
  local colors = {
	textColor = unpackColor(profile.textColor),
	authorColor = unpackColor(profile.authorColor),
	playerColor = unpackColor(profile.playerColor) or settings.playerColor,
	friendColor = unpackColor(profile.friendColor) or settings.friendColor,
	outlineColor = unpackColor(profile.outlineColor),
	backgroundColor = unpackColor(profile.backgroundColor),
	accentColor = unpackColor(profile.accentColor)
  }
  for _, color in pairs(colors) do
	if not color then return false end
  end
  settings.textSize = profile.textSize
  settings.duration = profile.duration
  settings.opacity = profile.opacity
  settings.hideWhenNotHovered = profile.hideWhenNotHovered
  settings.backgroundEnabled = profile.backgroundEnabled
  settings.outlineThicknessPercent = profile.outlineThicknessPercent
  settings.softOutline = profile.softOutline
  for keyName, color in pairs(colors) do
	settings[keyName] = color
  end
  applyWindowGeometry(profile.windowPosition, profile.windowSize)
  return true
end

local function syncVehicleDisplayProfile()
  local nextKey = settings.useVehicleDisplayProfiles and getVehicleProfileKey() or nil
  if nextKey == activeVehicleProfileKey then return end
  if activeVehicleProfileKey then saveVehicleDisplayProfile(activeVehicleProfileKey) end
  activeVehicleProfileKey = nextKey
  if nextKey then
	local profileKey = vehicleDisplayProfiles[nextKey] and nextKey or 'all:default'
	if vehicleDisplayProfiles[profileKey] then
	  if not applyVehicleDisplayProfile(profileKey) then
		profileStatus = 'The saved display profile for this car is invalid.'
	  end
	else
	  resetVehicleDisplayProfile(nextKey)
	end
  end
end

local function syncKeywordProfile()
  local nextKey = getActiveKeywordProfileKey()
  if nextKey == activeKeywordProfileKey and keywordProfileContextInitialized then return end
  local previousKey = activeKeywordProfileKey
  if previousKey then saveKeywordProfile(previousKey) end
  activeKeywordProfileKey = nextKey
  keywordProfileContextInitialized = true
  if nextKey then
	if keywordProfiles[nextKey] then
	  if not loadKeywordProfile(nextKey) then
		profileStatus = 'The saved keyword profile for this context is invalid.'
	  end
	elseif not applyKeywordProfileFallback() then
	  profileStatus = 'The keyword profile fallback was invalid; built-in keywords were loaded.'
	end
  elseif settings.useServerKeywordProfiles then
	if not applyKeywordProfileFallback() then
	  profileStatus = 'The keyword profile fallback was invalid; built-in keywords were loaded.'
	end
  elseif previousKey and not applyKeywordProfileFallback() then
	profileStatus = 'The keyword profile fallback was invalid; built-in keywords were loaded.'
  end
end

local function resetSettings()
  if applyDefaultSettings() then
    profileStatus = 'Built-in Default profile applied. User backup files were kept.'
  else
    profileStatus = 'Default settings applied, but the chat window could not be repositioned.'
  end
end

local function isAlertSoundPlaying()
  if not currentSoundEvent then return false end
  local checked, isPlaying = pcall(function() return currentSoundEvent:isPlaying() end)
  return checked and isPlaying
end

local function playSoundFile(fileName, volumePercent)
  stopCurrentSound()
  local fullPath = soundFolder .. '\\' .. (alertSoundFileSet[fileName] or fileName)
  local ok, sound = pcall(ac.AudioEvent.fromFile, {
	filename = fullPath,
	use3D = false,
	loop = false
  })
  if ok and sound then
	local valid, isValid = pcall(function() return sound:isValid() end)
	if valid and isValid then
	  local started, err = pcall(function()
		sound.volume = math.min(3, (volumePercent or 100) / 100 * (settings.masterVolume or 100) / 100)
		sound:start()
	  end)
	  if started then
		currentSoundEvent = sound
		return true
	  end
	  pcall(function() sound:dispose() end)
	  if not soundWarningsLogged[fileName] then
		Debug.error('could not play ' .. fileName .. ': ' .. tostring(err))
		soundWarningsLogged[fileName] = true
	  end
	  return false
	end
	pcall(function() sound:dispose() end)
  end
  if not soundWarningsLogged[fileName] then
	Debug.error('could not load audio file ' .. fileName .. (ok and '' or ': ' .. tostring(sound)))
	soundWarningsLogged[fileName] = true
  end
  return false
end

playAlertSound = function(fileName, force, testKey, volumePercent)
  if testKey and currentSoundTestKey == testKey and currentSoundEvent then
	local checked, isPlaying = pcall(function() return currentSoundEvent:isPlaying() end)
	if checked and isPlaying then
	  stopCurrentSound()
	  return
	end
	stopCurrentSound()
  end
  if (not force and not settings.soundEnabled) or not ac.isAudioReady() then return end
  if not alertSoundFileSet[fileName] then
	if not soundWarningsLogged[fileName] then
	  Debug.error('audio file is not available in the app folder: ' .. tostring(fileName))
	  soundWarningsLogged[fileName] = true
	end
	fileName = defaultAlertSoundFile
		if not alertSoundFileSet[fileName] then
		  if not soundWarningsLogged[fileName] then
			Debug.error('default alert sound is missing from the sounds folder: ' .. fileName)
			soundWarningsLogged[fileName] = true
		  end
		  return
		end
  end
	if playSoundFile(fileName, volumePercent) then
	currentSoundTestKey = testKey
  elseif fileName ~= defaultAlertSoundFile and alertSoundFileSet[defaultAlertSoundFile] and playSoundFile(defaultAlertSoundFile, volumePercent) then
	currentSoundTestKey = testKey
  end
end

-- Alerts triggered this session, newest last. Kept in memory only and cleared when the app closes.
local alertHistory = { items = {}, max = 100, current = nil }

function alertHistory.add(entry)
  entry.events = {}
  table.insert(alertHistory.items, entry)
  while #alertHistory.items > alertHistory.max do
    table.remove(alertHistory.items, 1)
  end
  return entry
end

function alertHistory.addEvent(entry, text)
  if not entry then return end
  table.insert(entry.events, { time = os.date('%H:%M:%S'), text = text })
end

-- A newer popup replaces the one still on screen, so the older entry gets a note.
function alertHistory.popupReplaced()
  if alertHistory.current and alertTimeLeft > 0 then
    alertHistory.addEvent(alertHistory.current, 'Replaced on screen by a newer alert')
  end
end

function alertHistory.clear()
  alertHistory.items = {}
  alertHistory.current = nil
end

function alertHistory.formatEntry(entry)
  local visual = entry.hidden and 'no popup' or 'popup'
  local audio = entry.muted and 'muted' or 'sound'
  local lines = { entry.time .. ' [' .. entry.trigger .. '] ' .. entry.author .. ' : ' .. entry.message, '  ' .. visual .. ' | ' .. audio .. ': ' .. entry.soundName }
  for _, event in ipairs(entry.events) do
    table.insert(lines, '  ' .. event.time .. '  ' .. event.text)
  end
  return table.concat(lines, '\n')
end

-- Sounds of hidden keywords wait here while another alert sound plays, then play in order. A full queue drops new sounds.
local hiddenSoundQueue = { items = {}, maxSize = 5 }

function hiddenSoundQueue.add(fileName, volumePercent, historyEntry)
  if #hiddenSoundQueue.items >= hiddenSoundQueue.maxSize then
    alertHistory.addEvent(historyEntry, 'Not played: hidden sound queue is full')
    return
  end
  table.insert(hiddenSoundQueue.items, { fileName = fileName, volumePercent = volumePercent, historyEntry = historyEntry })
  alertHistory.addEvent(historyEntry, 'Delayed: waiting for the current alert sound to finish')
end

function hiddenSoundQueue.playNext()
  if #hiddenSoundQueue.items == 0 or isAlertSoundPlaying() then return end
  local nextSound = table.remove(hiddenSoundQueue.items, 1)
  playAlertSound(nextSound.fileName, false, nil, nextSound.volumePercent)
  alertHistory.addEvent(nextSound.historyEntry, 'Left the queue and started playing')
end

-- Friends come from CSP's friend tags (same source as comfy_map). Only online races have other players, so solo sessions get an empty list. Car 0 is the player's own car and is skipped.
-- Saved friends are kept in a JSON file so the list survives restarts.
local friendList = {
  names = {}, known = {}, dirty = true, elapsed = 0, refreshInterval = 2, status = '',
  folder = App.stateFolder .. '\\Friends',
}
friendList.file = friendList.folder .. '\\friends.json'

function friendList.ensureFolder()
  if io.dirExists(friendList.folder) then return true end
  return io.createDir(friendList.folder) and io.dirExists(friendList.folder)
end

-- A missing or unreadable file just means an empty list.
function friendList.load()
  friendList.known = {}
  if not io.fileExists(friendList.file) then return end
  local ok, parsed = pcall(JSON.parse, io.load(friendList.file) or '')
  if ok and type(parsed) == 'table' then
    for _, name in ipairs(parsed) do
      if type(name) == 'string' and name ~= '' then table.insert(friendList.known, name) end
    end
  end
end

function friendList.save()
  if not friendList.ensureFolder() then
    friendList.status = 'Could not create the friends folder.'
    return false
  end
  if not io.save(friendList.file, JSON.stringify(friendList.known), true) then
    friendList.status = 'Could not save the friends list.'
    return false
  end
  return true
end

function friendList.isKnown(name)
  for _, knownName in ipairs(friendList.known) do
    if knownName == name then return true end
  end
  return false
end

function friendList.refresh()
  local names = {}
  local sim = ac.getSim()
  if sim.isOnlineRace and ac.isTaggedAsFriend then
    for i = 1, sim.carsCount - 1 do
      if ac.getCar(i).isConnected then
        local name = ac.getDriverName(i)
        if name and name ~= '' and ac.isTaggedAsFriend(name) then
          table.insert(names, name)
        end
      end
    end
  end
  friendList.names = names
  friendList.dirty = false

  local added = false
  for _, name in ipairs(names) do
    if not friendList.isKnown(name) then
      table.insert(friendList.known, name)
      added = true
    end
  end
  if added then friendList.save() end
end

-- Clears the saved list. Friends connected at that moment are saved again on the next refresh if still tagged.
function friendList.reset()
  friendList.known = {}
  if io.fileExists(friendList.file) then io.deleteFile(friendList.file) end
  if io.fileExists(friendList.file) then
    friendList.status = 'Could not delete the friends file.'
    return
  end
  friendList.status = 'Friends list reset.'
  friendList.dirty = true
end

friendList.load()

function friendList.update(dt)
  friendList.elapsed = friendList.elapsed + dt
  if friendList.dirty or friendList.elapsed >= friendList.refreshInterval then
    friendList.elapsed = 0
    friendList.refresh()
  end
end

-- Returns the names of connected friends. Read-only copy so callers cannot change the cache.
function friendList.get()
  local copy = {}
  for i, name in ipairs(friendList.names) do copy[i] = name end
  return copy
end

function friendList.isFriend(name)
  for _, friendName in ipairs(friendList.names) do
    if friendName == name then return true end
  end
  return false
end

ac.onClientConnected(function()
  friendList.dirty = true
end)

function Debug.handleChatMessage(message, senderCarIndex, simulatedAuthor, simulatedFriend)
  if not message or message == '' then
	return false
  end
  syncKeywordProfile()
  local playerMentioned = isPlayerMentioned(message)
  local friendMessage = simulatedFriend or (senderCarIndex ~= nil and senderCarIndex >= 0 and friendList.isFriend(ac.getDriverName(senderCarIndex)))
  -- Any car on the server counts as a player; the server itself (-1) does not.
  local playerMessage = simulatedAuthor ~= nil or (senderCarIndex ~= nil and senderCarIndex >= 0)
  local senderColor = friendMessage and settings.friendColor or (playerMessage and settings.playerColor) or nil
  local matchedAlert = findMatchedAlert(message, playerMentioned, friendMessage)
  -- Showing all messages does not make non-matching messages play a sound.
  if not matchedAlert and not settings.showAllChatMessages then
	return false
  end

  local author = simulatedAuthor
  if not author and senderCarIndex == -1 then
	author = 'Server'
  elseif not author and senderCarIndex and senderCarIndex >= 0 then
	author = ac.getDriverName(senderCarIndex)
  end
  author = author and author ~= '' and author or 'Unknown'

  local alertOption
  local historyEntry
  if matchedAlert then
	local alertKey = lowerText(matchedAlert)
	alertOption = keywordOptionStore.get(alertKey)
	local muted, soundFile
	if matchedAlert == specialAlertKeys.player then
	  muted, soundFile = settings.mentionSoundMuted, settings.mentionSound
	elseif matchedAlert == specialAlertKeys.friend then
	  muted, soundFile = settings.friendSoundMuted, settings.friendSound
	else
	  muted, soundFile = loadMutedKeywords()[alertKey], loadKeywordSoundAssignments()[alertKey] or defaultAlertSoundFile
	end
	local soundToPlay = (soundFile and soundFile ~= '') and soundFile or defaultAlertSoundFile
	historyEntry = alertHistory.add({
	  time = os.date('%H:%M:%S'),
	  trigger = matchedAlert == specialAlertKeys.player and 'Player mention' or matchedAlert == specialAlertKeys.friend and 'Friend message' or matchedAlert,
	  author = author,
	  authorColor = senderColor or settings.authorColor,
	  message = message,
	  textColor = settings.textColor,
	  hidden = alertOption.hidden and true or false,
	  muted = muted and true or false,
	  soundName = soundToPlay,
	})
	if not muted then
	  -- A hidden entry waits its turn behind the alert sound instead of interrupting it.
	  if alertOption.hidden and (isAlertSoundPlaying() or #hiddenSoundQueue.items > 0) then
		hiddenSoundQueue.add(soundToPlay, alertOption.volume, historyEntry)
	  else
		playAlertSound(soundToPlay, false, nil, alertOption.volume)
	  end
	end
  end
  -- Hidden entries never show the popup, and leave the current or next display untouched.
  if alertOption and alertOption.hidden then
	return false
  end

  testMode = nil
  local authorPrefix = author:sub(1, 15)
  local maxMessageLength = 2048
  local displayMessage = message:sub(1, maxMessageLength)
  alertHistory.popupReplaced()
  alertHistory.current = historyEntry
  latestMessage = authorPrefix .. ' : ' .. displayMessage
  latestAuthorColor = senderColor
  measuredMessage = nil
  textScrollElapsed = 0
  firstScrollRequired = false
  firstScrollComplete = false
  local duration = math.min(settings.duration + #latestMessage * 0.08, 15.0)
  alertDuration = duration
  alertTimeLeft = alertDuration
  return false
end

-- CSP passes a third argument (senderSessionID) that must not reach the simulator's simulatedAuthor parameter.
ac.onChatMessage(function(message, senderCarIndex)
  return Debug.handleChatMessage(message, senderCarIndex)
end)

-- Debug colors, editable from the Tools tab and stored in settings as text.
local debugColors = {
  background = rgbm(1, 1, 1, 1),
  childBg = rgbm(0, 0, 1, 0.9),
  scrollbarBg = rgbm(0, 1, 0, 1),
  resizeGrip = rgbm(1, 0.2, 0.8, 1),
  usedSound = rgbm(1, 0.85, 0.2, 1),
  selectedSound = rgbm(1, 0.5, 0, 1),
  buttonOverflow = sliders.defaults.buttonOverflow,
}

local function encodeDebugColors()
  local parts = {}
  for _, key in ipairs({ 'background', 'childBg', 'scrollbarBg', 'resizeGrip', 'usedSound', 'selectedSound' }) do
    local c = debugColors[key]
    parts[#parts + 1] = string.format('%s:%.4f,%.4f,%.4f,%.4f', key, c.r, c.g, c.b, c.mult)
  end
  parts[#parts + 1] = string.format('buttonOverflow:%.2f', debugColors.buttonOverflow)
  return table.concat(parts, ';')
end

local function decodeDebugColors(text)
  for key, value in text:gmatch('(%a+):([^;]*)') do
    if key == 'buttonOverflow' then
      debugColors.buttonOverflow = tonumber(value) or debugColors.buttonOverflow
    elseif debugColors[key] then
      local numbers = {}
      for number in value:gmatch('[%-%d%.]+') do numbers[#numbers + 1] = tonumber(number) end
      if #numbers == 4 then debugColors[key] = rgbm(numbers[1], numbers[2], numbers[3], numbers[4]) end
    end
  end
end

local function saveDebugColors()
  local encoded = encodeDebugColors()
  if encoded ~= settings.debugColorsData then settings.debugColorsData = encoded end
end

decodeDebugColors(settings.debugColorsData)

-- The debug colour applies only while Debug mode is on; otherwise the default yellow is used.
function soundPicker.usedColor()
  return settings.debugModeEnabled and debugColors.usedSound or rgbm(1, 0.85, 0.2, 1)
end

-- The sound chosen for the alert being edited. It wins over the used colour, even when the same file is used elsewhere.
function soundPicker.selectedColor()
  return settings.debugModeEnabled and debugColors.selectedSound or rgbm(1, 0.5, 0, 1)
end

-- Draws a checkerboard slightly larger than the color button (like the picker's alpha preview), then the button on top.
local function drawColorButton(id, color, flags)
  local size = vec2(32, 20)
  local pos = ui.getCursor()
  local grow = size * (debugColors.buttonOverflow / 100)
  local topLeft = pos - grow
  local bottomRight = pos + size + grow
  local square = 4
  local light = rgbm(0.8, 0.8, 0.8, 1)
  ui.drawRectFilled(topLeft, bottomRight, rgbm(0.5, 0.5, 0.5, 1))
  for row = 0, math.ceil((bottomRight.y - topLeft.y) / square) - 1 do
    for col = 0, math.ceil((bottomRight.x - topLeft.x) / square) - 1 do
      if (row + col) % 2 == 0 then
        local a = topLeft + vec2(col * square, row * square)
        ui.drawRectFilled(a, vec2(math.min(a.x + square, bottomRight.x), math.min(a.y + square, bottomRight.y)), light)
      end
    end
  end
  ui.colorButton(id, color, flags, size)
end

local function drawColorSetting(label, key)
  ui.text(label)
  ui.sameLine()
  drawColorButton('##color_' .. key, settings[key], ui.ColorPickerFlags.AlphaPreview)
  ui.itemPopup('##color_popup_' .. key, ui.MouseButton.Left, function()
	ui.text('Choose ' .. label:lower())
	ui.colorPicker('##color_picker_' .. key, settings[key], bit.bor(
	  ui.ColorPickerFlags.AlphaBar,
	  ui.ColorPickerFlags.AlphaPreview,
	  ui.ColorPickerFlags.PickerHueWheel
	))
  end)
end

local function drawThemeColorSetting(label, key)
  ui.text(label)
  ui.sameLine()
  drawColorButton('##color_' .. key, settings[key], ui.ColorPickerFlags.NoAlpha)
  ui.itemPopup('##color_popup_' .. key, ui.MouseButton.Left, function()
	ui.text('Choose ' .. label:lower())
	local edited = ui.colorPicker('##color_picker_' .. key, settings[key], bit.bor(
	  ui.ColorPickerFlags.NoAlpha,
	  ui.ColorPickerFlags.PickerHueWheel
	))
	if edited then
	  settings[key] = rgbm(settings[key].r, settings[key].g, settings[key].b, 1)
	end
  end)
end

local function pushSettingsTheme()
  local color = settings.themeColor
  local bgColor = settings.themeBgColor
  local frameBg = rgbm(bgColor.r * 0.18, bgColor.g * 0.18, bgColor.b * 0.18, 0.96)
  local frameHovered = rgbm(bgColor.r * 0.28, bgColor.g * 0.28, bgColor.b * 0.28, 0.98)
  local frameActive = rgbm(bgColor.r * 0.38, bgColor.g * 0.38, bgColor.b * 0.38, 1)
  local button = rgbm(bgColor.r * 0.14, bgColor.g * 0.14, bgColor.b * 0.14, 0.92)
  local buttonHovered = rgbm(bgColor.r * 0.25, bgColor.g * 0.25, bgColor.b * 0.25, 0.96)
  local buttonActive = rgbm(bgColor.r * 0.35, bgColor.g * 0.35, bgColor.b * 0.35, 1)
  ui.pushStyleColor(ui.StyleColor.ChildBg, settings.debugModeEnabled and debugColors.childBg or rgbm(0, 0, 0, 0))
  ui.pushStyleColor(ui.StyleColor.ScrollbarBg, settings.debugModeEnabled and debugColors.scrollbarBg or rgbm(0.02, 0.02, 0.02, 0.53))
  ui.pushStyleColor(ui.StyleColor.FrameBg, frameBg)
  ui.pushStyleColor(ui.StyleColor.FrameBgHovered, frameHovered)
  ui.pushStyleColor(ui.StyleColor.FrameBgActive, frameActive)
  ui.pushStyleColor(ui.StyleColor.CheckMark, color)
  ui.pushStyleColor(ui.StyleColor.SliderGrab, color)
  ui.pushStyleColor(ui.StyleColor.SliderGrabActive, color)
  ui.pushStyleColor(ui.StyleColor.Button, button)
  ui.pushStyleColor(ui.StyleColor.ButtonHovered, buttonHovered)
  ui.pushStyleColor(ui.StyleColor.ButtonActive, buttonActive)
  ui.pushStyleColor(ui.StyleColor.Header, button)
  ui.pushStyleColor(ui.StyleColor.HeaderHovered, buttonHovered)
  ui.pushStyleColor(ui.StyleColor.HeaderActive, buttonActive)
  ui.pushStyleColor(ui.StyleColor.PopupBg, rgbm(bgColor.r * 0.1, bgColor.g * 0.1, bgColor.b * 0.1, 0.98))
  ui.pushStyleColor(ui.StyleColor.Border, rgbm(color.r, color.g, color.b, 0.28))
  local grip = settings.debugModeEnabled and debugColors.resizeGrip or rgbm(color.r, color.g, color.b, 0.45)
  ui.pushStyleColor(ui.StyleColor.ResizeGrip, grip)
  ui.pushStyleColor(ui.StyleColor.ResizeGripHovered, rgbm(grip.r, grip.g, grip.b, 0.8))
  ui.pushStyleColor(ui.StyleColor.ResizeGripActive, rgbm(grip.r, grip.g, grip.b, 1))
end

local function drawSoundFolderButton()
  ui.pushID('openSoundFolder')
  if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
    if io.dirExists(soundFolder) then
      local ok, err = pcall(os.openInExplorer, soundFolder)
      if ok then
        soundFolderStatus = ''
      else
        soundFolderStatus = 'Could not open the sounds folder: ' .. tostring(err)
        ac.log(App.displayName .. ': ' .. soundFolderStatus)
    Debug.warn(soundFolderStatus)
      end
    else
      soundFolderStatus = 'Sounds folder not found: ' .. soundFolder
      ac.log(App.displayName .. ': ' .. soundFolderStatus)
    end
  end
  ui.popID()
  ui.sameLine()
  ui.text('Open sounds folder')
  if soundFolderStatus ~= '' then ui.textWrapped(soundFolderStatus) end
end

local function drawAlertsTab()
  if sliders.checkbox('Play alert sound', settings.soundEnabled, sliders.defaults.soundEnabled) then
	settings.soundEnabled = not settings.soundEnabled
  end
  settings.masterVolume = sliders.withDefault('Master volume', settings.masterVolume, 0, 300, '%.0f%%', sliders.defaults.masterVolume, 1)
  drawSoundFolderButton()
  ui.textWrapped('Available sounds: .wav and .mp3 files in the sounds folder and its subfolders. If a selected file is missing or cannot be loaded, ' .. defaultAlertSoundFile .. ' is used instead.')
  if not alertSoundFileSet[defaultAlertSoundFile] then
    ui.textWrapped('Warning: the default sound ' .. defaultAlertSoundFile .. ' is missing from the sounds folder. Alerts with a missing sound will be silent.')
  end
  ui.separator()
  if sliders.checkbox('Alert when my name is mentioned', settings.mentionMe, sliders.defaults.mentionMe) then
	settings.mentionMe = not settings.mentionMe
  end
  ui.separator()
  ui.header('Alert keywords (priority order)')
  ui.textWrapped('When several entries match, the first one in this list selects the sound. Drag the handle to reorder. The player mention and friend entries can be moved, muted or hidden, but not deleted.')
  local keywords = parseKeywords()
  local keywordSoundAssignments = loadKeywordSoundAssignments()
  local mutedKeywords = loadMutedKeywords()
  local keywordOptions = keywordOptionStore.load()
  local keywordRowCenters = {}
  local keywordSettingsChanged = false
  local removedKeywordIndex = nil
  local insertAfterIndex = nil
  if #keywords == 0 then
	ui.text('No alert keywords yet.')
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = 0
	end
  end
  for index, keyword in ipairs(keywords) do
	ui.pushID('keyword' .. index)
	local specialPrefix = keyword == specialAlertKeys.player and 'mention' or (keyword == specialAlertKeys.friend and 'friend') or nil
	local isSpecial = specialPrefix ~= nil
	local fieldText = specialAlertKeys.labels[keyword] or keyword
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = index - 1
	end
	ui.separator()
	local rowTop = ui.getCursorY()
	ui.iconButton(ui.Icons.Menu, vec2(22, 22))
	if not draggingKeywordIndex and ui.itemActive() and ui.mouseDown() then
	  draggingKeywordIndex = index
	end
	ui.sameLine()
	ui.text('#' .. index)
	ui.sameLine()
	if isSpecial then
	  ui.dummy(vec2(22, 22))
	elseif ui.iconButton(ui.Icons.Trash, vec2(22, 22)) then
	  removedKeywordIndex = index
	end
	ui.text(isSpecial and 'Built-in alert' or 'Keyword or trigger phrase')
	ui.sameLine()
	local keywordWidth = math.max(40, ui.availableSpaceX())
	local keywordContentWidth = math.max(keywordWidth, ui.measureText(fieldText).x + 24)
	ui.pushStyleVar(ui.StyleVar.WindowPadding, vec2(0, 0))
	ui.setNextWindowContentSize(vec2(keywordContentWidth, 0))
	local updatedKeyword = keyword
	if ui.beginChild('##keywordScroll', vec2(keywordWidth, 22), false, ui.WindowFlags.NoScrollbar) then
	  ui.setNextItemWidth(keywordContentWidth)
	  local keywordEmpty = keyword:match('^%s*$') ~= nil
	  if keywordEmpty then
		local themeBgColor = settings.themeBgColor
		local emptyFrameBg = rgbm(themeBgColor.r * 0.08, themeBgColor.g * 0.08, themeBgColor.b * 0.08, 0.96)
		ui.pushStyleColor(ui.StyleColor.FrameBg, emptyFrameBg)
		ui.pushStyleColor(ui.StyleColor.FrameBgHovered, emptyFrameBg)
		ui.pushStyleColor(ui.StyleColor.FrameBgActive, emptyFrameBg)
	  end
	  local typedKeyword = ui.inputText('##keywordValue', fieldText, isSpecial and ui.InputTextFlags.ReadOnly or 0)
	  if not isSpecial then updatedKeyword = typedKeyword end
	  if keywordEmpty then
		ui.popStyleColor(3)
	  end
	  local maxKeywordScroll = ui.getScrollMaxX()
	  if not ui.itemActive() then
		if maxKeywordScroll > 0 then
		  local speed = 35
		  local pause = 0.8
		  local travel = maxKeywordScroll / speed
		  local cycle = 2 * (pause + travel)
		  local elapsed = (ui.time() + index * 0.4) % cycle
		  local offset = 0
		  if elapsed > pause and elapsed <= pause + travel then
			offset = (elapsed - pause) * speed
		  elseif elapsed > pause + travel and elapsed <= 2 * pause + travel then
			offset = maxKeywordScroll
		  elseif elapsed > 2 * pause + travel then
			offset = maxKeywordScroll - (elapsed - 2 * pause - travel) * speed
		  end
		  ui.setScrollX(offset)
		else
		  ui.setScrollX(0)
		end
	  end
	end
	ui.endChild()
	ui.popStyleVar()
	local oldKey = lowerText(keyword:match('^%s*(.-)%s*$'))
	local newKey = lowerText(updatedKeyword:match('^%s*(.-)%s*$'))
	if updatedKeyword ~= keyword then
	  if oldKey ~= '' and newKey ~= '' and oldKey ~= newKey then
		if keywordSoundAssignments[oldKey] and not keywordSoundAssignments[newKey] then
		  keywordSoundAssignments[newKey] = keywordSoundAssignments[oldKey]
		end
		if mutedKeywords[oldKey] then mutedKeywords[newKey] = true end
		if keywordOptions[oldKey] and not keywordOptions[newKey] then keywordOptions[newKey] = keywordOptions[oldKey] end
	  end
	  keywords[index] = updatedKeyword
	  keywordSettingsChanged = true
	end
	ui.indent(22)
	local keywordKey = newKey
	local selectedSound
	if isSpecial then selectedSound = settings[specialPrefix .. 'Sound'] else selectedSound = keywordSoundAssignments[keywordKey] end
	local option = keywordOptionStore.get(keywordKey)
	local function setSelectedSound(value)
		  soundPicker.remember(value)
	  if isSpecial then
		settings[specialPrefix .. 'Sound'] = value
	  else
		keywordSoundAssignments[keywordKey] = value
	  end
	  keywordSettingsChanged = true
	end
	if keywordKey ~= '' then
	  if ui.iconButton(option.hidden and ui.Icons.Hide or ui.Icons.Eye, vec2(22, 22)) then
		keywordOptions[keywordKey] = { volume = option.volume, hidden = not option.hidden }
		keywordSettingsChanged = true
	  end
	else
	  ui.dummy(vec2(22, 22))
	end
	ui.sameLine()
	local soundMuted
	if isSpecial then
	  soundMuted = settings[specialPrefix .. 'SoundMuted']
	else
	  soundMuted = mutedKeywords[keywordKey]
	end
	if ui.iconButton(soundMuted and ui.Icons.Mute or ui.Icons.VolumeHigh, vec2(22, 22)) then
	  if isSpecial then
		settings[specialPrefix .. 'SoundMuted'] = not soundMuted
	  else
		mutedKeywords[keywordKey] = not soundMuted
	  end

	  keywordSettingsChanged = true
	end
	ui.sameLine()
	local keywordTestKey = specialPrefix or ('keyword:' .. keywordKey)
	if ui.iconButton(isSoundTestPlaying(keywordTestKey) and ui.Icons.Stop or ui.Icons.Play, vec2(22, 22)) then
	  playAlertSound(selectedSound or defaultAlertSoundFile, true, keywordTestKey, option.volume)
	end
	ui.sameLine()
	ui.setNextItemWidth(90)
	local volume = sliders.withDefault('##keywordVolume', option.volume, 0, 300, '%.0f%%', sliders.defaults.keywordVolume, 1)
	if keywordKey ~= '' and volume ~= option.volume then
	  keywordOptions[keywordKey] = { volume = volume, hidden = option.hidden }
	  keywordSettingsChanged = true
	end
	ui.sameLine()
	local keywordSoundWidth = ui.availableSpaceX()
	soundPicker.drawFile('##keywordSound', selectedSound, keywordSoundWidth, index, nil, soundPicker.usedSounds(keywordSoundAssignments), setSelectedSound)
	keywordRowCenters[index] = (rowTop + ui.getCursorY() + 22) / 2
	ui.unindent(22)
	ui.separator()
	ui.popID()
  end
  if #keywords > 0 then
	ui.pushID('keywordAppend')
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = #keywords
	end
	ui.popID()
  end
  if removedKeywordIndex then
	table.remove(keywords, removedKeywordIndex)
	keywordSettingsChanged = true
  elseif insertAfterIndex then
	table.insert(keywords, insertAfterIndex + 1, '')
	keywordSettingsChanged = true
  end

  if draggingKeywordIndex and ui.mouseDown() and #keywords > 1 then
	local mouseY = ui.mouseLocalPos().y
	local previousIndex = draggingKeywordIndex - 1
	local nextIndex = draggingKeywordIndex + 1
	if previousIndex >= 1 and mouseY < keywordRowCenters[previousIndex] then
	  keywords[draggingKeywordIndex], keywords[previousIndex] = keywords[previousIndex], keywords[draggingKeywordIndex]
	  draggingKeywordIndex = previousIndex
	  keywordSettingsChanged = true
	elseif nextIndex <= #keywords and mouseY > keywordRowCenters[nextIndex] then
	  keywords[draggingKeywordIndex], keywords[nextIndex] = keywords[nextIndex], keywords[draggingKeywordIndex]
	  draggingKeywordIndex = nextIndex
	  keywordSettingsChanged = true
	end
  end
  if not ui.mouseDown() then draggingKeywordIndex = nil end
  if keywordSettingsChanged then
	local activeKeywords = {}
	for _, keyword in ipairs(keywords) do
	  local keywordKey = lowerText(keyword:match('^%s*(.-)%s*$'))
	  if keywordKey ~= '' then activeKeywords[keywordKey] = true end
	end
	for keyword in pairs(keywordSoundAssignments) do
	  if not activeKeywords[keyword] then keywordSoundAssignments[keyword] = nil end
	end
	for keyword in pairs(mutedKeywords) do
	  if not activeKeywords[keyword] then mutedKeywords[keyword] = nil end
	end
	for keyword in pairs(keywordOptions) do
	  if not activeKeywords[keyword] then keywordOptions[keyword] = nil end
	end
	saveKeywords(keywords)
	saveKeywordSoundAssignments(keywordSoundAssignments)
	saveMutedKeywords(mutedKeywords)
	keywordOptionStore.save(keywordOptions)
	if activeKeywordProfileKey then
	  saveKeywordProfile(activeKeywordProfileKey)
	elseif settings.useServerKeywordProfiles then
	  settings.keywordProfileFallback = stringify(captureKeywordProfile(), true)
	end
  end
end

local triggerTestAlert

local function drawDisplayTab()
  ui.header('Test & Preview')
  if ui.button('Test short preview', vec2(-0.1, 0)) then
	triggerTestAlert('short')
  end
  if ui.button('Test long message', vec2(-0.1, 0)) then
	triggerTestAlert('long')
  end
  if testMode and ui.button('Stop test', vec2(-0.1, 0)) then
	testMode = nil
	testMessagePending = nil
	latestMessage = ''
	textScrollElapsed = 0
	alertTimeLeft = 0
	firstScrollRequired = false
	firstScrollComplete = false
	measuredMessage = nil
  end

  ui.separator()
  ui.header('Display Settings')
  if sliders.checkbox('Show all chat messages', settings.showAllChatMessages, sliders.defaults.showAllChatMessages) then
	settings.showAllChatMessages = not settings.showAllChatMessages
  end
  if sliders.checkbox('Hide alert when not hovered', settings.hideWhenNotHovered, sliders.defaults.hideWhenNotHovered) then
	settings.hideWhenNotHovered = not settings.hideWhenNotHovered
  end
  settings.textSize = sliders.withDefault('Text size', settings.textSize, 8, 96, '%.0f px', sliders.defaults.textSize, 1)
  settings.duration = sliders.withDefault('Base display time', settings.duration, 1, 10, '%.1f s', sliders.defaults.duration, 0.1)
  settings.opacity = sliders.withDefault('Alert opacity multiplier', settings.opacity, 0, 100, '%.0f%%', sliders.defaults.opacity, 1)
  ui.separator()
  drawColorSetting('Text color', 'textColor')
  drawColorSetting('Author color', 'authorColor')
  drawColorSetting('Outline color', 'outlineColor')
  local outlineScale = math.min(maxOutlineScale, settings.outlineThicknessPercent * settings.textSize / 100)
  local outlineDefault = math.min(maxOutlineScale, sliders.defaults.outlineThicknessPercent * settings.textSize / 100)
  outlineScale = sliders.withDefault('Outline scale (CSP)', outlineScale, 0, maxOutlineScale, '%.1f', outlineDefault, 0.1)
  settings.outlineThicknessPercent = outlineScale * 100 / settings.textSize
  if sliders.checkbox('Soft outline gradient', settings.softOutline, sliders.defaults.softOutline) then
	settings.softOutline = not settings.softOutline
  end
  if sliders.checkbox('Show background', settings.backgroundEnabled, sliders.defaults.backgroundEnabled) then
	settings.backgroundEnabled = not settings.backgroundEnabled
  end
  drawColorSetting('Background color', 'backgroundColor')
  drawColorSetting('Accent color', 'accentColor')
end

local function drawVehicleDisplayProfiles()
  if sliders.checkbox('Use separate display settings for each car', settings.useVehicleDisplayProfiles, sliders.defaults.useVehicleDisplayProfiles) then
	settings.useVehicleDisplayProfiles = not settings.useVehicleDisplayProfiles
	syncVehicleDisplayProfile()
  end
  local vehicleKey = getVehicleProfileKey()
  local vehicleName = ac.getCarName(0) or ac.getCarID(0) or 'No car detected'
  ui.text('Current car: ' .. vehicleName)
  if ui.button('Save display for this car', vec2(-0.1, 0)) then
	if saveVehicleDisplayProfile(vehicleKey) then
	  profileStatus = 'Display profile saved for ' .. vehicleName .. '.'
	else
	  profileStatus = 'A car must be loaded to save a vehicle profile.'
	end
  end
  if ui.button('Reset display for this car', vec2(-0.1, 0)) then
	if resetVehicleDisplayProfile(vehicleKey) then
	  profileStatus = 'Display reset to defaults for ' .. vehicleName .. '.'
	else
	  profileStatus = 'Display settings reset, but the chat window could not be repositioned.'
	end
  end
  if ui.button('Save this display for all cars (overwrite)', vec2(-0.1, 0)) then
	confirmOverwriteAllCars = true
	overwriteAllCarsConfirmed = false
  end
  if confirmOverwriteAllCars then
	ui.textWrapped('This permanently overwrites every saved vehicle display profile. Save a backup first if you may want to restore them.')
	if ui.checkbox('I understand and want to overwrite all car profiles', overwriteAllCarsConfirmed) then
	  overwriteAllCarsConfirmed = not overwriteAllCarsConfirmed
	end
	if overwriteAllCarsConfirmed and ui.button('Confirm overwrite all car displays', vec2(-0.1, 0)) then
	  if saveDisplayForAllCars() then
		profileStatus = 'Current display saved for all cars; existing profiles were overwritten.'
	  else
		profileStatus = 'Could not overwrite all car profiles because the chat window is unavailable.'
	  end
	  confirmOverwriteAllCars = false
	  overwriteAllCarsConfirmed = false
	end
	if ui.button('Cancel overwrite', vec2(-0.1, 0)) then
	  confirmOverwriteAllCars = false
	  overwriteAllCarsConfirmed = false
	end
  end
end

local function drawKeywordProfiles()
  ui.separator()
  if sliders.checkbox('Use separate keyword settings per server', settings.useServerKeywordProfiles, sliders.defaults.useServerKeywordProfiles) then
	if not settings.useServerKeywordProfiles then
	  settings.keywordProfileFallback = stringify(captureKeywordProfile(), true)
	end
	settings.useServerKeywordProfiles = not settings.useServerKeywordProfiles
	keywordProfileContextInitialized = false
	syncKeywordProfile()
  end
  local profileKey, contextName = getKeywordProfileContext()
  ui.text('Current context: ' .. (contextName or 'No active session'))
  if profileKey then
	if ui.button('Save keywords for this context', vec2(-0.1, 0)) then
	  if saveKeywordProfile(profileKey) then
		profileStatus = 'Keyword profile saved for ' .. contextName .. '.'
	  else
		profileStatus = 'Could not save the keyword profile for this context.'
	  end
	end
	if ui.button('Reset keywords for this context', vec2(-0.1, 0)) then
	  if resetKeywordProfile(profileKey) then
		profileStatus = 'Keyword profile reset for ' .. contextName .. '.'
	  else
		profileStatus = 'Could not reset the keyword profile for this context.'
	  end
	end
  else
	ui.textDisabled('Save and reset are available during an active server session.')
  end
end

local sharedExportName = ''
local sharedExportNameKey = nil

local function defaultSharedExportName(profileKey)
  local info = sanitizeProfileInfo(keywordProfiles[profileKey] and keywordProfiles[profileKey].info) or newProfileInfo()
  local serverName = info.serverName ~= '' and info.serverName or profileKey:sub(8)
  local creator = info.createdBy ~= '' and info.createdBy or 'unknown player'
  return serverName .. ' - ' .. creator .. ' - ' .. os.date('%Y/%m/%d-%H:%M', info.createdAt)
end

local function drawSharedKeywordProfiles()
  ui.separator()
  ui.text('Share server keyword profile')
  local profileKey, contextName = getKeywordProfileContext()
  if profileKey then
	if sharedExportNameKey ~= profileKey then
	  sharedExportNameKey = profileKey
	  sharedExportName = defaultSharedExportName(profileKey)
	end
	ui.text('Shared file name')
	ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
	sharedExportName = ui.inputText('##sharedExportName', sharedExportName)
	if ui.button('Export current profile for sharing', vec2(-0.1, 0)) then
	  exportSharedKeywordProfile(profileKey, contextName, sharedExportName)
	end
	if pendingOverwrite.export and normalizeBackupName(sharedExportName):sub(1, 80) == pendingOverwrite.export then
	  if ui.button('Confirm overwrite of this shared file', vec2(-0.1, 0)) then
		exportSharedKeywordProfile(profileKey, contextName, sharedExportName)
	  end
	  if ui.button('Cancel shared file overwrite', vec2(-0.1, 0)) then pendingOverwrite.export = nil end
	end
	ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
	local selectedFileLabel = selectedSharedKeywordFile ~= '' and selectedSharedKeywordFile or 'No shared files found'
	if ui.beginCombo('##sharedKeywordFiles', selectedFileLabel) then
	  if not comboWasOpen['##sharedKeywordFiles'] then
		refreshSharedKeywordFiles()
		comboWasOpen['##sharedKeywordFiles'] = true
	  end
	  for _, fileName in ipairs(sharedKeywordFiles) do
		if ui.selectable(fileName, selectedSharedKeywordFile == fileName) then
		  selectedSharedKeywordFile = fileName
		  pendingSharedKeywordImport = nil
		end
	  end
	  ui.endCombo()
	else
	  comboWasOpen['##sharedKeywordFiles'] = false
	end
	ui.sameLine()
	ui.pushID('openSharedKeywordFolder')
	if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
	  if ensureSharedKeywordFolder() then os.openInExplorer(sharedKeywordFolder) end
	end
	ui.popID()
	if ui.button('Prepare import into this server', vec2(-0.1, 0)) then
	  stageSharedKeywordImport(selectedSharedKeywordFile, profileKey, contextName)
	end
	if pendingSharedKeywordImport then
	  ui.textWrapped('Import from "' .. pendingSharedKeywordImport.serverLabel .. '" into ' .. pendingSharedKeywordImport.targetLabel .. '? This replaces this server-specific keyword profile.')
	  if ui.button('Confirm import and replace server profile', vec2(-0.1, 0)) then
		applyStagedSharedKeywordImport(profileKey)
	  end
	  if ui.button('Cancel import', vec2(-0.1, 0)) then pendingSharedKeywordImport = nil end
	end
	ui.textDisabled('Copy shared .json files into this folder. Import enables server-specific keyword profiles.')
	ui.textDisabled('Share folder: ' .. sharedKeywordFolder)
  else
	ui.textDisabled('Connect to a server to export or import its keyword profile.')
  end
end

local function drawSettingsBackup()
  ui.separator()
  ui.text('Backup name (used by Save)')
  ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
  settings.backupName = ui.inputText('##backupName', settings.backupName)
  ui.sameLine()
  ui.pushID('openSettingsBackupFolder')
  if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
	if ensureBackupFolder() then
	  os.openInExplorer(backupFolder)
	else
	  profileStatus = backupFolderStatus
	end
  end
  ui.popID()
  local selectedBackupName = normalizeBackupName(selectedBackupToLoad)
  local backupPreview = selectedBackupName ~= '' and selectedBackupName or 'Select a backup'
  if selectedBackupName:lower() == 'default' then backupPreview = 'Default (built-in)' end
  ui.text('Selected backup (used by Load)')
  if ui.beginCombo('##backupList', backupPreview) then
	if not comboWasOpen['##backupList'] then
	  refreshBackupList()
	  comboWasOpen['##backupList'] = true
	end
	for _, backupName in ipairs(availableBackups) do
	  local label = backupName == 'Default' and 'Default (built-in)' or backupName
	  if ui.selectable(label, selectedBackupName:lower() == backupName:lower()) then
		selectedBackupToLoad = backupName
	  end
	end
	ui.endCombo()
  else
	comboWasOpen['##backupList'] = false
  end
  ui.textDisabled('Your own settings backups folder: ' .. backupFolder)
  if backupFolderStatus ~= '' then ui.textWrapped('Backup status: ' .. backupFolderStatus) end
  if ui.button('Save current settings', vec2(-0.1, 0)) then
	saveSettingsBackup()
  end
  if pendingOverwrite.backup and normalizeBackupName(settings.backupName) == pendingOverwrite.backup then
	if ui.button('Confirm overwrite of this backup', vec2(-0.1, 0)) then
	  saveSettingsBackup()
	end
	if ui.button('Cancel backup overwrite', vec2(-0.1, 0)) then pendingOverwrite.backup = nil end
  end
  ui.textDisabled('Will load: ' .. backupPreview)
  if ui.button('Load selected backup', vec2(-0.1, 0)) then
	loadSettingsBackup()
  end
end

local function keywordKey(keyword)
  return lowerText(keyword:match('^%s*(.-)%s*$'))
end

local function ensureServerKeywordFolder()
  if io.dirExists(serverKeywordFolder) then return true end
  if io.createDir(serverKeywordFolder) and io.dirExists(serverKeywordFolder) then return true end
  ac.log(App.displayName .. ': could not create ' .. serverKeywordFolder)
  return false
end

local function readPlainKeywordFile(filePath)
  local data = io.load(filePath)
  if type(data) ~= 'string' or #data == 0 or #data > maximumBackupSize then
    return nil, 'Keyword text file is empty or too large.'
  end
  local entries = {}
  local seen = {}
  for line in data:gmatch('[^\r\n]+') do
    local keyword = line:match('^%s*(.-)%s*$')
    local key = keywordKey(keyword)
    if keyword ~= '' and not seen[key] and #entries < 256 then
      seen[key] = true
      entries[#entries + 1] = '=' .. encodeAssignmentValue(keyword)
    end
  end
  return {
    keywords = '',
    keywordRows = 'v1:' .. table.concat(entries, ';'),
    keywordSoundAssignments = '',
    mutedKeywords = '',
    keywordOptions = ''
  }
end

local function formatProfileInfo(info, fallbackServer)
  local serverName = info and info.serverName ~= '' and info.serverName or fallbackServer
  local creator = info and info.createdBy ~= '' and info.createdBy or 'unknown player'
  local createdText = info and os.date('%d/%m/%Y %H:%M', info.createdAt) or 'date unknown'
  return serverName .. ' - ' .. creator .. ' - ' .. createdText
end

local function describeServerKeywordFile(fileName)
  if not fileName:match('%.json$') then return 'Text file: ' .. fileName end
  local payload = readSharedKeywordFile(serverKeywordFolder .. '\\' .. fileName)
  if not payload then return 'Invalid file: ' .. fileName end
  local serverName = cleanProfileText(payload.serverName, 256)
  if serverName == '' then serverName = cleanProfileText(payload.serverLabel, 256) end
  return formatProfileInfo(sanitizeProfileInfo(payload.profile.info), serverName)
end

local function refreshServerKeywordSources()
  serverKeywordSources = {}
  ensureServerKeywordFolder()

  local profileKeys = {}
  for profileKey, profile in pairs(keywordProfiles) do
    if type(profileKey) == 'string' and profileKey:sub(1, 7) == 'server:' and validateKeywordProfile(profile) then
      profileKeys[#profileKeys + 1] = profileKey
    end
  end
  table.sort(profileKeys)
  for _, profileKey in ipairs(profileKeys) do
    local info = sanitizeProfileInfo(keywordProfiles[profileKey].info)
    serverKeywordSources[#serverKeywordSources + 1] = { id = 'profile:' .. profileKey, kind = 'profile', label = formatProfileInfo(info, profileKey:sub(8)) }
  end

  local fileNames = {}
  for _, pattern in ipairs({ '*.json', '*.txt' }) do
    for _, fileName in ipairs(io.scanDir(serverKeywordFolder, pattern) or {}) do
      if not fileName:find('^%.') and not fileName:find('..', 1, true) and not fileName:find('[/\\%c]') then
        fileNames[#fileNames + 1] = fileName
      end
    end
  end
  table.sort(fileNames, function(a, b) return a:lower() < b:lower() end)
  for _, fileName in ipairs(fileNames) do
    serverKeywordSources[#serverKeywordSources + 1] = { id = 'file:' .. fileName, kind = 'file', label = describeServerKeywordFile(fileName) }
  end

  if selectedServerKeywordSource then
    local current = nil
    for _, source in ipairs(serverKeywordSources) do
      if source.id == selectedServerKeywordSource.id then current = source end
    end
    selectedServerKeywordSource = current
  end
end

local function resolveServerKeywordSource(source)
  if not source then return nil, 'Select a server keyword list first.' end
  local profileKey = source.id:match('^profile:(.+)$')
  if profileKey then
    local profile = keywordProfiles[profileKey]
    if not validateKeywordProfile(profile) then return nil, 'The saved profile is missing or invalid.' end
    return profile
  end
  local fileName = source.id:match('^file:(.+)$')
  if not fileName then return nil, 'Unknown keyword list.' end
  local filePath = serverKeywordFolder .. '\\' .. fileName
  if fileName:match('%.json$') then
    local payload, readError = readSharedKeywordFile(filePath)
    if not payload then return nil, readError end
    return payload.profile
  end
  if fileName:match('%.txt$') then return readPlainKeywordFile(filePath) end
  return nil, 'Unsupported keyword list file.'
end

local function applyServerKeywordSource(source, replace)
  local profile, resolveError = resolveServerKeywordSource(source)
  if not profile then
    profileStatus = resolveError
    return false
  end

  local keywords = {}
  local seen = {}
  if not replace then
    for index, keyword in ipairs(parseKeywords()) do
      keywords[index] = keyword
      seen[keywordKey(keyword)] = true
    end
  end

  local kept, skipped, capped = 0, 0, false
  for _, keyword in ipairs(decodeKeywordRows(profile.keywordRows)) do
    local trimmed = keyword:match('^%s*(.-)%s*$')
    local key = keywordKey(trimmed)
    if trimmed == '' or seen[key] then
      skipped = skipped + 1
    elseif #keywords >= 256 then
      capped = true
      break
    else
      keywords[#keywords + 1] = trimmed
      seen[key] = true
      kept = kept + 1
    end
  end

  if replace then
    settings.keywordSoundAssignments = profile.keywordSoundAssignments
    settings.mutedKeywords = profile.mutedKeywords
    settings.keywordOptions = profile.keywordOptions or ''
  end
  saveKeywords(keywords)

  if replace then
    profileStatus = string.format('Keyword list replaced from %s: %d keyword(s), %d duplicate or empty line(s) removed.', source.label, kept, skipped)
  else
    profileStatus = string.format('Keywords added from %s: %d new, %d already present or empty.', source.label, kept, skipped)
  end
  if capped then profileStatus = profileStatus .. ' The 256 keyword limit was reached.' end
  return true
end

local function drawServerSourceCombo(comboId, kind, previewText, emptyText)
  ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
  if not ui.beginCombo(comboId, previewText) then
    comboWasOpen[comboId] = false
    return
  end
  if not comboWasOpen[comboId] then
    refreshServerKeywordSources()
    comboWasOpen[comboId] = true
  end
  local found = false
  for _, source in ipairs(serverKeywordSources) do
    if source.kind == kind then
      found = true
      if ui.selectable(source.label, selectedServerKeywordSource ~= nil and selectedServerKeywordSource.id == source.id) then
        selectedServerKeywordSource = source
      end
    end
  end
  if not found then ui.textDisabled(emptyText) end
  ui.endCombo()
end

local function drawServerSpecificSettings()
  ui.separator()
  if sliders.checkbox('Auto-save settings for each server', settings.autoSaveServerSettings, sliders.defaults.autoSaveServerSettings) then
	settings.autoSaveServerSettings = not settings.autoSaveServerSettings
  end
  ui.textWrapped('When enabled, your settings are automatically saved for each server you join and restored when you return.')
  ui.text('Keyword list from a saved server')
  ui.textDisabled('Saved by you (your server profiles)')
  local selectedProfileLabel = selectedServerKeywordSource and selectedServerKeywordSource.kind == 'profile' and selectedServerKeywordSource.label or 'Select a list saved by you'
  drawServerSourceCombo('##serverProfileSources', 'profile', selectedProfileLabel, 'No lists saved by you yet.')
  ui.textDisabled('Server shared keywords folder (mod install folder):')
  ui.textDisabled(serverKeywordFolder)
  local selectedFileLabel = selectedServerKeywordSource and selectedServerKeywordSource.kind == 'file' and selectedServerKeywordSource.label or 'Select a list from this folder'
  drawServerSourceCombo('##serverFileSources', 'file', selectedFileLabel, 'No lists in this folder yet.')
  ui.textDisabled('Manual lists: .json (share format) or .txt with one keyword per line.')
  ui.text('Selected list (read-only, pick another list above to replace it)')
  ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
  ui.inputText('##selectedServerKeywordSource', selectedServerKeywordSource and selectedServerKeywordSource.label or '(nothing selected)', ui.InputTextFlags.ReadOnly)
  if selectedServerKeywordSource then
	ui.textWrapped('Apply "' .. selectedServerKeywordSource.label .. '" to your current keyword list?')
	if ui.button('Add to the end of the current list', vec2(-0.1, 0)) then
	  applyServerKeywordSource(selectedServerKeywordSource, false)
	end
	if ui.button('Replace the current list', vec2(-0.1, 0)) then
	  applyServerKeywordSource(selectedServerKeywordSource, true)
	end
  end
  ui.pushID('openServerKeywordFolder')
  if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
	if ensureSharedKeywordFolder() then
	  os.openInExplorer(sharedKeywordFolder)
	else
	  profileStatus = 'Could not access the shared keyword folder: ' .. sharedKeywordFolder
	end
  end
  ui.popID()
  ui.sameLine()
  ui.text('Your saved keyword lists (created by you, exports)')
  ui.textDisabled(sharedKeywordFolder)
  ui.pushID('openServerBackupFolder')
  if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
	if ensureServerKeywordFolder() then
	  os.openInExplorer(serverKeywordFolder)
	else
	  profileStatus = 'Could not access the server keyword folder: ' .. serverKeywordFolder
	end
  end
  ui.popID()
  ui.sameLine()
  ui.text('Server keyword lists to share or import (manual files)')
  ui.textDisabled(serverKeywordFolder)
  ui.textDisabled('Automatic server backups are kept in the Servers subfolder, separate from your manual backups.')
end

local function drawProfilesTab()
  ui.header('Mes réglages')
  drawVehicleDisplayProfiles()
  drawSettingsBackup()
  ui.header('Serveurs (auto)')
  drawServerSpecificSettings()
  drawKeywordProfiles()
  ui.header('Partage de mots-clés')
  drawSharedKeywordProfiles()
  if profileStatus ~= '' then 
	ui.separator()
	ui.textWrapped('Status: ' .. profileStatus) 
  end
end

function triggerTestAlert(messageType) -- Assigns the local forward-declared above drawDisplayTab
  local ownName = ac.getDriverName(0) or 'Driver'
  if messageType == 'short' then
	testMessagePending = { mode = 'short', message = ownName:sub(1, 15) .. ' : This is a test message preview.', duration = 10 }
  elseif messageType == 'long' then
	testMessagePending = { mode = 'long', message = ownName:sub(1, 15) .. ' : ' .. longPreviewMessage, duration = 15 }
  end
  ac.setWindowOpen('main', true)
end

local function drawDebugColorSetting(label, key)
  ui.text(label)
  ui.sameLine()
  drawColorButton('##debug_color_' .. key, debugColors[key], ui.ColorPickerFlags.AlphaPreview)
  ui.itemPopup('##debug_color_popup_' .. key, ui.MouseButton.Left, function()
    ui.text('Choose ' .. label:lower())
    ui.colorPicker('##debug_color_picker_' .. key, debugColors[key], bit.bor(
      ui.ColorPickerFlags.AlphaBar,
      ui.ColorPickerFlags.AlphaPreview,
      ui.ColorPickerFlags.PickerHueWheel
    ))
  end)
end

local function drawToolsTab()
  ui.header('Reset Settings')
  if ui.button('Reset all settings to defaults', vec2(-0.1, 0)) then
	settings.backupName = 'Default'
	resetSettings()
  end
  if ui.button('Reset audio settings', vec2(-0.1, 0)) then
	resetAudioSettings()
  end
  if ui.button('Reset alert appearance', vec2(-0.1, 0)) then
	resetAlertAppearanceSettings()
  end
  if ui.button('Reset keyword settings', vec2(-0.1, 0)) then
	resetKeywordSettings()
  end

  ui.separator()
  ui.header('Debug')
  local cspVersion = ac.getPatchVersionCode and ac.getPatchVersionCode() or 'unknown'
  ui.text('CSP Version: ' .. tostring(cspVersion))
  local uiScale = ac.getUI() and ac.getUI().uiScale or 'unknown'
  ui.text('UI Scale: ' .. tostring(uiScale))
  local vehicleName = ac.getCarName(0) or ac.getCarID(0) or 'No car'
  ui.text('Current vehicle: ' .. vehicleName)
  local serverName = ac.getServerName() or 'Offline'
  ui.text('Server: ' .. serverName)
  if ui.button('Print debug to log', vec2(-0.1, 0)) then
	Debug.info(App.displayName .. ' Debug Info:')
	Debug.info('  CSP Version: ' .. tostring(cspVersion))
	Debug.info('  UI Scale: ' .. tostring(uiScale))
	Debug.info('  Vehicle: ' .. vehicleName)
	Debug.info('  Server: ' .. serverName)
	Debug.info('  Test mode: ' .. tostring(testMode))
  end
  ui.separator()
  local friends = friendList.get()
  ui.treeNode('Friends (' .. #friendList.known .. ' saved, ' .. #friends .. ' connected)###friendsDebug', function()
    if #friendList.known == 0 then
      ui.textDisabled('No friends saved yet. A tagged friend is saved when seen in an online race.')
    end
    for _, name in ipairs(friendList.known) do
      if friendList.isFriend(name) then
        ui.text(name .. '  (connected)')
      else
        ui.textDisabled(name)
      end
    end
    ui.pushID('openFriendsFolder')
    if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
      if friendList.ensureFolder() then
        os.openInExplorer(friendList.folder)
      else
        friendList.status = 'Could not create the friends folder.'
      end
    end
    ui.popID()
    ui.sameLine()
    if ui.button('Reset friends list') then friendList.reset() end
    if friendList.status ~= '' then ui.textWrapped(friendList.status) end
    ui.textDisabled('File: ' .. friendList.file)
  end)
  ui.separator()
  ui.treeNode('Alert history (' .. #alertHistory.items .. ' of ' .. alertHistory.max .. ')###alertHistoryDebug', function()
	alertHistory.drawEntries()
  end)
  if ui.button('Print alert history to log', vec2(-0.1, 0)) then
	Debug.info(App.displayName .. ' History (' .. #alertHistory.items .. ' entries):')
	for _, entry in ipairs(alertHistory.items) do
	  Debug.info(alertHistory.formatEntry(entry))
	end
  end
  if ui.button('Clear alert history', vec2(-0.1, 0)) then
	alertHistory.clear()
  end
  ui.separator()
  ui.text('Simulate a chat message (offline testing). Use a keyword or your name to trigger an alert.')
  Debug.simulator.author = ui.inputText('##simulatedAuthor', Debug.simulator.author)
  Debug.simulator.text = ui.inputText('##simulatedText', Debug.simulator.text)
  if sliders.checkbox('Simulated sender is a friend', Debug.simulator.friend, sliders.defaults.simulatorFriend) then
	Debug.simulator.friend = not Debug.simulator.friend
  end
  if ui.button('Simulate chat message', vec2(-0.1, 0)) then
	Debug.handleChatMessage(Debug.simulator.text, nil, Debug.simulator.author ~= '' and Debug.simulator.author or 'Simulated driver', Debug.simulator.friend)
  end
  ui.separator()
  ui.text('Debug colors')
  if sliders.checkbox('Debug mode (diagnostic colors)', settings.debugModeEnabled, sliders.defaults.debugModeEnabled) then
    settings.debugModeEnabled = not settings.debugModeEnabled
  end
  if settings.debugModeEnabled then
    drawColorSetting('Player color', 'playerColor')
    drawColorSetting('Friend color', 'friendColor')
    drawThemeColorSetting('Settings theme color 1', 'themeColor')
    drawThemeColorSetting('Settings theme color 2 (background)', 'themeBgColor')
    drawDebugColorSetting('Background rectangle', 'background')
    drawDebugColorSetting('Child background', 'childBg')
    drawDebugColorSetting('Scrollbar background', 'scrollbarBg')
    drawDebugColorSetting('Resize grip', 'resizeGrip')
    drawDebugColorSetting('Used sound (already in an alert)', 'usedSound')
    drawDebugColorSetting('Selected sound (this alert)', 'selectedSound')
  end
  debugColors.buttonOverflow = sliders.withDefault('Color button overflow', debugColors.buttonOverflow, 0, 20, '%.1f%%', sliders.defaults.buttonOverflow, 0.1)
  saveDebugColors()
end

-- Lists the session's alerts, newest first. Used by the History tab and Tools > Debug.
function alertHistory.drawEntries()
  local grey = rgbm(0.6, 0.6, 0.6, 1)
  if #alertHistory.items == 0 then
    ui.textColored('No alerts triggered yet this session.', grey)
    return
  end
  for i = #alertHistory.items, 1, -1 do
    local entry = alertHistory.items[i]
    ui.textColored(entry.time .. '  ' .. entry.trigger, rgbm(1, 1, 1, 1))
    ui.sameLine(0, 10)
    ui.icon(entry.hidden and ui.Icons.Hide or ui.Icons.Eye, 14)
    ui.sameLine(0, 4)
    ui.textColored(entry.hidden and 'no popup' or 'popup', grey)
    ui.sameLine(0, 10)
    ui.icon(entry.muted and ui.Icons.Mute or ui.Icons.VolumeHigh, 14)
    ui.sameLine(0, 4)
    ui.textColored((entry.muted and 'muted, ' or '') .. entry.soundName, grey)
    ui.textColored(entry.author, entry.authorColor)
    ui.pushStyleColor(ui.StyleColor.Text, entry.textColor)
    ui.textWrapped(entry.message)
    ui.popStyleColor()
    for _, event in ipairs(entry.events) do
      ui.textColored('  ' .. event.time .. '  ' .. event.text, grey)
    end
    ui.separator()
  end
end

-- Copy and clear for the History tab.
function alertHistory.drawTab()
  ui.textWrapped(#alertHistory.items .. ' of ' .. alertHistory.max .. ' alerts this session. Kept in memory only and cleared when the app closes.')
  if ui.button('Copy history', vec2(-0.1, 0)) then
    local lines = {}
    for _, entry in ipairs(alertHistory.items) do
      table.insert(lines, alertHistory.formatEntry(entry))
    end
    ac.setClipboardText(table.concat(lines, '\n'))
  end
  if ui.button('Clear history', vec2(-0.1, 0)) then
    alertHistory.clear()
  end
  ui.separator()
  alertHistory.drawEntries()
end


local configGripSize = 14

function windowConfig()
  syncVehicleDisplayProfile()
  syncKeywordProfile()
  if ui.isWindowAppearing() then
	refreshAlertSoundFiles()
	refreshBackupList()
	refreshSharedKeywordFiles()
  end

  -- Force window to stay visible (not fade)
  ac.forceFadingIn()

  pushSettingsTheme()

  -- Lighter background below the title bar, drawn over ImGui's native window background.
  -- The native background is drawn before this callback, so the resize grip is redrawn on top to stay visible.
  local windowSize = ui.windowSize()
  local backgroundTop = ui.cursorStartPos().y - 10
  local bandColor = settings.debugModeEnabled and debugColors.background or rgbm(0.14, 0.14, 0.14, 0.96)
  ui.drawRectFilled(vec2(0, backgroundTop), vec2(windowSize.x, windowSize.y - configGripSize), bandColor)

  ui.tabBar('configTabs', bit.bor(ui.TabBarFlags.IntegratedTabs, ui.TabBarFlags.FittingPolicyScroll, ui.TabBarFlags.TabListPopupButton), function()
	ui.tabItem('Alerts', function()
	  -- Scrollable content area for this tab only
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('AlertsContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		drawAlertsTab()
		ui.endChild()
	  end
	end)
	ui.tabItem('Display', function()
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('DisplayContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		drawDisplayTab()
		ui.endChild()
	  end
	end)
	ui.tabItem('Profiles', function()
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('ProfilesContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		drawProfilesTab()
		ui.endChild()
	  end
	end)
	ui.tabItem('History', function()
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('HistoryContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		alertHistory.drawTab()
		ui.endChild()
	  end
	end)
	ui.tabItem('Tools', function()
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('ToolsContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		drawToolsTab()
		ui.endChild()
	  end
	end)
  end)

  ui.popStyleColor(19)
end




local function drawAlert(message, isPreview, dt, showInteractionBackground)
  if message == '' then
	return
  end

  local fade = isPreview and 1 or math.min(1, (alertDuration - alertTimeLeft) / 0.5, alertTimeLeft / 0.5)
  local opacity = settings.opacity / 100 * math.max(0, fade)
  local cursor = ui.getCursor()
  local available = ui.availableSpace()
  local inset = 10
  local textWidth = math.max(40, available.x - inset * 2 - 5)

  ui.pushDWriteFont('@System')
  local fontSize = ui.fontSize()
  if measuredMessage ~= message or measuredTextSize ~= settings.textSize
	  or measuredTextWidth ~= textWidth or measuredFontSize ~= fontSize then
	measuredMessage = message
    measuredTextSize = settings.textSize
    measuredTextWidth = textWidth
    measuredFontSize = fontSize
    measuredTextHeight = math.max(fontSize, ui.measureDWriteText(message, settings.textSize, textWidth).y)
    local separator = message:find(' : ', 1, true)
    measuredAuthorPrefix = separator and message:sub(1, separator + 1) or nil
    measuredAuthorWidth = measuredAuthorPrefix and ui.measureDWriteText(measuredAuthorPrefix, settings.textSize).x or 0
  end
  local textHeight = measuredTextHeight
  local textViewportHeight = math.max(1, available.y - inset * 2)
  local maxScroll = math.max(0, textHeight - textViewportHeight)
  local scrollOffset = 0
  -- Pause at each end of the scroll cycle so long alerts remain readable.
  if maxScroll > 0 then
    if not firstScrollRequired then
      firstScrollComplete = false
      textScrollElapsed = 0
    end
    firstScrollRequired = true
    textScrollElapsed = textScrollElapsed + dt
    local speed = 28
    local pause = 0.8
    local travel = maxScroll / speed
    local cycle = 2 * (pause + travel)
    local timeInCycle = textScrollElapsed % cycle
    if textScrollElapsed >= pause + travel then
      firstScrollComplete = true
    end
    if timeInCycle > pause and timeInCycle <= pause + travel then
      scrollOffset = (timeInCycle - pause) * speed
    elseif timeInCycle > pause + travel and timeInCycle <= 2 * pause + travel then
      scrollOffset = maxScroll
    elseif timeInCycle > 2 * pause + travel then
      scrollOffset = maxScroll - (timeInCycle - 2 * pause - travel) * speed
    end
  else
    firstScrollRequired = false
    firstScrollComplete = true
    textScrollElapsed = 0
  end
  if settings.backgroundEnabled then
	ui.drawRectFilled(cursor, cursor + available, rgbm(
	  settings.backgroundColor.r,
	  settings.backgroundColor.g,
	  settings.backgroundColor.b,
	  settings.backgroundColor.mult * opacity
	), 0)
  elseif showInteractionBackground then
	ui.drawRectFilled(cursor, cursor + available, rgbm(0.35, 0.35, 0.35, 0.45), 0)
  end
  ui.drawRectFilled(cursor, vec2(cursor.x + 5, cursor.y + available.y), rgbm(
	settings.accentColor.r,
	settings.accentColor.g,
	settings.accentColor.b,
	settings.accentColor.mult * opacity
  ), 0)

  local textStart = cursor + vec2(inset + 5, inset - scrollOffset)
  local textEnd = vec2(textStart.x + textWidth, textStart.y + textHeight)
  local function drawTextPass(textAlpha, outlineAlpha, outlineScale)
	if settings.outlineThicknessPercent > 0 then
	  ui.beginOutline()
	end
	ui.dwriteDrawTextClipped(
	  message,
	  settings.textSize,
	  textStart,
	  textEnd,
	  ui.Alignment.Start,
	  ui.Alignment.Start,
	  true,
	  rgbm(
		settings.textColor.r,
		settings.textColor.g,
		settings.textColor.b,
		settings.textColor.mult * opacity * textAlpha
	  )
	)
	if settings.outlineThicknessPercent > 0 then
	  ui.endOutline(rgbm(
		settings.outlineColor.r,
		settings.outlineColor.g,
		settings.outlineColor.b,
		settings.outlineColor.mult * opacity * outlineAlpha
	  ), math.min(maxOutlineScale, outlineScale))
	end
  end

  local outlineScale = math.min(maxOutlineScale, settings.outlineThicknessPercent * settings.textSize / 100)
  if settings.softOutline and outlineScale > 0 then
	drawTextPass(0.15, 0.2, outlineScale * 2)
	drawTextPass(0.45, 0.5, outlineScale * 1.4)
  end
  drawTextPass(1, 1, outlineScale)
  local prefixColor = latestAuthorColor or settings.authorColor
  if measuredAuthorPrefix and measuredAuthorWidth <= textWidth then
    ui.dwriteDrawTextClipped(
      measuredAuthorPrefix,
      settings.textSize,
      textStart,
      textEnd,
      ui.Alignment.Start,
      ui.Alignment.Start,
      true,
      rgbm(
        prefixColor.r,
        prefixColor.g,
        prefixColor.b,
        prefixColor.mult * opacity
      )
    )
  end
  ui.popDWriteFont()
end

function windowMain(dt)
  -- Draw settings icon in top-left corner (always visible) with click detection
  local settingsIconPos = vec2(8, 8)
  local settingsIconSize = 20
  local settingsIconColor = rgbm(0.5, 0.5, 0.5, 0.7)

  -- Draw the gear icon
  ui.drawText('âš™', settingsIconPos, 1, settingsIconColor)

  -- Check for click on gear icon
  local mousePos = ui.mousePos()
  local iconRect = {
    x1 = settingsIconPos.x,
    y1 = settingsIconPos.y,
    x2 = settingsIconPos.x + settingsIconSize + 5,
    y2 = settingsIconPos.y + settingsIconSize + 5
  }
  if mousePos.x >= iconRect.x1 and mousePos.x <= iconRect.x2 and
     mousePos.y >= iconRect.y1 and mousePos.y <= iconRect.y2 then
    if ui.mouseClicked() then
      ac.setWindowOpen('config', true)
    end
  end

  if testMessagePending then
	testMode = testMessagePending.mode
	latestMessage = testMessagePending.message
	latestAuthorColor = nil
	alertTimeLeft = testMessagePending.duration
	measuredMessage = nil
	textScrollElapsed = 0
	firstScrollRequired = false
	firstScrollComplete = false
	testMessagePending = nil
  end

  invalidatePlayerNameCache()
  syncVehicleDisplayProfile()
  syncKeywordProfile()

  local windowPos = ui.windowPos()
  local mouseDown = ui.mouseDown()
  local hovered = ui.windowHovered()
  local moving = mouseDown and lastWindowPos ~= nil
	  and (windowPos.x ~= lastWindowPos.x or windowPos.y ~= lastWindowPos.y)

  local showInteractionBackground = moving or (hovered and mouseDown)
  lastWindowPos = vec2(windowPos.x, windowPos.y)

  if alertTimeLeft > 0 then
	alertTimeLeft = math.max(0, alertTimeLeft - (dt or 0))
	-- Keep the alert up until its first slow scroll has played, for real alerts as well as previews.
	if firstScrollRequired and not firstScrollComplete then
	  alertTimeLeft = math.max(alertTimeLeft, 0.5)
	end
  end

  local resizing = ui.windowResizing()
  local normalAlert = alertTimeLeft > 0 and not testMode
  if normalAlert and not settings.hideWhenNotHovered then
	-- Only reveal the title bar while the pointer is on the window, so the alert shows alone otherwise.
	if hovered or resizing or moving then
	  ac.forceFadingIn()
	end
	drawAlert(latestMessage, false, dt or 0, showInteractionBackground)
	return
  end

  if normalAlert then
	if hovered or resizing or moving then
	  ac.forceFadingIn()
	  drawAlert(latestMessage, false, dt or 0, showInteractionBackground)
	end
	return
  end

  if settings.hideWhenNotHovered and not hovered and not resizing and not moving and not testMode then
	return
  end

  if testMode or hovered or resizing or moving then
	ac.forceFadingIn()
  end

	if testMode then
	drawAlert(latestMessage, true, dt or 0, showInteractionBackground)
  elseif hovered or resizing or moving then
	local ownName = ac.getDriverName(0) or 'Driver'
	local hoverPreviewMessage = ownName:sub(1, 15) .. ' : Chat preview - move or resize this window to position your alert.'
	drawAlert(hoverPreviewMessage, true, dt or 0, showInteractionBackground)
  end
end

local function sameValue(a, b)
  if a == b then return true end
  if type(a) ~= 'table' or type(b) ~= 'table' then return false end
  for key, value in pairs(a) do
    if not sameValue(value, b[key]) then return false end
  end
  for key in pairs(b) do
    if a[key] == nil then return false end
  end
  return true
end

-- Copies live edits into the active car/server profile, so they survive a restart without pressing a save button.
local function persistLiveProfiles()
  if activeVehicleProfileKey then
    local profile = captureVehicleDisplayProfile()
    if not sameValue(profile, vehicleDisplayProfiles[activeVehicleProfileKey]) then
      vehicleDisplayProfiles[activeVehicleProfileKey] = profile
      settings.vehicleDisplayProfiles = stringify(vehicleDisplayProfiles, true)
    end
  end
  if not keywordProfileContextInitialized then return end
  if activeKeywordProfileKey then
    -- Creator and date are ignored here so that they do not trigger a rewrite on every update.
    local stored = keywordProfiles[activeKeywordProfileKey] or {}
    if not sameValue(captureKeywordProfile(), { keywords = stored.keywords, keywordRows = stored.keywordRows, keywordSoundAssignments = stored.keywordSoundAssignments, mutedKeywords = stored.mutedKeywords, keywordOptions = stored.keywordOptions }) then
      saveKeywordProfile(activeKeywordProfileKey)
    end
  elseif settings.useServerKeywordProfiles then
    local fallback = captureKeywordProfile()
    if not sameValue(fallback, stringify.tryParse(settings.keywordProfileFallback, nil, nil)) then
      settings.keywordProfileFallback = stringify(fallback, true)
    end
  end
end

local serverCheckElapsed = 0
local profilePersistElapsed = 0
local lastServerName = nil

function script.update(dt)
  dt = dt or 0
  hiddenSoundQueue.playNext()
  friendList.update(dt)
  profilePersistElapsed = profilePersistElapsed + dt
  if profilePersistElapsed >= 1 then
    profilePersistElapsed = 0
    persistLiveProfiles()
  end

  serverCheckElapsed = serverCheckElapsed + dt
  if serverCheckElapsed < 5 then return end
  serverCheckElapsed = 0

  local autoSave = settings.autoSaveServerSettings
  local currentServer = getServerName()
  if currentServer == lastServerName then
    if currentServer and autoSave then saveServerBackup(currentServer, true) end
    return
  end
  -- Live values still belong to the server being left, so save it before loading the next one.
  if lastServerName and autoSave then saveServerBackup(lastServerName, true) end
  lastServerName = currentServer
  if currentServer and autoSave then loadServerBackup(currentServer) end
end

function script.reset()
  invalidatePlayerNameCache()
  invalidateKeywordCaches()
  alertTimeLeft = 0
  measuredMessage = nil
end
