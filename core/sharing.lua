-- Shared keyword files: export, import, and server keyword lists.
local modules = require('core.modules')
local Profiles = modules.profiles
local Sharing = modules.sharing

local App = modules.paths.App
local sharedKeywordFolder = modules.paths.sharedKeywordFolder
local serverKeywordFolder = modules.paths.serverKeywordFolder
local appVersion = modules.paths.appVersion
local sharedKeywordFormat = modules.paths.sharedKeywordFormat
local sharedKeywordFormatVersion = modules.paths.sharedKeywordFormatVersion
local maximumBackupSize = modules.paths.maximumBackupSize
local settings = modules.settings.settings
local encodeAssignmentValue = modules.keywords.encodeAssignmentValue
local saveKeywords = modules.keywords.saveKeywords
local decodeKeywordRows = modules.keywords.decodeKeywordRows
local parseKeywords = modules.keywords.parseKeywords
local keywordKey = modules.keywords.keywordKey
local captureKeywordProfile = modules.profiles.captureKeywordProfile
local validateKeywordProfile = modules.profiles.validateKeywordProfile
local applyKeywordProfile = modules.profiles.applyKeywordProfile
local cleanProfileText = modules.profiles.cleanProfileText
local sanitizeProfileInfo = modules.profiles.sanitizeProfileInfo
local newProfileInfo = modules.profiles.newProfileInfo
local pendingOverwrite = modules.backup.pendingOverwrite
local normalizeBackupName = modules.backup.normalizeBackupName
local makeBackupChecksum = modules.backup.makeBackupChecksum

Sharing.sharedKeywordFiles = {}
Sharing.selectedSharedKeywordFile = ''
Sharing.pendingSharedKeywordImport = nil
Sharing.serverKeywordSources = {}
Sharing.selectedServerKeywordSource = nil

local function ensureSharedKeywordFolder()
  if io.dirExists(sharedKeywordFolder) then return true end
  if io.createDir(sharedKeywordFolder) and io.dirExists(sharedKeywordFolder) then return true end
  Profiles.profileStatus = 'Could not create the shared keyword profiles folder.'
  ac.log(App.displayName .. ': ' .. Profiles.profileStatus .. ' ' .. sharedKeywordFolder)
  return false
end

