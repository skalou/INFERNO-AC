-- Settings window, Display tab: test previews and alert appearance.
local modules = require('core.modules')
local Alert = modules.alert
local DisplayTab = modules.displayTab
local tr = modules.i18n.tr

local settings = modules.settings.settings
local maxOutlineScale = modules.settings.maxOutlineScale
local sliders = modules.widgets.sliders
local drawColorSetting = modules.widgets.drawColorSetting
local drawThemeColorSetting = modules.widgets.drawThemeColorSetting

local longPreviewMessage = 'This is a long chat preview to check how the alert wraps across multiple lines without extending beyond the chat window width. Keep resizing the chat window or change the text size in settings to verify that the entire message remains visible and the window grows vertically as needed. This final sentence helps test particularly long messages.'

local triggerTestAlert

local function drawDisplayTabHeader()
  ui.header(tr('Test & Preview'))
  if ui.button(tr('Test short preview'), vec2(-0.1, 0)) then
	triggerTestAlert('short')
  end
  if ui.button(tr('Test long message'), vec2(-0.1, 0)) then
	triggerTestAlert('long')
  end
  if Alert.testMode and ui.button(tr('Stop test'), vec2(-0.1, 0)) then
	Alert.testMode = nil
	Alert.testMessagePending = nil
	Alert.latestMessage = ''
	Alert.textScrollElapsed = 0
	Alert.alertTimeLeft = 0
	Alert.firstScrollRequired = false
	Alert.firstScrollComplete = false
	Alert.measuredMessage = nil
  end
end

local function drawDisplayTab()
  ui.header(tr('Display Settings'))
  if sliders.checkbox(tr('Show all chat messages'), settings.showAllChatMessages, sliders.defaults.showAllChatMessages, 'showAllChatMessages') then
	settings.showAllChatMessages = not settings.showAllChatMessages
  end
  if sliders.checkbox(tr('Hide alert when not hovered'), settings.hideWhenNotHovered, sliders.defaults.hideWhenNotHovered, 'hideWhenNotHovered') then
	settings.hideWhenNotHovered = not settings.hideWhenNotHovered
  end
  settings.textSize = sliders.withDefault(tr('Text size'), settings.textSize, 8, 96, '%.0f px', sliders.defaults.textSize, 1, 'textSize')
  settings.duration = sliders.withDefault(tr('Base display time'), settings.duration, 0.1, 10, '%.1f s', sliders.defaults.duration, 0.1, 'duration')
  settings.opacity = sliders.withDefault(tr('Alert opacity multiplier'), settings.opacity, 0, 100, '%.0f%%', sliders.defaults.opacity, 1, 'opacity')
  ui.separator()
  drawColorSetting(tr('Text color'), 'textColor')
  drawColorSetting(tr('Author color'), 'authorColor')
  drawColorSetting(tr('Player color'), 'playerColor')
  drawColorSetting(tr('Friend color'), 'friendColor')
  drawColorSetting(tr('Outline color'), 'outlineColor')
  local outlineScale = math.min(maxOutlineScale, settings.outlineThicknessPercent * settings.textSize / 100)
  local outlineDefault = math.min(maxOutlineScale, sliders.defaults.outlineThicknessPercent * settings.textSize / 100)
  outlineScale = sliders.withDefault(tr('Outline scale (CSP)'), outlineScale, 0, maxOutlineScale, '%.1f', outlineDefault, 0.1, 'outlineThicknessPercent')
  settings.outlineThicknessPercent = outlineScale * 100 / settings.textSize
  if sliders.checkbox(tr('Soft outline gradient'), settings.softOutline, sliders.defaults.softOutline, 'softOutline') then
	settings.softOutline = not settings.softOutline
  end
  if sliders.checkbox(tr('Show background'), settings.backgroundEnabled, sliders.defaults.backgroundEnabled, 'backgroundEnabled') then
	settings.backgroundEnabled = not settings.backgroundEnabled
  end
  drawColorSetting(tr('Background color'), 'backgroundColor')
  drawColorSetting(tr('Accent color'), 'accentColor')
  ui.separator()
  drawThemeColorSetting(tr('Settings theme color 1'), 'themeColor')
  drawThemeColorSetting(tr('Settings theme color 2 (background)'), 'themeBgColor')
end

function triggerTestAlert(messageType)
  local ownName = ac.getDriverName(0) or 'Driver'
  if messageType == 'short' then
	Alert.testMessagePending = { mode = 'short', message = ownName:sub(1, 15) .. ' : This is a test message preview.', duration = 10 }
  elseif messageType == 'long' then
	Alert.testMessagePending = { mode = 'long', message = ownName:sub(1, 15) .. ' : ' .. longPreviewMessage, duration = 15 }
  end
  ac.setWindowOpen('main', true)
end

DisplayTab.drawDisplayTab = drawDisplayTab
DisplayTab.drawDisplayTabHeader = drawDisplayTabHeader

return DisplayTab
