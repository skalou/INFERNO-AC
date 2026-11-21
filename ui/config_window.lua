-- Settings window (manifest window "config").
local modules = require('core.modules')
local ConfigWindow = modules.configWindow

local settings = modules.settings.settings
local alertHistory = modules.history.alertHistory
local refreshAlertSoundFiles = modules.sounds.refreshAlertSoundFiles
local debugColor = modules.widgets.debugColor
local pushSettingsTheme = modules.widgets.pushSettingsTheme
local syncVehicleDisplayProfile = modules.profiles.syncVehicleDisplayProfile
local syncKeywordProfile = modules.profiles.syncKeywordProfile
local refreshBackupList = modules.backup.refreshBackupList
local refreshSharedKeywordFiles = modules.sharing.refreshSharedKeywordFiles
local drawAlertsTab = modules.alertsTab.drawAlertsTab
local drawDisplayTab = modules.displayTab.drawDisplayTab
local drawProfilesTab = modules.profilesTab.drawProfilesTab
local drawToolsTab = modules.toolsTab.drawToolsTab
local drawTipsTab = modules.tipsTab.drawTipsTab
local drawTitleMarker = modules.widgets.drawTitleMarker

local configGripSize = 14
local debugBannerColor = rgbm(1, 0.85, 0.2, 1)
local debugBannerHeight = 72
local debugBannerIconSize = 56
local debugBannerPadding = 12

-- Shown at the top of every tab while the general Debug mode is on.
local function drawDebugBanner()
  local origin = ui.getCursor()
  local left, top = ui.getCursorX(), ui.getCursorY()
  local width = ui.availableSpaceX()
  local iconSize = vec2(debugBannerIconSize, debugBannerIconSize)
  local textStart = origin + vec2(debugBannerPadding * 2 + debugBannerIconSize, 0)
  local textEnd = origin + vec2(width - debugBannerPadding, debugBannerHeight)
  ui.drawRectFilled(origin, origin + vec2(width, debugBannerHeight), rgbm(debugBannerColor.r, debugBannerColor.g, debugBannerColor.b, 0.12), 0)
  ui.drawRect(origin, origin + vec2(width, debugBannerHeight), debugBannerColor, 0, ui.CornerFlags.All, 3)
  ui.setCursorX(left + debugBannerPadding)
  ui.setCursorY(top + (debugBannerHeight - debugBannerIconSize) / 2)
  ui.icon(ui.Icons.Bug, iconSize, debugBannerColor)
  ui.pushDWriteFont('@System')
  ui.dwriteDrawTextClipped('DEBUG', 36, textStart, textEnd, ui.Alignment.Start, ui.Alignment.Center, false, debugBannerColor)
  ui.popDWriteFont()
  ui.setCursorX(left)
  ui.setCursorY(top)
  ui.dummy(vec2(width, debugBannerHeight + debugBannerPadding))
end

local function tabContent(childId, drawContent)
  return function()
	-- The banner sits outside the child, so it stays visible while the tab content scrolls.
	if settings.debugEnabled then drawDebugBanner() end
	local contentSize = ui.availableSpace()
	if ui.beginChild(childId, contentSize, false, ui.WindowFlags.AlwaysVerticalScrollbar) then
	  drawContent()
	  ui.endChild()
	end
  end
end

local tabAlerts = { 'Alerts', tabContent('AlertsContent', drawAlertsTab) }
local tabDisplay = { 'Display', tabContent('DisplayContent', drawDisplayTab) }
local tabProfiles = { 'Profiles', tabContent('ProfilesContent', drawProfilesTab) }
local tabHistory = { 'History', tabContent('HistoryContent', function() alertHistory.drawTab() end) }
local tabTools = { 'Tools', tabContent('ToolsContent', drawToolsTab) }
local tabTips = { 'Tips', tabContent('TipsContent', drawTipsTab) }

-- ImGui keeps a tab bar's order from its first frame, so each order uses its own bar ID.
local tabsTipsFirst = { tabTips, tabAlerts, tabDisplay, tabProfiles, tabHistory, tabTools }
local tabsTipsLast = { tabAlerts, tabDisplay, tabProfiles, tabHistory, tabTools, tabTips }
local tipsWasUnderstood = settings.tipsUnderstood

local function windowConfig()
  drawTitleMarker()
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
  local bandColor = debugColor('background')
  ui.drawRectFilled(vec2(0, backgroundTop), vec2(windowSize.x, windowSize.y - configGripSize), bandColor)

  local understood = settings.tipsUnderstood
  local tabs = understood and tabsTipsLast or tabsTipsFirst
  local barId = understood and 'configTabsTipsLast' or 'configTabsTipsFirst'
  -- Select Tips once, on the frame the checkbox changes, so the window stays on it.
  local selectTips = understood ~= tipsWasUnderstood
  tipsWasUnderstood = understood

  ui.tabBar(barId, bit.bor(ui.TabBarFlags.IntegratedTabs, ui.TabBarFlags.FittingPolicyScroll, ui.TabBarFlags.TabListPopupButton), function()
	for _, tab in ipairs(tabs) do
	  local flags = (selectTips and tab == tabTips) and ui.TabItemFlags.SetSelected or ui.TabItemFlags.None
	  -- The text after '###' is the tab ID: it does not change with the language, so the selected tab is kept.
	  ui.tabItem(modules.i18n.tr(tab[1]) .. '###' .. tab[1], flags, tab[2])
	end
  end)

  ui.popStyleColor(16)
end

ConfigWindow.windowConfig = windowConfig

return ConfigWindow
