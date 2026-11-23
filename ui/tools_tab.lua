-- Settings window, Tools tab: resets, debug info, friends, simulator, debug colours.
local modules = require('core.modules')
local Alert = modules.alert
local ToolsTab = modules.toolsTab
local tr = modules.i18n.tr

local App = modules.paths.App
local settings = modules.settings.settings
local Debug = modules.debug.Debug
local alertHistory = modules.history.alertHistory
local sliders = modules.widgets.sliders
local Widgets = modules.widgets
local debugColors = modules.widgets.debugColors
local saveDebugColors = modules.widgets.saveDebugColors
local drawColorButton = modules.widgets.drawColorButton
local drawColorSwatch = modules.widgets.drawColorSwatch
local drawLanguageSelector = modules.widgets.drawLanguageSelector
local debugColorNormalDefault = modules.widgets.debugColorNormalDefault
local friendList = modules.friends.friendList
local resetAudioSettings = modules.backup.resetAudioSettings
local resetAlertAppearanceSettings = modules.backup.resetAlertAppearanceSettings
local resetKeywordSettings = modules.backup.resetKeywordSettings
local resetSettings = modules.backup.resetSettings
local handleChatMessage = modules.chat.handleChatMessage

-- Diagnostic colors table: checkbox and label, then aligned columns for the editable Debug colour, its reset, the read-only Debug default and the read-only Normal colour.
local debugColorRows = {
  { 'Background rectangle', 'background' },
  { 'Child background', 'childBg' },
  { 'Scrollbar background', 'scrollbarBg' },
  { 'Used sound (already in an alert)', 'usedSound' },
  { 'Selected sound (this alert)', 'selectedSound' },
  { 'Default sound (00defaultALERT.wav)', 'defaultSound' },
  { 'Keyword row frame', 'rowFrame' },
}
local editWidth, resetWidth = 32, 20
-- Offset of the label after its checkbox, read on each row and used by the layout of the next frame.
local checkboxLabelOffset = 24
-- Cache vehicle/server info: check only on tab open or config open, not every frame
local debugInfoCache = {
  vehicleName = ac.getCarName(0) or ac.getCarID(0) or tr('No car'),
  serverName = ac.getServerName() or tr('Offline'),
  lastUpdateTime = 0,
  updateInterval = 2.0  -- Update every 2 seconds minimum (not every frame)
}

local function debugColorLayout(originX)
  local maxLabel = 0
  for _, row in ipairs(debugColorRows) do maxLabel = math.max(maxLabel, ui.measureText(tr(row[1])).x) end
  local layout = { originX = originX }
  layout.editX = checkboxLabelOffset + maxLabel + 12
  layout.resetX = layout.editX + editWidth + 10
  layout.defaultX = layout.resetX + resetWidth + 16
  layout.normalX = layout.defaultX + math.max(editWidth, ui.measureText(tr('Debug default')).x) + 16
  layout.normalResetX = layout.normalX + editWidth + 10
  layout.normalDefaultX = layout.normalResetX + resetWidth + 16
  return layout
end

local function drawDebugColorHeader(layout)
  ui.setCursorX(layout.originX + layout.editX)
  Widgets.textDisabled(tr('Debug'))
  ui.sameLine(layout.originX + layout.defaultX)
  Widgets.textDisabled(tr('Debug default'))
  ui.sameLine(layout.originX + layout.normalX)
  Widgets.textDisabled(tr('Normal'))
  ui.sameLine(layout.originX + layout.normalDefaultX)
  Widgets.textDisabled(tr('Normal default'))
end

