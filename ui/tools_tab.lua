-- Settings window, Tools tab: resets, debug info, friends, simulator, debug colours.
local modules = require('core.modules')
local Alert = modules.alert
local ToolsTab = modules.toolsTab

local App = modules.paths.App
local settings = modules.settings.settings
local Debug = modules.debug.Debug
local alertHistory = modules.history.alertHistory
local sliders = modules.widgets.sliders
local debugColors = modules.widgets.debugColors
local saveDebugColors = modules.widgets.saveDebugColors
local drawColorButton = modules.widgets.drawColorButton
local drawColorSetting = modules.widgets.drawColorSetting
local drawThemeColorSetting = modules.widgets.drawThemeColorSetting
local friendList = modules.friends.friendList
local resetAudioSettings = modules.backup.resetAudioSettings
local resetAlertAppearanceSettings = modules.backup.resetAlertAppearanceSettings
local resetKeywordSettings = modules.backup.resetKeywordSettings
local resetSettings = modules.backup.resetSettings
local handleChatMessage = modules.chat.handleChatMessage

local function drawDebugColorSetting(label, key)
  ui.text(label)
  ui.sameLine()
  drawColorButton('##debug_color_' .. key, debugColors[key], ui.ColorPickerFlags.AlphaPreview)
  ui.itemPopup('##debug_color_popup_' .. key, ui.MouseButton.Left, function()
    ui.text('Choose ' .. label:lower())
    ui.colorPicker('##debug_color_picker_' .. key, debugColors[key], bit.bor(
      ui.ColorPickerFlags.AlphaBar,
      ui.ColorPickerFlags.AlphaPreview,
      ui.ColorPickerFlags.PickerHueWheel
    ))
  end)
end

local function drawToolsTab()
  ui.header('Reset Settings')
  if ui.button('Reset all settings to defaults', vec2(-0.1, 0)) then
	settings.backupName = 'Default'
	resetSettings()
  end
  if ui.button('Reset audio settings', vec2(-0.1, 0)) then
	resetAudioSettings()
  end
  if ui.button('Reset alert appearance', vec2(-0.1, 0)) then
	resetAlertAppearanceSettings()
  end
  if ui.button('Reset keyword settings', vec2(-0.1, 0)) then
	resetKeywordSettings()
  end

  ui.separator()
  ui.header('Debug')
  local cspVersion = ac.getPatchVersionCode and ac.getPatchVersionCode() or 'unknown'
  ui.text('App version: ' .. App.versionLabel)
  ui.text('CSP Version: ' .. tostring(cspVersion))
  local uiScale = ac.getUI() and ac.getUI().uiScale or 'unknown'
  ui.text('UI Scale: ' .. tostring(uiScale))
  local vehicleName = ac.getCarName(0) or ac.getCarID(0) or 'No car'
  ui.text('Current vehicle: ' .. vehicleName)
  local serverName = ac.getServerName() or 'Offline'
  ui.text('Server: ' .. serverName)
  if ui.button('Print debug to log', vec2(-0.1, 0)) then
	Debug.info(App.displayName .. ' Debug Info:')
	Debug.info('  App version: ' .. App.versionLabel)
	Debug.info('  CSP Version: ' .. tostring(cspVersion))
	Debug.info('  UI Scale: ' .. tostring(uiScale))
	Debug.info('  Vehicle: ' .. vehicleName)
	Debug.info('  Server: ' .. serverName)
	Debug.info('  Test mode: ' .. tostring(Alert.testMode))
  end
  ui.separator()
  local friends = friendList.get()
  ui.treeNode('Friends (' .. #friendList.known .. ' saved, ' .. #friends .. ' connected)###friendsDebug', function()
    if #friendList.known == 0 then
      ui.textDisabled('No friends saved yet. A tagged friend is saved when seen in an online race.')
    end
    for _, name in ipairs(friendList.known) do
      if friendList.isFriend(name) then
        ui.text(name .. '  (connected)')
      else
        ui.textDisabled(name)
      end
    end
    ui.pushID('openFriendsFolder')
    if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
      if friendList.ensureFolder() then
        os.openInExplorer(friendList.folder)
      else
        friendList.status = 'Could not create the friends folder.'
      end
    end
    ui.popID()
    ui.sameLine()
    if ui.button('Reset friends list') then friendList.reset() end
    if friendList.status ~= '' then ui.textWrapped(friendList.status) end
    ui.textDisabled('File: ' .. friendList.file)
  end)
  ui.separator()
  ui.treeNode('Alert history (' .. #alertHistory.items .. ' of ' .. alertHistory.max .. ')###alertHistoryDebug', function()
	alertHistory.drawEntries()
  end)
  if ui.button('Print alert history to log', vec2(-0.1, 0)) then
	Debug.info(App.displayName .. ' History (' .. #alertHistory.items .. ' entries):')
	for _, entry in ipairs(alertHistory.items) do
	  Debug.info(alertHistory.formatEntry(entry))
	end
  end
  if ui.button('Clear alert history', vec2(-0.1, 0)) then
	alertHistory.clear()
  end
  ui.separator()
  ui.text('Simulate a chat message (offline testing). Use a keyword or your name to trigger an alert.')
  Debug.simulator.author = ui.inputText('##simulatedAuthor', Debug.simulator.author)
  Debug.simulator.text = ui.inputText('##simulatedText', Debug.simulator.text)
  if sliders.checkbox('Simulated sender is a friend', Debug.simulator.friend, sliders.defaults.simulatorFriend) then
	Debug.simulator.friend = not Debug.simulator.friend
  end
  if ui.button('Simulate chat message', vec2(-0.1, 0)) then
	handleChatMessage(Debug.simulator.text, nil, Debug.simulator.author ~= '' and Debug.simulator.author or 'Simulated driver', Debug.simulator.friend)
  end
  ui.separator()
  ui.text('Debug colors')
  if sliders.checkbox('Debug mode (diagnostic colors)', settings.debugModeEnabled, sliders.defaults.debugModeEnabled) then
    settings.debugModeEnabled = not settings.debugModeEnabled
  end
  if settings.debugModeEnabled then
    drawColorSetting('Player color', 'playerColor')
    drawColorSetting('Friend color', 'friendColor')
    drawThemeColorSetting('Settings theme color 1', 'themeColor')
    drawThemeColorSetting('Settings theme color 2 (background)', 'themeBgColor')
    drawDebugColorSetting('Background rectangle', 'background')
    drawDebugColorSetting('Child background', 'childBg')
    drawDebugColorSetting('Scrollbar background', 'scrollbarBg')
    drawDebugColorSetting('Resize grip', 'resizeGrip')
    drawDebugColorSetting('Used sound (already in an alert)', 'usedSound')
    drawDebugColorSetting('Selected sound (this alert)', 'selectedSound')
  end
  debugColors.buttonOverflow = sliders.withDefault('Color button overflow', debugColors.buttonOverflow, 0, 20, '%.1f%%', sliders.defaults.buttonOverflow, 0.1)
  saveDebugColors()
end

ToolsTab.drawToolsTab = drawToolsTab

return ToolsTab
