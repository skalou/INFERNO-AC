-- Access to the app windows and their geometry.
local modules = require('core.modules')
local Windows = modules.windows

local App = modules.paths.App
local Debug = modules.debug.Debug
local isFiniteNumber = modules.util.isFiniteNumber

local getMainAppWindow
local resetMainWindowGeometry
local applyBackupWindowGeometry

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

Windows.getMainAppWindow = getMainAppWindow
Windows.resetMainWindowGeometry = resetMainWindowGeometry
Windows.applyBackupWindowGeometry = applyBackupWindowGeometry
Windows.applyWindowGeometry = applyWindowGeometry

return Windows