local function drawDebugColorSetting(label, key, layout)
  local enabled = Widgets.isDebugColorEnabled(key)
  if ui.checkbox('##debug_enable_' .. key, enabled) then Widgets.setDebugColorEnabled(key, not enabled) end
  Widgets.settingTooltip('debugColorEnabled', enabled, true)
  ui.sameLine()
  checkboxLabelOffset = ui.getCursorX() - layout.originX
  Widgets.text(label)
  Widgets.settingTooltip(key, debugColors[key])
  ui.sameLine(layout.originX + layout.editX)
  drawColorButton('##debug_color_' .. key, debugColors[key], ui.ColorPickerFlags.AlphaPreview)
  Widgets.settingTooltip(key, debugColors[key])
  ui.itemPopup('##debug_color_popup_' .. key, ui.MouseButton.Left, function()
    Widgets.text(tr('Choose %s', label:lower()))
    ui.colorPicker('##debug_color_picker_' .. key, debugColors[key], bit.bor(
      ui.ColorPickerFlags.AlphaBar,
      ui.ColorPickerFlags.AlphaPreview,
      ui.ColorPickerFlags.PickerHueWheel
    ))
  end)
  ui.sameLine(layout.originX + layout.resetX)
  ui.pushID('debugReset_' .. key)
  if ui.iconButton(ui.Icons.Reset, vec2(resetWidth, resetWidth), rgbm(1, 1, 1, 1), rgbm(0, 0, 0, 0)) then
    Widgets.resetDebugColor(key)
  end
  ui.popID()
  Widgets.settingTooltip('debugColorReset', debugColors[key])
  ui.sameLine(layout.originX + layout.defaultX)
  drawColorSwatch(Widgets.debugColorDefault(key))
  ui.sameLine(layout.originX + layout.normalX)
  local normal = Widgets.debugColorNormal(key)
  drawColorButton('##normal_color_' .. key, normal, ui.ColorPickerFlags.AlphaPreview)
  Widgets.settingTooltip('normalColor', normal)
  ui.itemPopup('##normal_color_popup_' .. key, ui.MouseButton.Left, function()
    Widgets.text(tr('Choose %s', label:lower()))
    ui.colorPicker('##normal_color_picker_' .. key, normal, bit.bor(
      ui.ColorPickerFlags.AlphaBar,
      ui.ColorPickerFlags.AlphaPreview,
      ui.ColorPickerFlags.PickerHueWheel
    ))
  end)
  ui.sameLine(layout.originX + layout.normalResetX)
  ui.pushID('normalReset_' .. key)
  if ui.iconButton(ui.Icons.Reset, vec2(resetWidth, resetWidth), rgbm(1, 1, 1, 1), rgbm(0, 0, 0, 0)) then
    Widgets.resetNormalColor(key)
  end
  ui.popID()
  Widgets.settingTooltip('normalColorReset', normal)
  ui.sameLine(layout.originX + layout.normalDefaultX)
  drawColorSwatch(debugColorNormalDefault(key))
end

local function drawToolsTabHeader()
  if sliders.checkbox(tr('Debug mode (general)'), settings.debugEnabled, sliders.defaults.debugEnabled, 'debugEnabled', ui.Icons.Bug) then
	settings.debugEnabled = not settings.debugEnabled
  end
end

