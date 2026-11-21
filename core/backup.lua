-- Settings snapshots, backup files, per-server auto-save, and resets.
local modules = require('core.modules')
local tr = modules.i18n.tr
local Sounds = modules.sounds
local Profiles = modules.profiles
local Backup = modules.backup

local defaultAlertSoundFile = modules.paths.defaultAlertSoundFile
local App = modules.paths.App
local backupFolder = modules.paths.backupFolder
local appVersion = modules.paths.appVersion
local backupFormat = modules.paths.backupFormat
local backupFormatVersion = modules.paths.backupFormatVersion
local maximumBackupSize = modules.paths.maximumBackupSize
local settings = modules.settings.settings
local defaultKeywordRows = modules.settings.defaultKeywordRows
local maxOutlineScale = modules.settings.maxOutlineScale
local unpackStoredTable = modules.util.unpackStoredTable
local packColor = modules.util.packColor
local isFiniteNumber = modules.util.isFiniteNumber
local unpackColor = modules.util.unpackColor
local stopCurrentSound = modules.sounds.stopCurrentSound
local sliders = modules.widgets.sliders
local invalidateKeywordCaches = modules.keywords.invalidateKeywordCaches
local getMainAppWindow = modules.windows.getMainAppWindow
local resetMainWindowGeometry = modules.windows.resetMainWindowGeometry
local resetWindowGeometry = modules.windows.resetWindowGeometry
local applyBackupWindowGeometry = modules.windows.applyBackupWindowGeometry

Backup.backupFolderStatus = ''
Backup.availableBackups = {}
Backup.selectedBackupToLoad = ''
local applyDefaultSettings
local pendingOverwrite = {}

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
  Profiles.profileStatus = tr('Audio settings reset to defaults.')
end

local function resetAlertAppearanceSettings()
  settings.textSize = sliders.defaults.textSize
  settings.duration = sliders.defaults.duration
  settings.opacity = sliders.defaults.opacity
  settings.hideWhenNotHovered = false
  settings.backgroundEnabled = false
  settings.outlineThicknessPercent = 8
  settings.softOutline = true
  settings.textColor = rgbm(1, 102 / 255, 134 / 255, 242 / 255)
  settings.authorColor = rgbm(1, 190 / 255, 80 / 255, 1)
  settings.playerColor = rgbm(0.3, 1, 0.3, 1)
  settings.friendColor = rgbm(0, 0.8, 1, 1)
  settings.outlineColor = rgbm(20 / 255, 20 / 255, 20 / 255, 1)
  settings.backgroundColor = rgbm(26 / 255, 26 / 255, 26 / 255, 1)
  settings.accentColor = rgbm(97 / 255, 138 / 255, 81 / 255, 198 / 255)
  settings.themeColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1)
  settings.themeBgColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1)
  Profiles.profileStatus = tr('Alert appearance reset to defaults.')
end

local function resetKeywordSettings()
  if Profiles.activeKeywordProfileKey then
    Profiles.keywordProfiles[Profiles.activeKeywordProfileKey] = nil
    settings.keywordProfiles = stringify(Profiles.keywordProfiles, true)
  end
  settings.keywordRows = defaultKeywordRows
  settings.keywordSoundAssignments = ''
  settings.mutedKeywords = ''
  settings.keywordOptions = ''
  settings.keywordProfileFallback = ''
  Profiles.activeKeywordProfileKey = nil
  Profiles.keywordProfileContextInitialized = false
  invalidateKeywordCaches()
  Profiles.profileStatus = tr('Keyword settings reset to defaults.')
end

