-- Smoke test: runs the app against deterministic CSP stubs and prints a trace, then the results of the checks.
-- Usage (from the repository root): luajit tools\harness.lua INFERNO-ChatAlerts.lua
-- Exit code 1 if a scenario step raised an error or a check failed.
local mainFile = arg[1]
local root = mainFile:match('^(.*)[\\/][^\\/]+$') or '.'
local TRACE = {}
local function trace(s) TRACE[#TRACE + 1] = s end
PRESS = false

-- vec2 / rgbm
local V_mt = {}
function vec2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, V_mt) end
local function tov(a) if type(a) == 'number' then return { x = a, y = a } end return a end
V_mt.__add = function(a, b) a, b = tov(a), tov(b) return vec2(a.x + b.x, a.y + b.y) end
V_mt.__sub = function(a, b) a, b = tov(a), tov(b) return vec2(a.x - b.x, a.y - b.y) end
V_mt.__mul = function(a, b) a, b = tov(a), tov(b) return vec2(a.x * b.x, a.y * b.y) end
V_mt.__div = function(a, b) a, b = tov(a), tov(b) return vec2(a.x / b.x, a.y / b.y) end
V_mt.__unm = function(a) return vec2(-a.x, -a.y) end
V_mt.__tostring = function(a) return string.format('vec2(%g,%g)', a.x, a.y) end
local RGBM_mt = {}
RGBM_mt.__index = RGBM_mt
function RGBM_mt.clone(c) return rgbm(c.r, c.g, c.b, c.mult) end
function rgbm(r, g, b, m) return setmetatable({ r = r, g = g, b = b, mult = m, _rgbm = true }, RGBM_mt) end

-- stringify / JSON: deterministic serializer + load-based parser
local function ser(v)
  local t = type(v)
  if t == 'string' then return string.format('%q', v)
  elseif t == 'number' or t == 'boolean' or t == 'nil' then return tostring(v)
  elseif t == 'table' then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = '[' .. ser(k) .. ']=' .. ser(v[k]) end
    return '{' .. table.concat(parts, ',') .. '}'
  end
  return '"<' .. t .. '>"'
end
local function deser(s)
  if type(s) ~= 'string' then return nil end
  local f = loadstring('return ' .. s)
  if not f then return nil end
  local ok, r = pcall(f)
  return ok and r or nil
end
stringify = setmetatable({ tryParse = function(s) return deser(s) end, parse = deser }, { __call = function(_, v) return ser(v) end })
JSON = { stringify = ser, parse = function(s) local r = deser(s); if r == nil then error('bad json') end return r end }
math.clamp = function(x, a, b) return math.max(a, math.min(b, x)) end
local realDate = os.date
os.date = function(f, t) return realDate(f, t or 1700000000) end
os.time = function() return 1700000000 end
os.openInExplorer = function(p) trace('explorer ' .. p) end

