-- Keyword list storage, per-keyword sound/mute/volume options, and chat matching.
local modules = require('core.modules')
local Keywords = modules.keywords
local Profiles = modules.profiles

local settings = modules.settings.settings
local defaultKeywordRows = modules.settings.defaultKeywordRows
local Debug = modules.debug.Debug
local sliders = modules.widgets.sliders

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

local invalidateKeywordCaches

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
  if cachedKeywords and cachedKeywordProfileKey == Profiles.activeKeywordProfileKey then
    return cachedKeywords
  end

  if type(settings.keywordRows) ~= 'string' or settings.keywordRows:sub(1, 3) ~= 'v1:' then
    settings.keywordRows = defaultKeywordRows
  end

  local keywords = decodeKeywordRows(settings.keywordRows)
  if specialAlertKeys.ensure(keywords) then saveKeywords(keywords) end
  cachedKeywords = keywords
  cachedKeywordProfileKey = Profiles.activeKeywordProfileKey
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
  if cachedSoundAssignments and cachedSoundAssignmentProfileKey == Profiles.activeKeywordProfileKey then
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
  cachedSoundAssignmentProfileKey = Profiles.activeKeywordProfileKey
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
  if cachedMutedKeywords and cachedMutedKeywordProfileKey == Profiles.activeKeywordProfileKey then
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
  cachedMutedKeywordProfileKey = Profiles.activeKeywordProfileKey
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
  if keywordOptionStore.cache and keywordOptionStore.cacheProfileKey == Profiles.activeKeywordProfileKey then
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
  keywordOptionStore.cacheProfileKey = Profiles.activeKeywordProfileKey
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

local function keywordKey(keyword)
  return lowerText(keyword:match('^%s*(.-)%s*$'))
end

Keywords.specialAlertKeys = specialAlertKeys
Keywords.invalidateKeywordCaches = invalidateKeywordCaches
Keywords.lowerText = lowerText
Keywords.invalidatePlayerNameCache = invalidatePlayerNameCache
Keywords.isPlayerMentioned = isPlayerMentioned
Keywords.encodeAssignmentValue = encodeAssignmentValue
Keywords.decodeAssignmentValue = decodeAssignmentValue
Keywords.saveKeywords = saveKeywords
Keywords.decodeKeywordRows = decodeKeywordRows
Keywords.parseKeywords = parseKeywords
Keywords.findMatchedAlert = findMatchedAlert
Keywords.loadKeywordSoundAssignments = loadKeywordSoundAssignments
Keywords.saveKeywordSoundAssignments = saveKeywordSoundAssignments
Keywords.loadMutedKeywords = loadMutedKeywords
Keywords.saveMutedKeywords = saveMutedKeywords
Keywords.keywordOptionStore = keywordOptionStore
Keywords.keywordKey = keywordKey

return Keywords