local function refreshSharedKeywordFiles()
  Sharing.sharedKeywordFiles = {}
  if not ensureSharedKeywordFolder() then return end
  for _, fileName in ipairs(io.scanDir(sharedKeywordFolder, '*.json') or {}) do
    if fileName:match('%.json$') and not fileName:find('..', 1, true)
        and not fileName:find('/', 1, true) and not fileName:find('\\', 1, true)
        and not fileName:find('%c') then
      Sharing.sharedKeywordFiles[#Sharing.sharedKeywordFiles + 1] = fileName
    end
  end
  table.sort(Sharing.sharedKeywordFiles, function(a, b) return a:lower() < b:lower() end)
  local stillAvailable = false
  for _, fileName in ipairs(Sharing.sharedKeywordFiles) do
    if fileName == Sharing.selectedSharedKeywordFile then stillAvailable = true end
  end
  if not stillAvailable then Sharing.selectedSharedKeywordFile = Sharing.sharedKeywordFiles[1] or '' end
end

local function exportSharedKeywordProfile(key, serverLabel, exportName)
  if not key then
    Profiles.profileStatus = 'Connect to a server before exporting its keyword profile.'
    return false
  end
  if not ensureSharedKeywordFolder() then return false end
  local profile = captureKeywordProfile()
  profile.info = sanitizeProfileInfo(Profiles.keywordProfiles[key] and Profiles.keywordProfiles[key].info) or newProfileInfo()
  if not validateKeywordProfile(profile) then
    Profiles.profileStatus = 'Current keyword settings failed validation; no export was written.'
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
    Profiles.profileStatus = 'Shared keyword profile could not be prepared or exceeds the size limit.'
    return false
  end
  local safeBaseName = normalizeBackupName(exportName or '')
  if safeBaseName == '' then
    Profiles.profileStatus = 'Enter a valid name for the shared file.'
    return false
  end
  safeBaseName = safeBaseName:sub(1, 80)
  local filePath = sharedKeywordFolder .. '\\' .. safeBaseName .. '.json'
  if io.fileExists(filePath) and pendingOverwrite.export ~= safeBaseName then
    pendingOverwrite.export = safeBaseName
    Profiles.profileStatus = 'A shared file named "' .. safeBaseName .. '.json" already exists. Confirm to overwrite it.'
    return false
  end
  pendingOverwrite.export = nil
  local temporaryPath = filePath .. '.tmp'
  if not io.save(temporaryPath, data, true) then
    Profiles.profileStatus = 'Could not write temporary shared keyword profile.'
    return false
  end
  if io.fileSize(temporaryPath) ~= #data or io.load(temporaryPath) ~= data then
    if io.fileExists(temporaryPath) then io.deleteFile(temporaryPath) end
    Profiles.profileStatus = 'Shared keyword profile readback verification failed.'
    return false
  end
  if not io.move(temporaryPath, filePath, true) then
    if io.fileExists(temporaryPath) then io.deleteFile(temporaryPath) end
    Profiles.profileStatus = 'Could not install the verified shared keyword profile.'
    return false
  end
  Sharing.selectedSharedKeywordFile = safeBaseName .. '.json'
  refreshSharedKeywordFiles()
  Profiles.profileStatus = 'Keyword profile exported for sharing: ' .. Sharing.selectedSharedKeywordFile
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
  Sharing.pendingSharedKeywordImport = nil
  refreshSharedKeywordFiles()
  local isListedFile = false
  for _, availableFile in ipairs(Sharing.sharedKeywordFiles) do
    if availableFile == fileName then isListedFile = true end
  end
  if not targetKey or not isListedFile or not fileName:match('%.json$')
      or fileName:find('..', 1, true) or fileName:find('/', 1, true)
      or fileName:find('\\', 1, true) then
    Profiles.profileStatus = 'Select a valid shared keyword file and connect to a server.'
    return false
  end
  local filePath = sharedKeywordFolder .. '\\' .. fileName
  local payload, readError = readSharedKeywordFile(filePath)
  if not payload then
    Profiles.profileStatus = readError
    return false
  end
  Sharing.pendingSharedKeywordImport = {
    fileName = fileName,
    serverLabel = payload.serverLabel,
    targetKey = targetKey,
    targetLabel = targetLabel,
    profile = payload.profile
  }
  Profiles.profileStatus = 'Shared file validated. Confirm to replace the keyword profile for the current server.'
  return true
end

local function applyStagedSharedKeywordImport(targetKey)
  if not targetKey or not Sharing.pendingSharedKeywordImport then return false end
  if targetKey ~= Sharing.pendingSharedKeywordImport.targetKey then
    Sharing.pendingSharedKeywordImport = nil
    Profiles.profileStatus = 'Server context changed; prepare the import again for the current server.'
    return false
  end
  if not settings.useServerKeywordProfiles then
    settings.keywordProfileFallback = stringify(captureKeywordProfile(), true)
    settings.useServerKeywordProfiles = true
  end
  local importedProfile = Sharing.pendingSharedKeywordImport.profile
  importedProfile.info = sanitizeProfileInfo(importedProfile.info) or newProfileInfo()
  Profiles.keywordProfiles[targetKey] = importedProfile
  settings.keywordProfiles = stringify(Profiles.keywordProfiles, true)
  if not applyKeywordProfile(importedProfile) then
    Profiles.profileStatus = 'Shared keyword profile could not be applied.'
    return false
  end
  Profiles.activeKeywordProfileKey = targetKey
  Profiles.keywordProfileContextInitialized = true
  Profiles.profileStatus = 'Imported ' .. Sharing.pendingSharedKeywordImport.fileName .. ' into the current server profile.'
  Sharing.pendingSharedKeywordImport = nil
  return true
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
  Sharing.serverKeywordSources = {}
  ensureServerKeywordFolder()

  local profileKeys = {}
  for profileKey, profile in pairs(Profiles.keywordProfiles) do
    if type(profileKey) == 'string' and profileKey:sub(1, 7) == 'server:' and validateKeywordProfile(profile) then
      profileKeys[#profileKeys + 1] = profileKey
    end
  end
  table.sort(profileKeys)
  for _, profileKey in ipairs(profileKeys) do
    local info = sanitizeProfileInfo(Profiles.keywordProfiles[profileKey].info)
    Sharing.serverKeywordSources[#Sharing.serverKeywordSources + 1] = { id = 'profile:' .. profileKey, kind = 'profile', label = formatProfileInfo(info, profileKey:sub(8)) }
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
    Sharing.serverKeywordSources[#Sharing.serverKeywordSources + 1] = { id = 'file:' .. fileName, kind = 'file', label = describeServerKeywordFile(fileName) }
  end

  if Sharing.selectedServerKeywordSource then
    local current = nil
    for _, source in ipairs(Sharing.serverKeywordSources) do
      if source.id == Sharing.selectedServerKeywordSource.id then current = source end
    end
    Sharing.selectedServerKeywordSource = current
  end
end

local function resolveServerKeywordSource(source)
  if not source then return nil, 'Select a server keyword list first.' end
  local profileKey = source.id:match('^profile:(.+)$')
  if profileKey then
    local profile = Profiles.keywordProfiles[profileKey]
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
    Profiles.profileStatus = resolveError
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
    Profiles.profileStatus = string.format('Keyword list replaced from %s: %d keyword(s), %d duplicate or empty line(s) removed.', source.label, kept, skipped)
  else
    Profiles.profileStatus = string.format('Keywords added from %s: %d new, %d already present or empty.', source.label, kept, skipped)
  end
  if capped then Profiles.profileStatus = Profiles.profileStatus .. ' The 256 keyword limit was reached.' end
  return true
end

Sharing.ensureSharedKeywordFolder = ensureSharedKeywordFolder
Sharing.refreshSharedKeywordFiles = refreshSharedKeywordFiles
Sharing.exportSharedKeywordProfile = exportSharedKeywordProfile
Sharing.stageSharedKeywordImport = stageSharedKeywordImport
Sharing.applyStagedSharedKeywordImport = applyStagedSharedKeywordImport
Sharing.ensureServerKeywordFolder = ensureServerKeywordFolder
Sharing.refreshServerKeywordSources = refreshServerKeywordSources
Sharing.applyServerKeywordSource = applyServerKeywordSource

return Sharing
