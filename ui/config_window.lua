-- Settings window (manifest window "config").
local modules = require('core.modules')
local ConfigWindow = modules.configWindow

local settings = modules.settings.settings
local alertHistory = modules.history.alertHistory
local refreshAlertSoundFiles = modules.sounds.refreshAlertSoundFiles
local debugColors = modules.widgets.debugColors
local pushSettingsTheme = modules.widgets.pushSettingsTheme
local syncVehicleDisplayProfile = modules.profiles.syncVehicleDisplayProfile
local syncKeywordProfile = modules.profiles.syncKeywordProfile
local refreshBackupList = modules.backup.refreshBackupList
local refreshSharedKeywordFiles = modules.sharing.refreshSharedKeywordFiles
local drawAlertsTab = modules.alertsTab.drawAlertsTab
local drawDisplayTab = modules.displayTab.drawDisplayTab
local drawProfilesTab = modules.profilesTab.drawProfilesTab
local drawToolsTab = modules.toolsTab.drawToolsTab

local configGripSize = 14

local function windowConfig()
  syncVehicleDisplayProfile()
  syncKeywordProfile()
  if ui.isWindowAppearing() then
	refreshAlertSoundFiles()
	refreshBackupList()
	refreshSharedKeywordFiles()
  end

  -- Force window to stay visible (not fade)
  ac.forceFadingIn()

  pushSettingsTheme()

  -- Lighter background below the title bar, drawn over ImGui's native window background.
  -- The native background is drawn before this callback, so the resize grip is redrawn on top to stay visible.
  local windowSize = ui.windowSize()
  local backgroundTop = ui.cursorStartPos().y - 10
  local bandColor = settings.debugModeEnabled and debugColors.background or rgbm(0.14, 0.14, 0.14, 0.96)
  ui.drawRectFilled(vec2(0, backgroundTop), vec2(windowSize.x, windowSize.y - configGripSize), bandColor)

  ui.tabBar('configTabs', bit.bor(ui.TabBarFlags.IntegratedTabs, ui.TabBarFlags.FittingPolicyScroll, ui.TabBarFlags.TabListPopupButton), function()
	ui.tabItem('Alerts', function()
	  -- Scrollable content area for this tab only
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('AlertsContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		drawAlertsTab()
		ui.endChild()
	  end
	end)
	ui.tabItem('Display', function()
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('DisplayContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		drawDisplayTab()
		ui.endChild()
	  end
	end)
	ui.tabItem('Profiles', function()
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('ProfilesContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		drawProfilesTab()
		ui.endChild()
	  end
	end)
	ui.tabItem('History', function()
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('HistoryContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		alertHistory.drawTab()
		ui.endChild()
	  end
	end)
	ui.tabItem('Tools', function()
	  local contentSize = ui.availableSpace()
	  if ui.beginChild('ToolsContent', contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
		drawToolsTab()
		ui.endChild()
	  end
	end)
  end)

  ui.popStyleColor(19)
end

ConfigWindow.windowConfig = windowConfig

return ConfigWindow
