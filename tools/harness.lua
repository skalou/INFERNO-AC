-- Smoke test: runs the app against deterministic CSP stubs and prints a trace, then the results of the checks.
-- Usage (from the repository root): luajit tools\harness.lua INFERNO-ChatAlerts.lua [dev]
-- Exit code 1 if a scenario step raised an error or a check failed.
local mainFile = arg[1]
local withDev = arg[2] == 'dev'
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
function rgbm(r, g, b, m) return { r = r, g = g, b = b, mult = m, _rgbm = true } end

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
local function window(name)
  local pos, size = vec2(50, 63), vec2(680, 260)
  return {
    valid = function() return true end, visible = function() return true end,
    position = function() return pos end, size = function() return size end,
    move = function(_, v) pos = v trace('move window ' .. name .. ' ' .. tostring(v)) end,
    resize = function(_, v) size = v trace('resize window ' .. name .. ' ' .. tostring(v)) end,
  }
end
local mainWindow = window('main')
STORE = nil
ac = {
  FolderID = setmetatable({}, { __index = function(_, k) return k end }),
  getFolder = function(id) return 'C:\\stub\\' .. tostring(id) end,
  storage = function(defaults, prefix)
    STORE = {}
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
  isTaggedAsFriend = function(i) return i == 2 end,
  getAppWindows = function() return { { name = 'INFERNO-Chat Alerts_main', title = 'INFERNO-Chat Alerts' } } end,
  accessAppWindow = function(n) return mainWindow end,
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
  getCursor = function() return vec2(0, 0) end, getCursorY = function() return 0 end, cursorStartPos = function() return vec2(0, 30) end,
  mousePos = function() return vec2(100, 100) end, mouseLocalPos = function() return vec2(0, 0) end,
  getScrollMaxX = function() return 0 end, time = function() return 1.5 end, fontSize = function() return 14 end,
  mouseWheel = function() return 0 end, windowResizing = function() return false end,
  measureText = function(s) return vec2(#s * 7, 14) end,
  measureDWriteText = function(s, size, width) local w = #s * size * 0.5; local lines = width and math.ceil(w / width) or 1; return vec2(width and math.min(w, width) or w, size * lines) end,
  button = function() return PRESS end, iconButton = function() return PRESS end, checkbox = function() return PRESS end,
  selectable = function() return PRESS end, mouseClicked = function() return PRESS end, itemClicked = function() return PRESS end,
  beginCombo = function() return PRESS end, beginChild = function() return true end, itemHovered = function() return PRESS end,
  itemActive = function() return false end, mouseDown = function() return false end, windowHovered = function() return PRESS end,
  isWindowAppearing = function() return true end, colorPicker = function() return false end, colorButton = function() return false end,
  inputText = function(_, text) return text end, slider = function(_, v) return v end,
  tabBar = function(id, a, b) local fn = b or a; fn() end, tabItem = function(_, fn) fn() end,
  treeNode = function(_, a, b) local fn = b or a; if type(fn) == 'function' then fn() end end,
  itemPopup = function(_, _, fn) if PRESS then fn() end end,
}
for _, n in ipairs({ 'beginOutline', 'dummy', 'drawRectFilled', 'drawText', 'dwriteDrawTextClipped', 'endChild', 'endCombo', 'endOutline', 'header', 'icon', 'indent', 'popDWriteFont', 'popID', 'popStyleColor', 'popStyleVar', 'pushDWriteFont', 'pushID', 'pushStyleColor', 'pushStyleVar', 'sameLine', 'separator', 'setItemDefaultFocus', 'setNextItemWidth', 'setNextWindowContentSize', 'setNextWindowSizeConstraints', 'setScrollX', 'text', 'textColored', 'textDisabled', 'textWrapped', 'unindent', 'setTooltip' }) do impl[n] = noop end
ui = {}
for k, fn in pairs(impl) do ui[k] = counted(k, fn) end
for _, e in ipairs({ 'Alignment', 'ColorPickerFlags', 'ComboFlags', 'Icons', 'InputTextFlags', 'MouseButton', 'StyleColor', 'StyleVar', 'TabBarFlags', 'WindowFlags' }) do ui[e] = enum(e) end
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
if windowDev and withDev then step('windowDev', function() windowDev(0.016) end) end

-- Checks: targeted tests of module functions, run after the scenario. Add new cases to this list.
local CHECKS = {}
local function check(name, fn) CHECKS[#CHECKS + 1] = { name = name, fn = fn } end
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