local function drawToolsTab()
  drawLanguageSelector('##toolsLanguage')
  ui.separator()
  ui.header(tr('Reset Settings'))
  if ui.button(tr('Reset all settings to defaults'), vec2(-0.1, 0)) then
	settings.backupName = 'Default'
	resetSettings()
  end
  if ui.button(tr('Reset audio settings'), vec2(-0.1, 0)) then
	resetAudioSettings()
  end
  if ui.button(tr('Reset alert appearance'), vec2(-0.1, 0)) then
	resetAlertAppearanceSettings()
  end
  if ui.button(tr('Reset keyword settings'), vec2(-0.1, 0)) then
	resetKeywordSettings()
  end

  ui.separator()
  local iconSize = 128
  local totalIconsWidth = iconSize * 2 + 16  -- 2 icons + spacing
  local iconOffset = (ui.availableSpaceX() - totalIconsWidth) / 2
  ui.beginGroup()
  Widgets.text(tr('Debug'))
  local cspVersion = ac.getPatchVersion and ac.getPatchVersion() or 'unknown'
  Widgets.text(tr('App version: %s', App.versionLabel))
  Widgets.text(tr('CSP Version: %s', tostring(cspVersion)))
  local uiScale = ac.getUI() and ac.getUI().uiScale or 'unknown'
  Widgets.text(tr('UI Scale: %s', tostring(uiScale)))
  ui.endGroup()
  ui.sameLine(iconOffset)
  -- Main app icon
  ui.image('icons/icon.png', vec2(iconSize, iconSize))
  ui.sameLine()
  -- Config window icon
  ui.image('icons/config-icon.png', vec2(iconSize, iconSize))
  ui.separator()

  -- Update vehicle/server cache only every 2 seconds (not every frame)
  local currentTime = ui.time()
  if currentTime - debugInfoCache.lastUpdateTime >= debugInfoCache.updateInterval then
	debugInfoCache.vehicleName = ac.getCarName(0) or ac.getCarID(0) or tr('No car')
	debugInfoCache.serverName = ac.getServerName() or tr('Offline')
	debugInfoCache.lastUpdateTime = currentTime
  end

  Widgets.text(tr('Current vehicle: %s', debugInfoCache.vehicleName))
  Widgets.text(tr('Server: %s', debugInfoCache.serverName))
  local debugOff = not settings.debugEnabled
  ui.indent(22)
  if debugOff then ui.pushDisabled() end
  if sliders.checkbox(tr('Trace logs'), settings.debugTraceEnabled, sliders.defaults.debugTraceEnabled, 'debugTraceEnabled') then
    settings.debugTraceEnabled = not settings.debugTraceEnabled
  end
  if ui.button(tr('Print debug to log'), vec2(-0.1, 0)) then
   Debug.info(App.displayName .. ' Debug Info:')
   Debug.info('  App version: ' .. App.versionLabel)
   Debug.info('  CSP Version: ' .. tostring(cspVersion))
   Debug.info('  UI Scale: ' .. tostring(uiScale))
   Debug.info('  Vehicle: ' .. debugInfoCache.vehicleName)
   Debug.info('  Server: ' .. debugInfoCache.serverName)
   Debug.info('  Test mode: ' .. tostring(Alert.testMode))
  end
  if debugOff then ui.popDisabled() end
  ui.unindent(22)
  ui.separator()
  local friends = friendList.get()
  if debugOff then ui.pushDisabled() end
  ui.treeNode(tr('Friends (%d connected)', #friends) .. '###friendsDebug', function()
    if #friends == 0 then
      Widgets.textDisabled(tr('No tagged friend connected. Names are not saved; the list shows only the current online race.'))
    end
    for _, name in ipairs(friends) do
      Widgets.text(name)
    end
  end)
  if debugOff then ui.popDisabled() end
  ui.separator()
  ui.treeNode(tr('Alert history (%d of %d)', #alertHistory.items, alertHistory.max) .. '###alertHistoryDebug', function()
	alertHistory.drawEntries(3)
  end)
  if debugOff then ui.pushDisabled() end
  if ui.button(tr('Print alert history to log'), vec2(-0.1, 0)) then
	Debug.info(App.displayName .. ' History (' .. #alertHistory.items .. ' entries):')
	for _, entry in ipairs(alertHistory.items) do
	  Debug.info(alertHistory.formatEntry(entry))
	end
  end
  if debugOff then ui.popDisabled() end
  if ui.button(tr('Clear alert history'), vec2(-0.1, 0)) then
	alertHistory.clear()
  end
  ui.separator()
  if debugOff then ui.pushDisabled() end
  ui.indent(22)
  Widgets.text(tr('Simulate a chat message (offline testing). Use a keyword or your name to trigger an alert.'))
  Debug.simulator.author = ui.inputText('##simulatedAuthor', Debug.simulator.author)
  Debug.simulator.text = ui.inputText('##simulatedText', Debug.simulator.text)
  if sliders.checkbox(tr('Simulated sender is a friend'), Debug.simulator.friend, sliders.defaults.simulatorFriend, 'simulatorFriend') then
	Debug.simulator.friend = not Debug.simulator.friend
  end
  if ui.button(tr('Simulate chat message'), vec2(-0.1, 0)) then
	handleChatMessage(Debug.simulator.text, nil, Debug.simulator.author ~= '' and Debug.simulator.author or 'Simulated driver', Debug.simulator.friend)
  end
  ui.separator()
  ui.unindent(22)
  if debugOff then ui.popDisabled() end
  ui.separator()
  if debugOff then ui.pushDisabled() end
  ui.indent(22)
  if sliders.checkbox(tr('Diagnostic colors'), settings.debugModeEnabled, sliders.defaults.debugModeEnabled, 'debugModeEnabled') then
    settings.debugModeEnabled = not settings.debugModeEnabled
  end
  if settings.debugModeEnabled then
    local layout = debugColorLayout(ui.getCursorX())
    drawDebugColorHeader(layout)
    for _, row in ipairs(debugColorRows) do drawDebugColorSetting(tr(row[1]), row[2], layout) end
    ui.separator()
    debugColors.buttonOverflow = sliders.withDefault(tr('Color button overflow'), debugColors.buttonOverflow, 0, 20, '%.1f%%', sliders.defaults.buttonOverflow, 0.1, 'buttonOverflow')
  end
  ui.unindent(22)
  if debugOff then ui.popDisabled() end
  saveDebugColors()
end

ToolsTab.drawToolsTab = drawToolsTab
ToolsTab.drawToolsTabHeader = drawToolsTabHeader

return ToolsTab
