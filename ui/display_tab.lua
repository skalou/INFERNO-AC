-- Settings window, Display tab: test previews and alert appearance.
local modules = require('core.modules')
local Alert = modules.alert
local DisplayTab = modules.displayTab

local settings = modules.settings.settings
local maxOutlineScale = modules.settings.maxOutlineScale
local sliders = modules.widgets.sliders
local drawColorSetting = modules.widgets.drawColorSetting

local longPreviewMessage = 'This is a long chat preview to check how the alert wraps across multiple lines without extending beyond the chat window width. Keep resizing the chat window or change the text size in settings to verify that the entire message remains visible and the window grows vertically as needed. This final sentence helps test particularly long messages.'

local triggerTestAlert

local function drawDisplayTab()
  ui.header('Test & Preview')
  if ui.button('Test short preview', vec2(-0.1, 0)) then
	triggerTestAlert('short')
  end
  if ui.button('Test long message', vec2(-0.1, 0)) then
	triggerTestAlert('long')
  end
  if Alert.testMode and ui.button('Stop test', vec2(-0.1, 0)) then
	Alert.testMode = nil
	Alert.testMessagePending = nil
	Alert.latestMessage = ''
	Alert.textScrollElapsed = 0
	Alert.alertTimeLeft = 0
	Alert.firstScrollRequired = false
	Alert.firstScrollComplete = false
	Alert.measuredMessage = nil
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

return DisplayTab
