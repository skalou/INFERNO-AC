-- Persistent settings (ac.storage).
local modules = require('core.modules')
local Store = modules.settings

local defaultAlertSoundFile = modules.paths.defaultAlertSoundFile

local settings = ac.storage({

  keywords = 'ric,convoy,skalou',
  keywordRows = '',
  mentionMe = true,
  mentionSoundMuted = false,
  showAllChatMessages = false,
  textSize = 48,
  duration = 3.0,
  opacity = 75,
  soundEnabled = true,
  masterVolume = 100,
  mentionSound = defaultAlertSoundFile,
  friendSound = defaultAlertSoundFile,
  friendSoundMuted = false,
  keywordSoundAssignments = '',
  mutedKeywords = '',
  keywordOptions = '',
  savedSettings = '',
    recentSounds = '',
  backupName = 'isuchatalertversionv.2.8.1-5',
  settingsWindowHeightPercent = 75,
  settingsWindowPositionSaved = false,
  settingsWindowOffsetX = 0,
  settingsWindowOffsetY = 0,
  settingsWindowAbsoluteX = 0,
  settingsWindowAbsoluteY = 0,
  vehicleDisplayProfiles = '',
  keywordProfiles = '',
  keywordProfileFallback = '',
  useVehicleDisplayProfiles = false,
  useServerKeywordProfiles = false,
  autoSaveServerSettings = false,
  hideWhenNotHovered = false,
  backgroundEnabled = false,
  debugModeEnabled = true,
  debugColorsData = '',
  outlineThicknessPercent = 8,
  softOutline = false,
	themeColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1),
		themeBgColor = rgbm(97 / 255, 138 / 255, 81 / 255, 1),
  textColor = rgbm(1, 102 / 255, 134 / 255, 242 / 255),
  authorColor = rgbm(1, 190 / 255, 80 / 255, 1),
  playerColor = rgbm(0.3, 1, 0.3, 1),
  friendColor = rgbm(0, 0.8, 1, 1),
  outlineColor = rgbm(20 / 255, 20 / 255, 20 / 255, 1),
  backgroundColor = rgbm(26 / 255, 26 / 255, 26 / 255, 1),
  accentColor = rgbm(97 / 255, 138 / 255, 81 / 255, 198 / 255)
-- Old key prefix kept so migrated settings still load.
}, 'IsuChatAlertLua_')
local maxOutlineScale = 3

Store.settings = settings
Store.maxOutlineScale = maxOutlineScale

return Store