-- In-memory file system
local FS, DIRS = {}, {}
local soundRoot = 'C:\\stub\\ACApps\\lua\\INFERNO-ChatAlerts\\sounds'
FS[soundRoot .. '\\00defaultALERT.wav'] = 'wav'
FS[soundRoot .. '\\beep.mp3'] = 'mp3'
FS[soundRoot .. '\\Sub\\sub.wav'] = 'wav'
DIRS[soundRoot] = true; DIRS[soundRoot .. '\\Sub'] = true
-- Data of the old IsuChat Alert app: INFERNO must never read or copy it.
local oldState = 'C:\\stub\\ExtCfgState\\lua\\app\\isuChatAlertLua'
FS[oldState .. '.ini'] = 'old settings'
FS[oldState .. '\\Saves\\Old.json'] = 'old backup'
DIRS[oldState] = true; DIRS[oldState .. '\\Saves'] = true
io.fileExists = function(p) return FS[p] ~= nil end
io.dirExists = function(p) return DIRS[p] == true end
io.createDir = function(p) DIRS[p] = true trace('mkdir ' .. p) return true end
io.save = function(p, d) FS[p] = d trace('save ' .. p .. ' #' .. #d) return true end
io.load = function(p) return FS[p] end
io.fileSize = function(p) return FS[p] and #FS[p] or -1 end
io.move = function(a, b) FS[b] = FS[a]; FS[a] = nil trace('move ' .. a .. ' -> ' .. b) return true end
io.copyFile = function(a, b) FS[b] = FS[a] trace('copy ' .. a .. ' -> ' .. b) return true end
io.deleteFile = function(p) FS[p] = nil trace('delete ' .. p) return true end
io.scanDir = function(folder, mask, cb)
  local names, seen = {}, {}
  local pattern = '^' .. (mask or '*'):gsub('%.', '%%.'):gsub('%*', '.*') .. '$'
  for p in pairs(FS) do
    local rest = p:sub(#folder + 2)
    if p:sub(1, #folder + 1) == folder .. '\\' and rest ~= '' then
      local first = rest:match('^[^\\]+')
      if not seen[first] and first:match(pattern) then seen[first] = true; names[#names + 1] = first end
    end
  end
  table.sort(names)
  if cb then
    for _, n in ipairs(names) do cb(n, { isDirectory = DIRS[folder .. '\\' .. n] == true }) end
  end
  return names
end
local realOpen = io.open
io.open = function(p, m) if p:find('C:\\stub', 1, true) then return nil end return realOpen(p, m) end

-- ac
local chatHandler
local function enum(prefix)
  local n = 0
  return setmetatable({}, { __index = function(t, k) n = n + 1; rawset(t, k, n); return n end })
end
local function window(name, size)
  local pos = vec2(50, 63)
  size = size or vec2(680, 260)
  return {
    valid = function() return true end, visible = function() return true end,
    position = function() return pos end, size = function() return size end,
    move = function(_, v) pos = v trace('move window ' .. name .. ' ' .. tostring(v)) end,
    resize = function(_, v) size = v trace('resize window ' .. name .. ' ' .. tostring(v)) end,
  }
end
local mainWindow = window('main')
local configWindow = window('config', vec2(800, 700))
STORE = nil
ac = {
  FolderID = setmetatable({}, { __index = function(_, k) return k end }),
  getFolder = function(id) return 'C:\\stub\\' .. tostring(id) end,
  storage = function(defaults, prefix)
    if type(defaults) == 'string' then
      KEY_STORE = KEY_STORE or {}
      if KEY_STORE[defaults] == nil then KEY_STORE[defaults] = prefix end
      return { get = function() return KEY_STORE[defaults] end, set = function(_, v) KEY_STORE[defaults] = v end }
    end
    STORE = {}
    STORAGE_PREFIX = prefix
    for k, v in pairs(defaults) do STORE[k] = v end
    trace('storage prefix ' .. prefix)
    return STORE
  end,
  log = function(...) trace('log ' .. table.concat({ ... }, ' ')) end,
  getDriverName = function(i) return i == 0 and 'Driver' or ('Player' .. tostring(i)) end,
  getServerName = function() return 'Test Server' end,
  getServerIP = function() return '1.2.3.4' end,
  getServerPortTCP = function() return 9600 end,
  getTrackID = function() return 'track' end,
  getCarID = function() return 'car' end,
  getCarName = function() return 'Car' end,
  isAudioReady = function() return true end,
  AudioEvent = { fromFile = function(o)
    local playing = false
    trace('sound load ' .. o.filename)
    return { isValid = function() return true end, start = function(self) playing = true trace('sound start ' .. o.filename .. ' vol ' .. tostring(self.volume)) end,
      stop = function() playing = false end, dispose = function() end, isPlaying = function() return playing end, getDuration = function() return 1.5 end }
  end },
  getSim = function() return { windowWidth = 1920, windowHeight = 1080, carsCount = 4, isOnlineRace = true } end,
  getUI = function() return { uiScale = 1, windowSize = vec2(1920, 1080) } end,
  getCar = function(i) return { index = i, isConnected = true } end,
  isTaggedAsFriend = function(name) return name == 'Player2' end,
  getAppWindows = function() return {
    { name = 'INFERNO-Chat Alerts_main', title = 'INFERNO-Chat Alerts' },
    { name = 'INFERNO-Chat Alerts_config', title = 'INFERNO-Chat Alerts Config' },
  } end,
  accessAppWindow = function(n) return n:find('_config$') and configWindow or mainWindow end,
  onChatMessage = function(fn) chatHandler = fn end,
  onClientConnected = function(fn) trace('onClientConnected registered') end,
  setWindowOpen = function(id, v) trace('setWindowOpen ' .. id) end,
  forceFadingIn = function() end,
  setClipboardText = function(s) trace('clipboard #' .. #s) end,
  checksumSHA256 = function(s) return 'sha' .. #s end,
  encodeBase64 = function(s) return 'b64' .. s end,
  getPatchVersionCode = function() return 3000 end,
  getPatchVersion = function() return '0.2.test' end,
}
setmetatable(ac, { __index = function(_, k) error('missing ac stub: ' .. k) end })
script = {}

-- ui
local UICOUNT = {}
local function counted(name, fn) return function(...) UICOUNT[name] = (UICOUNT[name] or 0) + 1 return fn(...) end end
local noop = function() end
local impl = {
  availableSpace = function() return vec2(400, 300) end, availableSpaceX = function() return 400 end,
  windowSize = function() return vec2(500, 400) end, windowPos = function() return vec2(10, 10) end,
  getCursor = function() return vec2(0, 0) end, getCursorX = function() return 0 end, getCursorY = function() return 0 end, cursorStartPos = function() return vec2(0, 30) end,
  windowTitleWidth = function() return 80 end,
  mousePos = function() return vec2(100, 100) end, mouseLocalPos = function() return vec2(0, 0) end,
  getScrollMaxX = function() return 0 end, getScrollY = function() return 0 end, getScrollMaxY = function() return 0 end,
  windowHeight = function() return 600 end, deltaTime = function() return 0.016 end,
  time = function() return 1.5 end, fontSize = function() return 14 end,
  mouseWheel = function() return 0 end, windowResizing = function() return false end, frameCount = function() return 1 end,
  measureText = function(s) return vec2(#s * 7, 14) end,
  measureDWriteText = function(s, size, width) local w = #s * size * 0.5; local lines = width and math.ceil(w / width) or 1; return vec2(width and math.min(w, width) or w, size * lines) end,
  button = function() return PRESS end, iconButton = function() return PRESS end, checkbox = function() return PRESS end,
  selectable = function() return PRESS end, mouseClicked = function() return PRESS end, itemClicked = function() return PRESS end,
  beginCombo = function() return PRESS end, beginChild = function() return true end, itemHovered = function() return PRESS end,
  itemActive = function() return false end, itemDeactivatedAfterEdit = function() return false end, keyboardButtonPressed = function() return false end, getItemRectSize = function() return vec2(120, 20) end, mouseDown = function() return false end, windowHovered = function() return PRESS end,
  isWindowAppearing = function() return true end, colorPicker = function() return false end, colorButton = function() return false end,
  inputText = function(_, text) return text end, slider = function(_, v) return v end,
  tabBar = function(id, a, b) local fn = b or a; TAB_BAR = id; fn() end,
  tabItem = function(label, flags, fn) if TAB_LOG then TAB_LOG[#TAB_LOG + 1] = { id = label:match('###(.*)$') or label, label = label:match('^(.-)##') or label, flags = flags, bar = TAB_BAR } end fn() end,
  treeNode = function(_, a, b) local fn = b or a; if type(fn) == 'function' then fn() end end,
  itemPopup = function(_, _, fn) if PRESS then fn() end end,
}
for _, n in ipairs({ 'alignTextToFramePadding', 'beginGroup', 'beginOutline', 'dummy', 'drawRect', 'drawRectFilled', 'drawText', 'dwriteDrawTextClipped', 'endChild', 'endCombo', 'endGroup', 'endOutline', 'header', 'icon', 'image', 'indent', 'popDWriteFont', 'popDisabled', 'popID', 'popStyleColor', 'popStyleVar', 'pushDWriteFont', 'pushDisabled', 'pushID', 'pushStyleColor', 'pushStyleVar', 'sameLine', 'separator', 'setCursorX', 'setCursorY', 'setItemDefaultFocus', 'setNextItemWidth', 'setNextWindowContentSize', 'setNextWindowSizeConstraints', 'setScrollX', 'setScrollY', 'text', 'textColored', 'textDisabled', 'textWrapped', 'unindent', 'setTooltip' }) do impl[n] = noop end
ui = {}
for k, fn in pairs(impl) do ui[k] = counted(k, fn) end
for _, e in ipairs({ 'Alignment', 'ColorPickerFlags', 'ComboFlags', 'CornerFlags', 'Icons', 'InputTextFlags', 'MouseButton', 'StyleColor', 'StyleVar', 'TabBarFlags', 'TabItemFlags', 'TreeNodeFlags', 'WindowFlags' }) do ui[e] = enum(e) end
setmetatable(ui, { __index = function(_, k) error('missing ui stub: ' .. k) end })

-- Scenario
package.path = root .. '\\?.lua;' .. package.path
local errors = 0
local function step(name, fn)
  trace('== ' .. name)
  local ok, err = pcall(fn)
  if not ok then errors = errors + 1 trace('ERROR ' .. tostring(err):gsub('^[^\n]-:%d+: ', '')) end
end
step('load', function() dofile(mainFile) end)
step('update 6s', function() for _ = 1, 12 do script.update(0.5) end end)
step('chat keyword', function() chatHandler('hey ric are you here', 1) end)
step('windowMain x3', function() for _ = 1, 3 do windowMain(0.016) end end)
step('chat mention', function() chatHandler('Driver: hello', 3) end)
step('chat friend', function() chatHandler('just a friend message', 2) end)
step('chat server', function() chatHandler('server says convoy', -1) end)
step('chat none', function() chatHandler('nothing here', 3) end)
step('windowMain', function() windowMain(0.016) end)
step('windowConfig', function() windowConfig() end)
PRESS = true
step('windowConfig press', function() windowConfig() end)
step('windowMain press', function() windowMain(0.016) end)
step('update 6s again', function() for _ = 1, 12 do script.update(0.5) end end)
step('windowConfig press 2', function() windowConfig() end)
PRESS = false
step('chat after', function() chatHandler('ric again', 1) end)
step('windowConfig', function() windowConfig() end)
step('reset', function() script.reset() end)

-- Checks: targeted tests of module functions, run after the scenario. Add new cases to this list.
local CHECKS = {}
local function check(name, fn) CHECKS[#CHECKS + 1] = { name = name, fn = fn } end

local M = require('core.modules')
local S = M.settings.settings
local stateDir = 'C:\\stub\\ExtCfgState\\lua\\app\\INFERNO-ChatAlerts'
local serverKey = 'server:1.2.3.4:9600'
local function status() return tostring(M.profiles.profileStatus) end
local function keywordSet()
  local set = {}
  for _, k in ipairs(M.keywords.parseKeywords()) do set[k] = true end
  return set
end

check('settings use the INFERNO_ storage prefix', function()
  assert(STORAGE_PREFIX == 'INFERNO_', tostring(STORAGE_PREFIX))
end)
check('nothing is copied from the old isuChatAlertLua folder', function()
  for _, l in ipairs(TRACE) do assert(not l:find('isuChatAlertLua', 1, true), l) end
end)
check('a keyword reset leaves only the built-in entries', function()
  M.backup.resetKeywordSettings()
  local keywords = M.keywords.parseKeywords()
  assert(#keywords == 2, #keywords .. ' entries')
  assert(keywords[1]:byte(1) == 1 and keywords[2]:byte(1) == 1, 'unexpected keyword')
end)
check('settings backup: save then load restores values', function()
  M.backup.pendingOverwrite.backup = nil
  S.backupName = 'Roundtrip'
  S.textSize = 33
  assert(M.backup.saveSettingsBackup(), status())
  assert(FS[stateDir .. '\\Saves\\Roundtrip.json']:find('INFERNO-Settings', 1, true), 'format id missing')
  S.textSize = 60
  M.backup.selectedBackupToLoad = 'Roundtrip'
  assert(M.backup.loadSettingsBackup(), status())
  assert(S.textSize == 33, 'textSize ' .. tostring(S.textSize))
  assert(status():find('app 0.4.0', 1, true), status())
end)
-- A complete, valid settings snapshot (taken from the Roundtrip backup), so old files fail only because of their format.
local function validSnapshotJson()
  return JSON.parse(FS[stateDir .. '\\Saves\\Roundtrip.json']).payload
end
check('IsuChat Alert 2.8 backup is rejected and changes nothing', function()
  local payload = validSnapshotJson()
  FS[stateDir .. '\\Saves\\Old28.json'] = JSON.stringify({ appVersion = '2.8.2', backupFormatVersion = 1, payload = payload,
    checksum = M.backup.makeBackupChecksum('2.8.2', 1, payload) })
  S.textSize = 44
  M.backup.selectedBackupToLoad = 'Old28'
  assert(not M.backup.loadSettingsBackup(), 'old backup was accepted')
  assert(S.textSize == 44, 'settings changed')
  assert(status():find('not supported', 1, true), status())
end)
check('unwrapped legacy backup is rejected', function()
  FS[stateDir .. '\\Saves\\Legacy.json'] = validSnapshotJson()
  M.backup.selectedBackupToLoad = 'Legacy'
  assert(not M.backup.loadSettingsBackup(), 'legacy backup was accepted')
  assert(S.textSize == 44, 'settings changed')
end)
check('server backup: written with format id and read back', function()
  S.textSize = 55
  assert(M.backup.saveServerBackup('Test Server', false), status())
  local data = FS[stateDir .. '\\Saves\\Servers\\1_2_3_4_9600.json']
  assert(data and data:find('INFERNO-Settings', 1, true), 'server file missing or without format id')
  S.textSize = 70
  assert(M.backup.loadServerBackup('Test Server'), status())
  assert(S.textSize == 55, 'textSize ' .. tostring(S.textSize))
end)
check('server backup saved under the server name (old layout) is not used', function()
  FS[stateDir .. '\\Saves\\Servers\\1_2_3_4_9600.json'] = nil
  FS[stateDir .. '\\Saves\\Servers\\Test_Server.json'] = FS[stateDir .. '\\Saves\\Roundtrip.json']
  assert(not M.backup.loadServerBackup('Test Server'), 'fallback file was used')
  assert(status():find('No saved settings', 1, true), status())
end)
check('shared keyword list: export then import', function()
  M.backup.resetKeywordSettings()
  M.keywords.saveKeywords({ 'alpha', 'beta' })
  M.backup.pendingOverwrite.export = nil
  assert(M.sharing.exportSharedKeywordProfile(serverKey, 'Server: Test', 'RoundtripList'), status())
  assert(FS[stateDir .. '\\SharedKeywords\\RoundtripList.json']:find('INFERNO-KeywordList', 1, true), 'format id missing')
  M.keywords.saveKeywords({ 'gamma' })
  assert(M.sharing.stageSharedKeywordImport('RoundtripList.json', serverKey, 'Server: Test'), status())
  assert(M.sharing.applyStagedSharedKeywordImport(serverKey), status())
  local set = keywordSet()
  assert(set.alpha and set.beta and not set.gamma, 'imported list not applied')
end)
check('IsuChat shared keyword file is rejected', function()
  local payload = JSON.stringify({ serverLabel = 'Old', profile = {} })
  FS[stateDir .. '\\SharedKeywords\\OldList.json'] = JSON.stringify({ format = 'IsuChatAlertServerKeywords', formatVersion = 1,
    appVersion = '2.8.2', payload = payload, checksum = M.backup.makeBackupChecksum('2.8.2', 1, payload) })
  assert(not M.sharing.stageSharedKeywordImport('OldList.json', serverKey, 'Server: Test'), 'old shared file was accepted')
  assert(status():find('format', 1, true), status())
end)

check('friend list: tagged friend is detected and nothing is written to disk', function()
  M.friends.friendList.dirty = true
  M.friends.friendList.refresh()
  assert(M.friends.friendList.isFriend('Player2'), 'friend not detected')
  assert(M.friends.friendList.get()[1] == 'Player2', 'not listed for the Debug panel')
  for path in pairs(FS) do assert(not path:find('friends', 1, true), 'written: ' .. path) end
end)
check('shared keyword list: server address and port are written, the profile key is not', function()
  M.keywords.saveKeywords({ 'delta' })
  M.backup.pendingOverwrite.export = nil
  assert(M.sharing.exportSharedKeywordProfile(serverKey, 'Server: Test', 'NoAddress'), status())
  local data = FS[stateDir .. '\\SharedKeywords\\NoAddress.json']
  assert(data:find('1.2.3.4', 1, true), 'server address missing')
  assert(data:find('serverPort', 1, true), 'server port missing')
  assert(not data:find('serverProfileKey', 1, true), 'profile key in export')
end)

check('debug trace is written only when general debug and trace logs are both on', function()
  local function traced(probe)
    local before = #TRACE
    M.debug.Debug.trace(probe)
    return #TRACE > before and TRACE[#TRACE]:find('[TRACE]: ' .. probe, 1, true) ~= nil
  end
  S.debugEnabled, S.debugTraceEnabled = false, true
  assert(not traced('probe-master-off'), 'trace written while general debug is off')
  S.debugEnabled, S.debugTraceEnabled = true, false
  assert(not traced('probe-trace-off'), 'trace written while trace logs are off')
  S.debugTraceEnabled = true
  assert(traced('probe-on'), 'trace not written with both on')
  S.debugEnabled, S.debugTraceEnabled = false, false
end)
check('diagnostic colors are active only when general debug is on', function()
  S.debugEnabled, S.debugModeEnabled = false, true
  assert(not M.debug.Debug.colorsEnabled(), 'colors active while general debug is off')
  S.debugEnabled = true
  assert(M.debug.Debug.colorsEnabled(), 'colors inactive with both on')
  S.debugEnabled, S.debugModeEnabled = false, false
end)
check('unticked diagnostic colour falls back to its normal colour and is stored', function()
  local W = M.widgets
  local normal = W.debugColorNormal('childBg')
  S.debugEnabled, S.debugModeEnabled = true, true
  W.setDebugColorEnabled('childBg', true)
  assert(W.debugColor('childBg') ~= normal, 'colour not used while ticked')
  W.setDebugColorEnabled('childBg', false)
  assert(W.debugColor('childBg') == normal, 'unticked colour still used')
  W.saveDebugColors()
  assert(S.debugColorsData:find('off:[^;]*childBg'), 'unticked colour not stored')
  W.setDebugColorEnabled('childBg', true)
  W.saveDebugColors()
  assert(not S.debugColorsData:find('off:[^;]*childBg'), 'ticked colour still stored as off')
  S.debugEnabled, S.debugModeEnabled = false, false
end)

check('normal colour is editable, stored and used while diagnostic colours are off', function()
  local W = M.widgets
  W.resetDebugColors()
  S.debugEnabled, S.debugModeEnabled = true, true
  W.debugColorNormal('background').r = 0.5
  W.saveDebugColors()
  assert(S.normalColorsData:find('background:0.5000', 1, true), 'edited normal colour not stored')
  assert(W.debugColor('background') == W.debugColors.background, 'debug colour not used while on')
  S.debugModeEnabled = false
  assert(W.debugColor('background').r == 0.5, 'edited normal colour not used while Debug mode is off')
  W.resetDebugColors()
  assert(W.debugColorNormal('background').r == 0.14, 'reset did not restore the normal colour')
  assert(S.normalColorsData:find('background:0.1400', 1, true), 'reset normal colour not saved')
  S.debugEnabled, S.debugModeEnabled = false, false
end)

check('normal colour reset restores its default, saves it and keeps the debug colour', function()
  local W = M.widgets
  W.resetDebugColors()
  W.debugColorNormal('background').r = 0.5
  W.debugColors.background = rgbm(1, 0, 0, 1)
  W.resetNormalColor('background')
  assert(W.debugColorNormal('background').r == 0.14, 'normal reset did not restore the default')
  assert(S.normalColorsData:find('background:0.1400', 1, true), 'normal reset was not saved')
  assert(W.debugColors.background.r == 1, 'normal reset changed the debug colour')
  W.resetDebugColors()
end)

check('debug banner is drawn at the top of every tab only while general Debug is on', function()
  local function bugIcons()
    local original, count = ui.icon, 0
    ui.icon = function(icon, ...)
      if icon == ui.Icons.Bug then count = count + 1 end
      return original(icon, ...)
    end
    local ok, err = pcall(M.configWindow.windowConfig)
    ui.icon = original
    assert(ok, err)
    return count
  end
  S.debugEnabled = false
  local off = bugIcons()
  S.debugEnabled = true
  local on = bugIcons()
  S.debugEnabled = false
  assert(on - off == 6, 'expected one banner per tab (6), got ' .. (on - off))
end)

check('Tips tab is first until understood, then last, with its own tab bar', function()
  local function render()
    TAB_LOG = {}
    local ok, err = pcall(M.configWindow.windowConfig)
    local log = TAB_LOG
    TAB_LOG = nil
    assert(ok, err)
    return log
  end
  local setSelected = ui.TabItemFlags.SetSelected
  S.tipsUnderstood = false
  local first = render()
  assert(first[1].label == 'Tips' and first[#first].label == 'Tools', 'order not Tips first: ' .. first[1].label)
  S.tipsUnderstood = true
  local last = render()
  assert(last[1].label == 'Alerts' and last[#last].label == 'Tips', 'order not Tips last: ' .. last[1].label)
  assert(last[#last].bar ~= first[1].bar, 'tab bar ID did not change with the order')
  assert(last[#last].flags == setSelected, 'Tips not selected on the frame it was checked')
  for _, tab in ipairs(render()) do assert(tab.flags ~= setSelected, tab.label .. ' selected again') end
  S.tipsUnderstood = false
  local back = render()
  assert(back[1].label == 'Tips' and back[1].flags == setSelected, 'Tips not selected when unchecked')
  S.tipsUnderstood = false
end)

check('tab IDs stay the same when the language changes, so the selected tab is kept', function()
  local function ids(language)
    S.language = language
    TAB_LOG = {}
    local ok, err = pcall(M.configWindow.windowConfig)
    local log = TAB_LOG
    TAB_LOG = nil
    assert(ok, err)
    local out = {}
    for i, tab in ipairs(log) do out[i] = tab.id end
    return out
  end
  local ok, err = pcall(function()
    local english, french = ids('en'), ids('fr')
    assert(#english > 0, 'no tabs rendered')
    assert(table.concat(english, '|') == table.concat(french, '|'), 'tab IDs changed with the language')
  end)
  S.language = 'en'
  if not ok then error(err, 0) end
end)

check('Tips text follows the language setting, English by default', function()
  local headers = {}
  local origHeader, origWrapped = ui.header, ui.textWrapped
  ui.header = function(title) headers[#headers + 1] = title end
  ui.textWrapped = function() end
  local function firstHeader(language)
    headers = {}
    S.language = language
    M.tipsTab.drawTipsTab()
    return headers[1]
  end
  local ok, err = pcall(function()
    assert(firstHeader('en') == 'Getting started', 'English header missing')
    assert(firstHeader('fr') == 'Pour commencer', 'French header missing')
    assert(firstHeader('xx') == 'Getting started', 'unknown language did not fall back to English')
  end)
  ui.header, ui.textWrapped = origHeader, origWrapped
  S.language = 'en'
  if not ok then error(err, 0) end
end)

check('reset settings restores language, Tips checkbox and both window positions', function()
  S.language = 'fr'
  S.tipsUnderstood = true
  local before = #TRACE
  M.backup.resetSettings()
  assert(S.language == 'auto', 'language was not reset to automatic detection: ' .. tostring(S.language))
  assert(S.tipsUnderstood == false, 'Tips checkbox was not reset')
  local moved = {}
  for i = before + 1, #TRACE do moved[#moved + 1] = TRACE[i] end
  local function has(text)
    for _, l in ipairs(moved) do if l:find(text, 1, true) then return true end end
    return false
  end
  assert(has('move window main'), 'chat window was not repositioned')
  assert(has('resize window config') and has('move window config'), 'settings window was not repositioned')
end)

check('auto language follows the Assetto Corsa launcher, English when the file or language is unknown', function()
  local launcher = 'C:\\stub\\ACDocuments\\cfg\\launcher.ini'
  local I18n = M.i18n
  local function detect(text)
    FS[launcher] = text
    return I18n.detectLanguage()
  end
  local ok, err = pcall(function()
    assert(I18n.languageFromLauncher('pt-BR') == 'pt_BR', 'pt-BR')
    assert(I18n.languageFromLauncher('zh_TW') == 'zh-TW', 'zh_TW')
    assert(I18n.languageFromLauncher('es-419') == 'es', 'es-419')
    assert(I18n.languageFromLauncher('en-US') == 'en', 'en-US')
    assert(I18n.languageFromLauncher('pt-PT') == 'en', 'pt-PT has no pack')
    assert(I18n.languageFromLauncher(nil) == 'en', 'nil')
    assert(detect('[WINDOW]\r\nLANGUAGE=it\r\n[PROCESS]\r\n') == 'it', 'launcher language not read')
    assert(detect(nil) == 'en', 'missing launcher.ini did not fall back to English')
    S.language = 'auto'
    detect('[WINDOW]\nLANGUAGE=fr\n')
    assert(I18n.currentLanguage().code == 'auto', 'auto not kept as the setting')
    assert(I18n.activeLanguage().code == 'fr', 'auto did not use the detected language')
    assert(I18n.tr('Getting started') == 'Pour commencer', 'auto did not translate')
    assert(I18n.languageName(I18n.languages[1]) == 'Détection automatique', 'automatic entry not translated to French')
    detect('[WINDOW]\nLANGUAGE=it\n')
    assert(I18n.languageName(I18n.languages[1]) == 'Rilevamento automatico', 'automatic entry not translated to Italian')
    assert(I18n.languageName(I18n.languages[2]) == 'English', 'language names must not be translated')
    S.language = 'en'
    assert(I18n.tr('Getting started') == 'Getting started', 'manual English was overridden')
  end)
  FS[launcher] = nil
  I18n.detectLanguage()
  S.language = 'en'
end)

check('reset settings also restores debug flags, simulator friend and debug colours', function()
  S.debugEnabled = true
  S.debugTraceEnabled = true
  S.debugModeEnabled = true
  M.debug.Debug.simulator.friend = true
  M.widgets.debugColors.childBg = rgbm(1, 0, 0, 1)
  M.widgets.setDebugColorEnabled('childBg', false)
  M.backup.resetSettings()
  assert(S.debugEnabled == false and S.debugTraceEnabled == false and S.debugModeEnabled == false, 'debug flags were not reset')
  assert(M.debug.Debug.simulator.friend == false, 'simulator friend was not reset')
  assert(M.widgets.debugColors.childBg.r == 0, 'debug colour was not reset')
  assert(M.widgets.isDebugColorEnabled('childBg'), 'debug colour checkbox was not re-enabled')
  assert(not tostring(S.debugColorsData):find('off:', 1, true), 'debug colour checkboxes were not saved as reset')
end)

check('normal colours keep their defaults', function()
  local W = M.widgets
  assert(W.debugColorNormal('childBg').mult == 0, 'normal childBg should be transparent')
  assert(W.debugColorNormal('background').mult == 0.96, 'normal background band is wrong')
  W.debugColors.childBg = rgbm(1, 0, 0, 1)
  assert(W.debugColorNormal('childBg').mult == 0, 'normal colour followed the debug colour')
  W.resetDebugColors()
  assert(W.debugColorNormal('childBg').mult == 0, 'normal colour changed after reset')
end)

check('per-colour reset restores the debug default, keeps its checkbox and saves it', function()
  local W = M.widgets
  W.resetDebugColors()
  local default = W.debugColorDefault('childBg')
  assert(default.r == 0 and default.g == 0 and default.b == 1 and default.mult == 0.9, 'debug default childBg is wrong')
  assert(W.debugColors.childBg ~= default, 'debug colour is aliased to its read-only default')
  W.debugColors.childBg = rgbm(1, 0, 0, 1)
  assert(W.debugColorDefault('childBg').r == 0, 'editing the colour changed its default')
  W.setDebugColorEnabled('childBg', false)
  W.resetDebugColor('childBg')
  assert(W.debugColors.childBg.r == 0 and W.debugColors.childBg.b == 1, 'per-colour reset did not restore the default')
  assert(W.debugColors.childBg ~= default, 'reset stored the default table itself')
  assert(not W.isDebugColorEnabled('childBg'), 'per-colour reset changed the checkbox')
  assert(S.debugColorsData:find('childBg:0.0000,0.0000,1.0000,0.9000', 1, true), 'per-colour reset was not saved')
  W.setDebugColorEnabled('childBg', true)
  W.resetDebugColors()
end)

check('tools tab draws the diagnostic colour header without errors', function()
  local seen = {}
  local origTextDisabled, origText = ui.textDisabled, ui.text
  ui.textDisabled = function(s) seen[tostring(s)] = true end
  ui.text = function(s) seen[tostring(s)] = true end
  local debugEnabled, debugModeEnabled = S.debugEnabled, S.debugModeEnabled
  local ok, err = pcall(function()
    S.debugEnabled = false
    S.debugModeEnabled = true
    M.toolsTab.drawToolsTab()
    assert(seen['Debug default'] and seen['Normal'], 'diagnostic colour column headers are missing')
  end)
  ui.textDisabled, ui.text = origTextDisabled, origText
  S.debugEnabled, S.debugModeEnabled = debugEnabled, debugModeEnabled
  if not ok then error(err, 0) end
end)

check('diagnostic colour reset buttons do not share an ImGui id', function()
  local stack, seen, duplicate, calls = {}, {}, nil, 0
  local origPush, origPop, origIcon, origCheckbox, origColorButton = ui.pushID, ui.popID, ui.iconButton, ui.checkbox, ui.colorButton
  local debugEnabled, debugModeEnabled = S.debugEnabled, S.debugModeEnabled
  ui.pushID = function(id) stack[#stack + 1] = tostring(id) end
  ui.popID = function() stack[#stack] = nil end
  ui.iconButton = function(icon)
    calls = calls + 1
    local id = table.concat(stack, '/') .. '|' .. tostring(icon)
    if seen[id] then duplicate = duplicate or id end
    seen[id] = true
    return false
  end
  ui.checkbox = function() return false end
  ui.colorButton = function() return false end
  local ok, err = pcall(function()
    S.debugEnabled = false
    S.debugModeEnabled = true
    M.toolsTab.drawToolsTab()
  end)
  ui.pushID, ui.popID, ui.iconButton, ui.checkbox, ui.colorButton = origPush, origPop, origIcon, origCheckbox, origColorButton
  S.debugEnabled, S.debugModeEnabled = debugEnabled, debugModeEnabled
  if not ok then error(err, 0) end
  assert(calls >= 12, 'reset buttons were not drawn (' .. calls .. ' icon buttons)')
  assert(not duplicate, 'duplicate icon button id: ' .. tostring(duplicate))
end)

check('every language pack has the French key set, with matching placeholders', function()
  local fr = require('lang.fr')
  local function placeholders(text)
    local found = {}
    for p in text:gmatch('%%[sd%%]') do found[#found + 1] = p end
    table.sort(found)
    return table.concat(found, ' ')
  end
  for _, code in ipairs({ 'it', 'de', 'es', 'pt_BR', 'ru', 'pl', 'tr', 'nl', 'cs', 'hu', 'ro', 'sv', 'fi', 'uk', 'zh-CN', 'zh-TW' }) do
    local pack = require('lang.' .. code)
    for key in pairs(fr) do
      assert(type(pack[key]) == 'string' and pack[key] ~= '', code .. ' has no translation for: ' .. key)
      assert(placeholders(pack[key]) == placeholders(key), code .. ' placeholders differ for: ' .. key)
    end
    for key in pairs(pack) do
      assert(fr[key] ~= nil, code .. ' has an extra key: ' .. key)
    end
  end
end)

-- Keyword list drag (ui/list_drag.lua): a simulated list in a scrolling window, 60 fps unless a dt is given.
-- Row centres are content coordinates; the scroll returned by update() is applied on the next frame, as in ImGui.
local function newDragList(heights, windowHeight)
  local list = { drag = M.listDrag.new(), items = {}, centers = {}, scrollY = 0, windowHeight = windowHeight or 731, swaps = 0 }
  local y = 170
  for i, height in ipairs(heights) do
    list.items[i] = i
    list.centers[i] = y + height / 2
    y = y + height
  end
  list.scrollMaxY = math.max(0, y + 60 - list.windowHeight)
  return list
end
local function sameRows(count)
  local heights = {}
  for i = 1, count do heights[i] = 128 end
  return heights
end
-- One frame; returns the scroll step the module asked for (0 if none).
local function dragFrame(list, mouseDown, pointerY, dt, pressIndex)
  if list.pendingScroll then
    list.scrollY = list.pendingScroll
    list.pendingScroll = nil
  end
  if pressIndex then list.drag:press(pressIndex, pointerY) end
  local moves, scrollY = list.drag:update({ mouseDown = mouseDown, pointerY = pointerY, windowHeight = list.windowHeight,
    scrollY = list.scrollY, scrollMaxY = list.scrollMaxY, dt = dt or 1 / 60, centers = list.centers })
  for _, move in ipairs(moves) do
    assert(math.abs(move[1] - move[2]) == 1, 'non-adjacent swap')
    list.items[move[1]], list.items[move[2]] = list.items[move[2]], list.items[move[1]]
    list.swaps = list.swaps + 1
  end
  if not scrollY then return 0 end
  assert(scrollY >= 0 and scrollY <= list.scrollMaxY, 'scroll out of range: ' .. scrollY)
  list.pendingScroll = scrollY
  return scrollY - list.scrollY
end
local function slotPointer(list, index) return list.centers[index] - list.scrollY end
local function glide(list, from, to, frames)
  for f = 1, frames do dragFrame(list, true, from + (to - from) * f / frames) end
end
-- Distance between the dragged slot and the grabbed point of the row, which follows the pointer.
local function rowLag(list, pointerY)
  local itemY = math.max(0, math.min(pointerY, list.windowHeight)) + list.scrollY - list.drag.grabOffset
  return math.abs(list.centers[list.drag.index] - itemY), itemY
end
local function assertOrder(list, expected)
  for i, item in ipairs(expected) do assert(list.items[i] == item, 'order ' .. table.concat(list.items, ',')) end
end

check('list drag: a click without movement neither reorders nor scrolls', function()
  local list = newDragList(sameRows(9))
  local y = slotPointer(list, 3)
  dragFrame(list, true, y, nil, 3)
  for f = 1, 30 do
    assert(dragFrame(list, true, y + (f % 2 == 0 and 3 or -3)) == 0, 'scrolled')
  end
  assert(not list.drag.moved, 'a 3 px tremor started the drag')
  dragFrame(list, false, y)
  assert(list.swaps == 0 and list.drag.index == nil, 'swaps ' .. list.swaps)
end)

check('list drag: 3 rows down then back gives exactly 3 swaps each way, without scrolling', function()
  local list = newDragList(sameRows(9))
  local start, target = slotPointer(list, 1), slotPointer(list, 4)
  dragFrame(list, true, start, nil, 1)
  glide(list, start, target, 24)
  assert(list.drag.index == 4 and list.swaps == 3, 'down: index ' .. tostring(list.drag.index) .. ', swaps ' .. list.swaps)
  assertOrder(list, { 2, 3, 4, 1, 5 })
  glide(list, target, start, 24)
  assert(list.drag.index == 1 and list.swaps == 6, 'back: index ' .. tostring(list.drag.index) .. ', swaps ' .. list.swaps)
  dragFrame(list, false, start)
  assertOrder(list, { 1, 2, 3, 4, 5, 6, 7, 8, 9 })
  assert(list.scrollY == 0 and list.pendingScroll == nil, 'scrolled')
end)

check('list drag: a 4 px tremor on the swap threshold swaps once', function()
  local list = newDragList(sameRows(9))
  local start = slotPointer(list, 1)
  local threshold = start + (list.centers[2] - list.centers[1]) * list.drag.swapAt
  dragFrame(list, true, start, nil, 1)
  glide(list, start, threshold + 1, 6)
  for f = 1, 60 do dragFrame(list, true, threshold + (f % 2 == 0 and 4 or -4)) end
  assert(list.swaps == 1 and list.drag.index == 2, 'swaps ' .. list.swaps)
end)

check('list drag: holding in the bottom zone scrolls after the delay, capped, with the row under the pointer', function()
  local list = newDragList(sameRows(9))
  local drag = list.drag
  local start, hold = slotPointer(list, 2), list.windowHeight - drag.edge / 2
  dragFrame(list, true, start, nil, 2)
  local zoneTime, firstScroll, lastStep = 0, nil, nil
  for f = 1, 370 do
    local pointer = f <= 10 and start + (hold - start) * f / 10 or hold
    if pointer > list.windowHeight - drag.edge then zoneTime = zoneTime + 1 / 60 end
    local step = dragFrame(list, true, pointer)
    assert(step >= 0 and step <= drag.maxSpeed / 60 + 1e-6, 'scroll step ' .. step)
    if step > 0 and not firstScroll then firstScroll = zoneTime end
    assert(rowLag(list, pointer) <= 128 * drag.swapAt + 1e-6, 'row left the pointer: ' .. rowLag(list, pointer))
    lastStep = step
  end
  assert(firstScroll and firstScroll >= drag.delay - 1e-9 and firstScroll < drag.delay + 0.05, 'first scroll at ' .. tostring(firstScroll))
  assert(drag.index == 9 and list.items[9] == 2, 'index ' .. drag.index)
  assert(lastStep == 0, 'still scrolling with the row at the end of the list')
end)

check('list drag: a pointer far below the window keeps the speed capped and the row at the edge', function()
  local list = newDragList(sameRows(9))
  local drag = list.drag
  local start, far = slotPointer(list, 2), list.windowHeight + 500
  dragFrame(list, true, start, nil, 2)
  local fastest = 0
  for f = 1, 130 do
    local pointer = f <= 10 and start + (far - start) * f / 10 or far
    local step = dragFrame(list, true, pointer)
    assert(step <= drag.maxSpeed / 60 + 1e-6, 'scroll step ' .. step)
    fastest = math.max(fastest, step)
    assert(rowLag(list, pointer) <= 128 * drag.swapAt + 1e-6, 'row left the window edge')
  end
  assert(fastest > 0.9 * drag.maxSpeed / 60, 'never reached full speed: ' .. fastest)
end)

check('list drag: brushing the bottom zone for 0.25 s does not scroll, and the delay restarts', function()
  local list = newDragList(sameRows(9))
  local drag = list.drag
  local start, zone = slotPointer(list, 2), list.windowHeight - drag.edge / 2
  dragFrame(list, true, start, nil, 2)
  for _ = 1, 2 do
    glide(list, start, 500, 5)
    for _ = 1, 15 do assert(dragFrame(list, true, zone) == 0, 'scrolled during a brush') end
    for _ = 1, 60 do assert(dragFrame(list, true, 500) == 0, 'scrolled outside the zone') end
  end
  assert(list.scrollY == 0, 'scrollY ' .. list.scrollY)
end)

check('list drag: no auto-scroll past the ends of the list', function()
  local list = newDragList(sameRows(9))
  list.scrollY = list.centers[9] - (list.windowHeight - 20)
  dragFrame(list, true, list.windowHeight - 20, nil, 9)
  for f = 1, 120 do assert(dragFrame(list, true, list.windowHeight - 6) == 0, 'last row scrolled down') end
  assert(list.swaps == 0, 'last row swapped')
  list = newDragList(sameRows(9))
  list.scrollY = list.centers[1] - 20
  dragFrame(list, true, 20, nil, 1)
  for f = 1, 120 do assert(dragFrame(list, true, 6) == 0, 'first row scrolled up') end
  assert(list.swaps == 0, 'first row swapped')
end)

check('list drag: the mouse wheel carries the held row with the content', function()
  local list = newDragList(sameRows(9))
  local start = slotPointer(list, 2)
  dragFrame(list, true, start, nil, 2)
  glide(list, start, start + 40, 4)
  assert(list.drag.index == 2 and list.drag.moved, 'drag did not start')
  list.scrollY = list.scrollY + 256
  dragFrame(list, true, start + 40)
  assert(list.drag.index == 4 and list.swaps == 2, 'index ' .. list.drag.index .. ', swaps ' .. list.swaps)
end)

check('list drag: a 0.5 s frame hitch scrolls at most one capped step', function()
  local list = newDragList(sameRows(9))
  local drag = list.drag
  local start, below = slotPointer(list, 2), list.windowHeight + 10
  dragFrame(list, true, start, nil, 2)
  glide(list, start, below, 10)
  for _ = 1, 80 do dragFrame(list, true, below) end
  local step = dragFrame(list, true, below, 0.5)
  assert(step > 0 and step <= drag.maxSpeed * drag.maxStep + 1e-6, 'hitch step ' .. step)
end)

check('list drag: release resets the state, presses are ignored while dragging', function()
  local list = newDragList(sameRows(9))
  local drag = list.drag
  local start = slotPointer(list, 2)
  dragFrame(list, true, start, nil, 2)
  glide(list, start, list.windowHeight + 10, 10)
  for _ = 1, 60 do dragFrame(list, true, list.windowHeight + 10) end
  assert(drag.scrolling, 'no auto-scroll')
  local index = drag.index
  drag:press(index == 7 and 6 or 7, 100)
  assert(drag.index == index and drag.moved and drag.grabOffset ~= nil, 'a press changed the running drag')
  dragFrame(list, false, 300)
  assert(drag.index == nil and not drag.moved and not drag.scrolling and drag.grabOffset == nil, 'state kept after release')
  dragFrame(list, true, 300, nil, 3)
  assert(drag.index == 3, 'new press ignored')
end)

check('list drag: 500 random drags keep a permutation and drop next to the pointer', function()
  math.randomseed(20240521)
  for run = 1, 500 do
    local heights = {}
    local count = math.random(2, 12)
    for i = 1, count do heights[i] = math.random(90, 170) end
    local list = newDragList(heights, math.random(300, 900))
    local drag = list.drag
    list.scrollY = math.random(0, math.floor(list.scrollMaxY))
    local visible = {}
    for i = 1, count do
      local y = slotPointer(list, i)
      if y >= 0 and y <= list.windowHeight then visible[#visible + 1] = i end
    end
    if #visible > 0 then
      local index = visible[math.random(#visible)]
      local pointer = slotPointer(list, index) + math.random(-30, 30)
      dragFrame(list, true, pointer, nil, index)
      for _ = 1, math.random(20, 240) do
        local r = math.random()
        if r < 0.05 then
          pointer = math.random(-200, list.windowHeight + 200)
        elseif r < 0.08 then
          list.scrollY = math.max(0, math.min(list.scrollY + (math.random() < 0.5 and -120 or 120), list.scrollMaxY))
        else
          pointer = pointer + math.random(-25, 25)
        end
        local dt = math.random() < 0.03 and 0.4 or 1 / math.random(30, 144)
        local step = dragFrame(list, true, pointer, dt)
        assert(math.abs(step) <= drag.maxSpeed * math.min(dt, drag.maxStep) + 1e-6, 'run ' .. run .. ': scroll step ' .. step)
        if drag.moved then
          local _, itemY = rowLag(list, pointer)
          local nearest, best = 1, math.huge
          for i, center in ipairs(list.centers) do
            if math.abs(center - itemY) < best then nearest, best = i, math.abs(center - itemY) end
          end
          assert(math.abs(drag.index - nearest) <= 1, 'run ' .. run .. ': row ' .. drag.index .. ', pointer over ' .. nearest)
        end
      end
      dragFrame(list, false, pointer)
      assert(drag.index == nil, 'run ' .. run .. ': not released')
      local seen = {}
      for _, item in ipairs(list.items) do seen[item] = true end
      for i = 1, count do assert(seen[i], 'run ' .. run .. ': lost row ' .. i) end
    end
  end
end)

-- CSP's ui.mouseLocalPos() is in content coordinates (it includes the scroll), like ui.getCursorY().
local function keywordDragScenario(contentTop, scrolled)
  local K = M.keywords
  local original = {}
  for i, keyword in ipairs(K.parseKeywords()) do original[i] = keyword end
  K.saveKeywords({ 'alpha', 'bravo', 'charlie', K.specialAlertKeys.player, K.specialAlertKeys.friend })
  M.alertsTab.keywordDrag:reset()
  local names = { 'itemActive', 'mouseDown', 'mouseLocalPos', 'getCursorY', 'getScrollY', 'getScrollMaxY', 'drawRect', 'pushID', 'popID' }
  local saved = {}
  for _, name in ipairs(names) do saved[name] = ui[name] end
  local held, pointerY, cursorY, scrollY, ids, rects = false, 0, 0, 0, {}, {}
  ui.pushID = function(id) ids[#ids + 1] = id end
  ui.popID = function() ids[#ids] = nil end
  ui.itemActive = function()
    for _, id in ipairs(ids) do if id == 'keyword2' then return held end end
    return false
  end
  ui.mouseDown = function() return held end
  ui.mouseLocalPos = function() return vec2(0, pointerY) end
  ui.getCursorY = function() cursorY = cursorY + 40 return cursorY end
  ui.getScrollY = function() return scrollY end
  ui.getScrollMaxY = function() return scrolled and scrollY + 1000 or 0 end
  ui.drawRect = function(p1, p2, _, _, _, thickness) rects[#rects + 1] = { center = (p1.y + p2.y) / 2, thickness = thickness } end
  local function frame()
    cursorY, rects = contentTop, {}
    M.alertsTab.drawAlertsTab()
    local thick = {}
    for _, rect in ipairs(rects) do if rect.thickness == 3 then thick[#thick + 1] = rect.center end end
    return thick
  end
  local ok, err = pcall(function()
    assert(#frame() == 0, 'thick frame without a drag')
    local centers = {}
    for i, rect in ipairs(rects) do centers[i] = rect.center end
    assert(#centers == 5, #centers .. ' row frames')
    if scrolled then scrollY = centers[1] - 100 end
    held, pointerY = true, centers[2]
    for _, y in ipairs({ centers[2], centers[2] + 10, centers[2] + 10 }) do
      pointerY = y
      local thick = frame()
      assert(#thick == 1 and thick[1] == y, 'drag frame missing or not under the pointer')
    end
    assert(K.parseKeywords()[2] == 'bravo', 'a small move reordered the list')
    pointerY = centers[3]
    frame()
    assert(K.parseKeywords()[3] == 'bravo' and K.parseKeywords()[2] == 'charlie', 'no swap down under the pointer')
    local thick = frame()
    assert(#thick == 1 and thick[1] == centers[3], 'drag frame did not follow the pointer after a swap')
    pointerY = centers[2]
    thick = frame()
    assert(K.parseKeywords()[2] == 'bravo' and K.parseKeywords()[3] == 'charlie', 'no swap up under the pointer')
    assert(#thick == 1 and thick[1] == centers[2], 'drag frame did not follow the pointer back up')
    held = false
    frame()
    assert(M.alertsTab.keywordDrag.index == nil, 'drag kept after release')
    assert(#frame() == 0, 'thick frame after release')
  end)
  for _, name in ipairs(names) do ui[name] = saved[name] end
  K.saveKeywords(original)
  assert(ok, err)
end

check('keyword drag: a frame follows the pointer while the held row swaps', function()
  keywordDragScenario(0, false)
end)

check('keyword drag: the pointer moves the row up and down in a scrolled list', function()
  keywordDragScenario(1000, true)
end)

local checkResults = {}
local failed = 0
for _, c in ipairs(CHECKS) do
  local ok, err = pcall(c.fn)
  if not ok then failed = failed + 1 end
  checkResults[#checkResults + 1] = (ok and 'PASS ' or 'FAIL ') .. c.name .. (ok and '' or (': ' .. tostring(err)))
end

for _, l in ipairs(TRACE) do print(l) end
print('== final settings')
local keys = {}
for k in pairs(STORE or {}) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do print(k .. ' = ' .. ser(STORE[k])) end
print('== ui calls')
keys = {}
for k in pairs(UICOUNT) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do print(k .. ' ' .. UICOUNT[k]) end
print('== checks')
for _, l in ipairs(checkResults) do print(l) end
print(string.format('== summary: %d scenario error(s), %d of %d check(s) failed', errors, failed, #CHECKS))
os.exit((errors > 0 or failed > 0) and 1 or 0)
