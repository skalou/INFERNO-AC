-- Per-car display profiles and per-server keyword profiles.
local modules = require('core.modules')
local Profiles = modules.profiles

local settings = modules.settings.settings
local defaultKeywordRows = modules.settings.defaultKeywordRows
local maxOutlineScale = modules.settings.maxOutlineScale
local Debug = modules.debug.Debug
local unpackStoredTable = modules.util.unpackStoredTable
local packColor = modules.util.packColor
local isFiniteNumber = modules.util.isFiniteNumber
local unpackColor = modules.util.unpackColor
local sameValue = modules.util.sameValue
local sliders = modules.widgets.sliders
local invalidateKeywordCaches = modules.keywords.invalidateKeywordCaches
local decodeAssignmentValue = modules.keywords.decodeAssignmentValue
local getMainAppWindow = modules.windows.getMainAppWindow
local resetMainWindowGeometry = modules.windows.resetMainWindowGeometry
local applyWindowGeometry = modules.windows.applyWindowGeometry

Profiles.activeVehicleProfileKey = nil
Profiles.activeKeywordProfileKey = nil

Profiles.keywordProfileContextInitialized = false
Profiles.profileStatus = ''

Profiles.vehicleDisplayProfiles = unpackStoredTable(settings.vehicleDisplayProfiles, 'vehicle display profiles')
Profiles.keywordProfiles = unpackStoredTable(settings.keywordProfiles, 'keyword profiles')

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
	  index = index + 1
	end
  end
  return true
end

local function validateKeywordProfile(profile)
  if type(profile) ~= 'table'
	  or type(profile.keywordRows) ~= 'string' or type(profile.keywordSoundAssignments) ~= 'string'
	  or type(profile.mutedKeywords) ~= 'string' or type(profile.keywordOptions) ~= 'string'
	  or #profile.keywordOptions > 262144
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
  for entry in profile.keywordOptions:gmatch('[^;]+') do
	local encodedKeyword = entry:match('^([^|]+)|%d+|[01]$')
	if not encodedKeyword or not isValidEncodedValue(encodedKeyword) then return false end
  end
  return true
end

local function applyKeywordProfile(profile)
  if not validateKeywordProfile(profile) then return false end
  settings.keywordRows = profile.keywordRows
  settings.keywordSoundAssignments = profile.keywordSoundAssignments
  settings.mutedKeywords = profile.mutedKeywords
  settings.keywordOptions = profile.keywordOptions
  invalidateKeywordCaches()
  return true
end

local function applyKeywordProfileFallback()
  if settings.keywordProfileFallback ~= '' then
	local fallback = stringify.tryParse(settings.keywordProfileFallback, nil, nil)
	if applyKeywordProfile(fallback) then return true end
	Debug.warn('Stored keyword profile fallback is invalid; using the default keyword list.')
  end
  settings.keywordRows = defaultKeywordRows
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
  local existing = Profiles.keywordProfiles[key]
  profile.info = sanitizeProfileInfo(existing and existing.info) or newProfileInfo()
  Profiles.keywordProfiles[key] = profile
  settings.keywordProfiles = stringify(Profiles.keywordProfiles, true)
  return true
end

local function resetKeywordProfile(key)
  if not key then return false end
  Profiles.keywordProfiles[key] = nil
  settings.keywordProfiles = stringify(Profiles.keywordProfiles, true)
  if Profiles.activeKeywordProfileKey == key then
    applyKeywordProfileFallback()
    Profiles.activeKeywordProfileKey = nil
  end
  return true
end

local function loadKeywordProfile(key)
  return applyKeywordProfile(key and Profiles.keywordProfiles[key])
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
  Profiles.vehicleDisplayProfiles[key] = captureVehicleDisplayProfile()
  settings.vehicleDisplayProfiles = stringify(Profiles.vehicleDisplayProfiles, true)
  return true
end

local function resetVehicleDisplayProfile(key)
  if key then
    Profiles.vehicleDisplayProfiles[key] = nil
    settings.vehicleDisplayProfiles = stringify(Profiles.vehicleDisplayProfiles, true)
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
    Profiles.vehicleDisplayProfiles[key] = captureVehicleDisplayProfile()
    settings.vehicleDisplayProfiles = stringify(Profiles.vehicleDisplayProfiles, true)
  end
  Profiles.activeVehicleProfileKey = settings.useVehicleDisplayProfiles and key or nil
  return geometryReset
end

local function saveDisplayForAllCars()
  if not getMainAppWindow() then return false end
  local profile = captureVehicleDisplayProfile()
  if not profile.windowPosition or not profile.windowSize then return false end
  Profiles.vehicleDisplayProfiles['all:default'] = profile
  for profileKey in pairs(Profiles.vehicleDisplayProfiles) do
    if profileKey ~= 'all:default' then
      Profiles.vehicleDisplayProfiles[profileKey] = profile
    end
  end
  local currentVehicleKey = getVehicleProfileKey()
  if currentVehicleKey then Profiles.vehicleDisplayProfiles[currentVehicleKey] = profile end
  settings.vehicleDisplayProfiles = stringify(Profiles.vehicleDisplayProfiles, true)
  return true
