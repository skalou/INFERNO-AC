-- Persistent settings (ac.storage).
local modules = require('core.modules')
local Store = modules.settings

-- Keyword list of a new install and of keyword resets: no keyword. The built-in "your name" and "friends"
-- entries are added by parseKeywords(). Format: 'v1:' followed by '=<encoded keyword>' entries separated by ';'.
local defaultKeywordRows = 'v1:'

-- Default colours, also used by the right-click reset of the colour pickers.
local colorDefaults = {
  themeColor = rgbm(0.61415600776672, 0.051795560866594, 0.046533223241568, 1),
  themeBgColor = rgbm(1, 0.99995344877243, 0.99989998340607, 1),
  textColor = rgbm(1, 102 / 255, 134 / 255, 242 / 255),
  authorColor = rgbm(1, 190 / 255, 80 / 255, 1),
  playerColor = rgbm(0.3, 1, 0.3, 1),
  friendColor = rgbm(0, 0.8, 1, 1),
  outlineColor = rgbm(20 / 255, 20 / 255, 20 / 255, 1),
  backgroundColor = rgbm(26 / 255, 26 / 255, 26 / 255, 1),
  accentColor = rgbm(0.76470404863358, 0.17448054254055, 0, 0.77647060155869)
}

local settings = ac.storage({
  keywordRows = defaultKeywordRows,
  mentionMe = true,
  mentionSoundMuted = false,
  alertFriendMessage = true,
  showAllChatMessages = false,
  textSize = 20,
  duration = 3.0,
  opacity = 75,
  soundEnabled = true,
  masterVolume = 100,
  mentionSound = 'AlertShort - Plouing.mp3',
  friendSound = 'AlertShort - Tudum.mp3',
  friendSoundMuted = false,
  keywordSoundAssignments = '',
  mutedKeywords = '',
  keywordOptions = '',
  recentSounds = '',
  backupName = 'My settings',
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
  tipsUnderstood = false,
  language = 'auto',
  backgroundEnabled = false,
  debugEnabled = false,
  debugTraceEnabled = false,
  debugModeEnabled = false,
  debugColorsData = '',
  normalColorsData = '',
  outlineThicknessPercent = 5.2631556987762,
  softOutline = true,
  themeColor = colorDefaults.themeColor:clone(),
  themeBgColor = colorDefaults.themeBgColor:clone(),
  textColor = colorDefaults.textColor:clone(),
  authorColor = colorDefaults.authorColor:clone(),
  playerColor = colorDefaults.playerColor:clone(),
  friendColor = colorDefaults.friendColor:clone(),
  outlineColor = colorDefaults.outlineColor:clone(),
  backgroundColor = colorDefaults.backgroundColor:clone(),
  accentColor = colorDefaults.accentColor:clone()
}, 'INFERNO_')
local maxOutlineScale = 3

Store.settings = settings
Store.colorDefaults = colorDefaults
Store.maxOutlineScale = maxOutlineScale
Store.defaultKeywordRows = defaultKeywordRows

return Store