local function captureAllSettings()
  local profile = {
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

-- Validates a settings snapshot (validateOnly) or applies it. Full backups carry every field; server backups
-- leave out the keyword and profile fields listed in serverBackupExcludedKeys, so those stay optional.
local function applyAllSettings(profile, validateOnly)
  if type(profile) ~= 'table' then return false end
  local colors = {
	themeColor = unpackColor(profile.themeColor),
	themeBgColor = unpackColor(profile.themeBgColor),
	textColor = unpackColor(profile.textColor),
	authorColor = unpackColor(profile.authorColor),
	playerColor = unpackColor(profile.playerColor),
	friendColor = unpackColor(profile.friendColor),
	outlineColor = unpackColor(profile.outlineColor),
	backgroundColor = unpackColor(profile.backgroundColor),
	accentColor = unpackColor(profile.accentColor)
  }
  for key, color in pairs(colors) do
	if not color then return false end
  end
  for _, key in ipairs({ 'mentionSound', 'friendSound' }) do
	if type(profile[key]) ~= 'string' then return false end
  end
  for _, key in ipairs({ 'mentionMe', 'mentionSoundMuted', 'friendSoundMuted', 'showAllChatMessages', 'soundEnabled', 'hideWhenNotHovered', 'backgroundEnabled', 'softOutline', 'useVehicleDisplayProfiles', 'settingsWindowPositionSaved' }) do
	if type(profile[key]) ~= 'boolean' then return false end
  end
  for _, key in ipairs({ 'textSize', 'duration', 'opacity', 'outlineThicknessPercent', 'settingsWindowHeightPercent', 'settingsWindowOffsetX', 'settingsWindowOffsetY', 'settingsWindowAbsoluteX', 'settingsWindowAbsoluteY' }) do
	if not isFiniteNumber(profile[key]) then return false end
  end
  if profile.textSize < 8 or profile.textSize > 96
	  or profile.duration < 0.1 or profile.duration > 10
	  or profile.opacity < 0 or profile.opacity > 100
	  or profile.outlineThicknessPercent < 0
	  or profile.outlineThicknessPercent > maxOutlineScale * 100 / 8
	  or profile.settingsWindowHeightPercent < 25 or profile.settingsWindowHeightPercent > 100 then
	return false
  end
  for _, key in ipairs({ 'vehicleDisplayProfiles', 'keywordProfiles', 'keywordProfileFallback', 'keywordRows', 'keywordSoundAssignments', 'mutedKeywords', 'keywordOptions' }) do
	if profile[key] ~= nil and type(profile[key]) ~= 'string' then return false end
  end
  if profile.useServerKeywordProfiles ~= nil and type(profile.useServerKeywordProfiles) ~= 'boolean' then return false end
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
	Profiles.vehicleDisplayProfiles = unpackStoredTable(profile.vehicleDisplayProfiles, 'vehicle display profiles')
  end
  if profile.keywordProfiles then
	Profiles.keywordProfiles = unpackStoredTable(profile.keywordProfiles, 'keyword profiles')
	settings.keywordProfiles = stringify(Profiles.keywordProfiles, true)
  end
  return true
end

local defaultSettingsProfile = {
  keywordRows = defaultKeywordRows,
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
  softOutline = true,
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
	Backup.backupFolderStatus = tr('Settings backup folder created.')
	return true
  end
  Backup.backupFolderStatus = tr('Could not create the settings backup folder.')
  ac.log(App.displayName .. ': ' .. Backup.backupFolderStatus .. ' ' .. folder)
  return false
end

local function refreshBackupList()
  Backup.availableBackups = { 'Default' }
	if not ensureBackupFolder() then return end
  local backupCount = 0
  for _, fileName in ipairs(io.scanDir(backupFolder, '*.json') or {}) do
	local backupName = fileName:gsub('%.json$', '')
	if not fileName:match('^%.') and #backupName <= 64
		and normalizeBackupName(backupName) == backupName and backupName:lower() ~= 'default' then
	  Backup.availableBackups[#Backup.availableBackups + 1] = backupName
	  backupCount = backupCount + 1
	end
  end
  table.sort(Backup.availableBackups, function(a, b)
	if a == b then return false end
	if a == 'Default' then return true end
	if b == 'Default' then return false end
	return a:lower() < b:lower()
  end)
  if backupCount == 0 then
	Backup.backupFolderStatus = tr('No settings backups found. Save current settings to create one.')
  else
	Backup.backupFolderStatus = tr('%d settings backup(s) found.', backupCount)
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

-- Envelope written around a settings snapshot. Only this exact format id and version are read back.
local function encodeBackup(snapshot)
  local payload = JSON.stringify(snapshot)
  local checksum = type(payload) == 'string' and makeBackupChecksum(appVersion, backupFormatVersion, payload) or nil
  local data = checksum and JSON.stringify({
	format = backupFormat,
	formatVersion = backupFormatVersion,
	appVersion = appVersion,
	payload = payload,
	checksum = checksum
  }) or nil
  if type(data) ~= 'string' or #data > maximumBackupSize then return nil end
  return data
end

-- Returns the settings snapshot and the app version that wrote it, or nil and an error message.
local function decodeBackupData(data)
  local parsedOk, envelope = pcall(JSON.parse, data)
  if not parsedOk or type(envelope) ~= 'table' or envelope.format ~= backupFormat
	  or envelope.formatVersion ~= backupFormatVersion then
	return nil, tr('Not an INFERNO %s settings backup (IsuChat Alert and older backups are not supported).', appVersion)
  end
  if type(envelope.appVersion) ~= 'string' or type(envelope.payload) ~= 'string' or #envelope.payload == 0
	  or #envelope.payload > maximumBackupSize or type(envelope.checksum) ~= 'string' then
	return nil, tr('Backup integrity metadata is invalid.')
  end
  local expectedChecksum = makeBackupChecksum(envelope.appVersion, envelope.formatVersion, envelope.payload)
  if not expectedChecksum or expectedChecksum ~= envelope.checksum then
	return nil, tr('Backup integrity check failed; the file may be damaged.')
  end
  local payloadOk, profile = pcall(JSON.parse, envelope.payload)
  if not payloadOk or type(profile) ~= 'table' then return nil, tr('Backup payload is damaged or invalid.') end
  return profile, envelope.appVersion
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

  if configData.mentionSound and not Sounds.alertSoundFileSet[configData.mentionSound] then
    table.insert(missingFiles, configData.mentionSound)
  end
  if configData.friendSound and not Sounds.alertSoundFileSet[configData.friendSound] then
    table.insert(missingFiles, configData.friendSound)
  end

  local assignments = configData.keywordSoundAssignments
  if type(assignments) == 'string' then
    local parsed = stringify.tryParse(assignments, nil, nil)
    if type(parsed) == 'table' then
      for keyword, soundFile in pairs(parsed) do
        if soundFile and not Sounds.alertSoundFileSet[soundFile] then
          table.insert(missingFiles, soundFile)
        end
      end
    end
  end

  return missingFiles
end

-- Keyword and per-context profile data stay in their own profile maps, so a server file never carries them.
local serverBackupExcludedKeys = {
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
    Profiles.profileStatus = tr('No active server session. Server backups are only available during races.')
    return false
  end

  if not ensureBackupFolder() or not ensureBackupFolder(backupFolder .. '\\Servers') then
    Profiles.profileStatus = Backup.backupFolderStatus
    return false
  end

  local snapshot = captureAllSettings()
  for key in pairs(serverBackupExcludedKeys) do
    snapshot[key] = nil
  end
  if not applyAllSettings(snapshot, true) then
    Profiles.profileStatus = tr('Current settings failed validation; no file was written.')
    return false
  end

  local data = encodeBackup(snapshot)
  if not data then
    Profiles.profileStatus = tr('Server backup could not be prepared or exceeds the size limit.')
    return false
  end

  if onlyIfChanged and lastServerBackupData[serverName] == data then return true end

  local serverAddress = ac.getServerIP()
  local serverKey = (serverAddress and serverAddress ~= '') and (serverAddress .. '_' .. tostring(ac.getServerPortTCP())) or serverName
  local filePath = backupFilePath(serverKey, true)
  if not io.save(filePath, data, true) then
    Profiles.profileStatus = tr('Could not write server backup for "%s".', serverName)
    return false
  end

  lastServerBackupData[serverName] = data
  Profiles.profileStatus = tr('Settings auto-saved for server: %s', serverName)
  return true
end

local function loadServerBackup(serverName)
  serverName = serverName or getServerName()
  if not serverName then
    Profiles.profileStatus = tr('No active server session. Cannot load server-specific settings.')
    return false
  end

  local serverAddress = ac.getServerIP()
  local serverKey = (serverAddress and serverAddress ~= '') and (serverAddress .. '_' .. tostring(ac.getServerPortTCP())) or serverName
  local filePath = backupFilePath(serverKey, true)
  if not filePath or not io.fileExists(filePath) then
    Profiles.profileStatus = tr('No saved settings found for this server.')
    return false
  end

  local data = io.load(filePath)
  if type(data) ~= 'string' or #data == 0 then
    Profiles.profileStatus = tr('Could not load server backup file.')
    return false
  end

  local profile, decodeError = decodeBackupData(data)
  if not profile then
    Profiles.profileStatus = tr('Server backup decoding failed: %s', decodeError or tr('unknown error'))
    return false
  end

  for key in pairs(serverBackupExcludedKeys) do
    profile[key] = nil
  end

  local missingFiles = getMissingMusicFiles(profile)
  if #missingFiles > 0 then
    Profiles.profileStatus = tr('Warning: Missing sound files in server config: %s', table.concat(missingFiles, ', '))
  else
    Profiles.profileStatus = tr('Server settings loaded successfully.')
  end

  if applyAllSettings(profile, false) then
    return true
  else
    Profiles.profileStatus = tr('Server settings failed to apply.')
    return false
  end
end

local function saveSettingsBackup()
  local safeName = normalizeBackupName(settings.backupName)
  if safeName:lower() == 'default' then
    Profiles.profileStatus = tr('The built-in Default profile cannot be overwritten.')
    return false
  end
  if safeName == '' then
	Profiles.profileStatus = tr('Enter a valid backup name.')
	return false
  end
	if #safeName > 64 then
	Profiles.profileStatus = tr('Backup name is empty or longer than 64 safe characters.')
	return false
	end
	if not ensureBackupFolder() then
	Profiles.profileStatus = Backup.backupFolderStatus
	return false
  end
  local snapshot = captureAllSettings()
	if not applyAllSettings(snapshot, true) then
	  Profiles.profileStatus = tr('Current settings failed validation; no file was written.')
    return false
  end
	local data = encodeBackup(snapshot)
	if not data then
	Profiles.profileStatus = tr('Backup could not be prepared or exceeds the size limit.')
	return false
  end
	local filePath = backupFilePath(safeName)
	if io.fileExists(filePath) and pendingOverwrite.backup ~= safeName then
	  pendingOverwrite.backup = safeName
	  Profiles.profileStatus = tr('A backup named "%s" already exists. Confirm to overwrite it.', safeName)
	  return false
	end
	pendingOverwrite.backup = nil
	local temporaryPath = filePath .. '.tmp'
	if not io.save(temporaryPath, data, true) then
	Profiles.profileStatus = tr('Could not write temporary backup file for "%s".', safeName)
	return false
	end
	if io.fileSize(temporaryPath) ~= #data or io.load(temporaryPath) ~= data then
	if io.fileExists(temporaryPath) then io.deleteFile(temporaryPath) end
	Profiles.profileStatus = tr('Backup readback verification failed; previous backup preserved.')
	return false
	end
	if not io.move(temporaryPath, filePath, true) then
	if io.fileExists(temporaryPath) then io.deleteFile(temporaryPath) end
	Profiles.profileStatus = tr('Could not install the verified backup; previous backup preserved.')
	return false
	end
  settings.backupName = safeName
  Backup.selectedBackupToLoad = safeName
  refreshBackupList()
	Profiles.profileStatus = tr('Backup saved and verified: %s (app %s).', safeName, appVersion)
	if not snapshot.mainWindowPosition or not snapshot.mainWindowSize then
	Profiles.profileStatus = Profiles.profileStatus .. tr(' Window geometry was unavailable and was not included.')
	end
  return true
end

local function loadSettingsBackup()
  local safeName = normalizeBackupName(Backup.selectedBackupToLoad)
  if safeName == '' then
    Profiles.profileStatus = tr('Select a backup in the list first.')
    return false
  end
  if safeName:lower() == 'default' then
    if applyDefaultSettings() and resetMainWindowGeometry() then
      Profiles.profileStatus = tr('Built-in Default profile applied. User backup files were kept.')
    else
      Profiles.profileStatus = tr('Default profile applied, but the chat window could not be repositioned.')
    end
    return true
  end
	local filePath = backupFilePath(safeName)
  local data = filePath and io.fileExists(filePath) and io.load(filePath) or nil
	if type(data) ~= 'string' or #data == 0 or #data > maximumBackupSize then
	Profiles.profileStatus = tr('No valid backup is available for this name.')
	return false
  end
	local saved, decodeResult = decodeBackupData(data)
	if not saved then
	Profiles.profileStatus = decodeResult
	return false
	end
	if not applyAllSettings(saved, true) then
	Profiles.profileStatus = tr('Backup failed settings validation; no settings were changed.')
	return false
	end
	if not applyAllSettings(saved) then
	Profiles.profileStatus = tr('Backup could not be applied.')
	return false
	end
  applyBackupWindowGeometry(saved)
  Profiles.activeVehicleProfileKey = nil
  Profiles.activeKeywordProfileKey = nil
  Profiles.keywordProfileContextInitialized = false
	Profiles.profileStatus = tr('Backup loaded and validated: %s (app %s).', safeName, decodeResult)
  return true
end

applyDefaultSettings = function()
  if not applyAllSettings(defaultSettingsProfile) then return false end
  Profiles.activeVehicleProfileKey = nil
  Profiles.activeKeywordProfileKey = nil
  settings.settingsWindowPositionSaved = false
  settings.settingsWindowOffsetX = 0
  settings.settingsWindowOffsetY = 0
  settings.settingsWindowAbsoluteX = 0
  settings.settingsWindowAbsoluteY = 0
  settings.backupName = 'Default'
  Backup.selectedBackupToLoad = 'Default'
  return true
end

local function resetSettings()
  local applied = applyDefaultSettings()
  settings.language = 'en'
  settings.tipsUnderstood = false
  settings.debugEnabled = sliders.defaults.debugEnabled
  settings.debugTraceEnabled = sliders.defaults.debugTraceEnabled
  settings.debugModeEnabled = sliders.defaults.debugModeEnabled
  modules.debug.Debug.simulator.friend = sliders.defaults.simulatorFriend
  modules.widgets.resetDebugColors()
  if applied and resetWindowGeometry() then
    Profiles.profileStatus = tr('Built-in Default settings applied. User backup files were kept.')
  else
    Profiles.profileStatus = tr('Default settings applied, but a window could not be repositioned.')
  end
end

Backup.pendingOverwrite = pendingOverwrite
Backup.resetAudioSettings = resetAudioSettings
Backup.resetAlertAppearanceSettings = resetAlertAppearanceSettings
Backup.resetKeywordSettings = resetKeywordSettings
Backup.normalizeBackupName = normalizeBackupName
Backup.ensureBackupFolder = ensureBackupFolder
Backup.refreshBackupList = refreshBackupList
Backup.makeBackupChecksum = makeBackupChecksum
Backup.getServerName = getServerName
Backup.saveServerBackup = saveServerBackup
Backup.loadServerBackup = loadServerBackup
Backup.saveSettingsBackup = saveSettingsBackup
Backup.loadSettingsBackup = loadSettingsBackup
Backup.resetSettings = resetSettings

return Backup