end

local function applyVehicleDisplayProfile(key)
  local profile = key and Profiles.vehicleDisplayProfiles[key]
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
  if nextKey == Profiles.activeVehicleProfileKey then return end
  if Profiles.activeVehicleProfileKey then saveVehicleDisplayProfile(Profiles.activeVehicleProfileKey) end
  Profiles.activeVehicleProfileKey = nextKey
  if nextKey then
	local profileKey = Profiles.vehicleDisplayProfiles[nextKey] and nextKey or 'all:default'
	if Profiles.vehicleDisplayProfiles[profileKey] then
	  if not applyVehicleDisplayProfile(profileKey) then
		Profiles.profileStatus = 'The saved display profile for this car is invalid.'
	  end
	else
	  resetVehicleDisplayProfile(nextKey)
	end
  end
end

local function syncKeywordProfile()
  local nextKey = getActiveKeywordProfileKey()
  if nextKey == Profiles.activeKeywordProfileKey and Profiles.keywordProfileContextInitialized then return end
  local previousKey = Profiles.activeKeywordProfileKey
  if previousKey then saveKeywordProfile(previousKey) end
  Profiles.activeKeywordProfileKey = nextKey
  Profiles.keywordProfileContextInitialized = true
  if nextKey then
	if Profiles.keywordProfiles[nextKey] then
	  if not loadKeywordProfile(nextKey) then
		Profiles.profileStatus = 'The saved keyword profile for this context is invalid.'
	  end
	elseif not applyKeywordProfileFallback() then
	  Profiles.profileStatus = 'The keyword profile fallback was invalid; the default keyword list was loaded.'
	end
  elseif settings.useServerKeywordProfiles then
	if not applyKeywordProfileFallback() then
	  Profiles.profileStatus = 'The keyword profile fallback was invalid; the default keyword list was loaded.'
	end
  elseif previousKey and not applyKeywordProfileFallback() then
	Profiles.profileStatus = 'The keyword profile fallback was invalid; the default keyword list was loaded.'
  end
end

-- Copies live edits into the active car/server profile, so they survive a restart without pressing a save button.
local function persistLiveProfiles()
  if Profiles.activeVehicleProfileKey then
    local profile = captureVehicleDisplayProfile()
    if not sameValue(profile, Profiles.vehicleDisplayProfiles[Profiles.activeVehicleProfileKey]) then
      Profiles.vehicleDisplayProfiles[Profiles.activeVehicleProfileKey] = profile
      settings.vehicleDisplayProfiles = stringify(Profiles.vehicleDisplayProfiles, true)
    end
  end
  if not Profiles.keywordProfileContextInitialized then return end
  if Profiles.activeKeywordProfileKey then
    -- Creator and date are ignored here so that they do not trigger a rewrite on every update.
    local stored = Profiles.keywordProfiles[Profiles.activeKeywordProfileKey] or {}
    if not sameValue(captureKeywordProfile(), { keywordRows = stored.keywordRows, keywordSoundAssignments = stored.keywordSoundAssignments, mutedKeywords = stored.mutedKeywords, keywordOptions = stored.keywordOptions }) then
      saveKeywordProfile(Profiles.activeKeywordProfileKey)
    end
  elseif settings.useServerKeywordProfiles then
    local fallback = captureKeywordProfile()
    if not sameValue(fallback, stringify.tryParse(settings.keywordProfileFallback, nil, nil)) then
      settings.keywordProfileFallback = stringify(fallback, true)
    end
  end
end

Profiles.getVehicleProfileKey = getVehicleProfileKey
Profiles.getKeywordProfileContext = getKeywordProfileContext
Profiles.captureKeywordProfile = captureKeywordProfile
Profiles.validateKeywordProfile = validateKeywordProfile
Profiles.applyKeywordProfile = applyKeywordProfile
Profiles.cleanProfileText = cleanProfileText
Profiles.sanitizeProfileInfo = sanitizeProfileInfo
Profiles.newProfileInfo = newProfileInfo
Profiles.saveKeywordProfile = saveKeywordProfile
Profiles.resetKeywordProfile = resetKeywordProfile
Profiles.saveVehicleDisplayProfile = saveVehicleDisplayProfile
Profiles.resetVehicleDisplayProfile = resetVehicleDisplayProfile
Profiles.saveDisplayForAllCars = saveDisplayForAllCars
Profiles.syncVehicleDisplayProfile = syncVehicleDisplayProfile
Profiles.syncKeywordProfile = syncKeywordProfile
Profiles.persistLiveProfiles = persistLiveProfiles

return Profiles
