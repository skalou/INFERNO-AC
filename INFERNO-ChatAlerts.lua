-- INFERNO-Chat Alerts - Assetto Corsa chat alert app (CSP Lua)
-- ============================================================
-- Shows a popup and plays a sound when a chat message matches a keyword,
-- mentions the player or comes from a friend.
-- Entry point: loads the modules in order (core/, ui/) and connects them to CSP.
-- See README.md and README_AI_NOTES.md for development notes.

local modules = require('core.modules')
require('core.paths')
require('core.settings')
require('core.debug')
require('core.i18n')
require('core.util')
require('core.alert')
require('core.history')
require('core.sounds')
require('ui.widgets')
require('ui.setting_help')
require('core.keywords')
require('core.friends')
require('core.windows')
require('core.profiles')
require('core.backup')
require('core.sharing')
require('core.chat')
require('ui.list_drag')
require('ui.alerts_tab')
require('ui.display_tab')
require('ui.profiles_tab')
require('ui.history_tab')
require('ui.tools_tab')
require('ui.tips_tab')
require('ui.config_window')
require('ui.alert_window')
local Alert = modules.alert

local settings = modules.settings.settings
local hiddenSoundQueue = modules.sounds.hiddenSoundQueue
local invalidateKeywordCaches = modules.keywords.invalidateKeywordCaches
local invalidatePlayerNameCache = modules.keywords.invalidatePlayerNameCache
local friendList = modules.friends.friendList
local persistLiveProfiles = modules.profiles.persistLiveProfiles
local getServerName = modules.backup.getServerName
local saveServerBackup = modules.backup.saveServerBackup
local loadServerBackup = modules.backup.loadServerBackup
local handleChatMessage = modules.chat.handleChatMessage

-- CSP passes a third argument (senderSessionID) that must not reach the simulator's simulatedAuthor parameter.
ac.onChatMessage(function(message, senderCarIndex)
  return handleChatMessage(message, senderCarIndex)
end)

local serverCheckElapsed = 0
local profilePersistElapsed = 0
local lastServerName = nil

function script.update(dt)
  dt = dt or 0
  hiddenSoundQueue.playNext()
  friendList.update(dt)
  profilePersistElapsed = profilePersistElapsed + dt
  if profilePersistElapsed >= 1 then
    profilePersistElapsed = 0
    persistLiveProfiles()
  end

  serverCheckElapsed = serverCheckElapsed + dt
  if serverCheckElapsed < 5 then return end
  serverCheckElapsed = 0

  local autoSave = settings.autoSaveServerSettings
  local currentServer = getServerName()
  if currentServer == lastServerName then
    if currentServer and autoSave then saveServerBackup(currentServer, true) end
    return
  end
  -- Live values still belong to the server being left, so save it before loading the next one.
  if lastServerName and autoSave then saveServerBackup(lastServerName, true) end
  lastServerName = currentServer
  if currentServer and autoSave then loadServerBackup(currentServer) end
end

function script.reset()
  invalidatePlayerNameCache()
  invalidateKeywordCaches()
  Alert.alertTimeLeft = 0
  Alert.measuredMessage = nil
end

-- Window callbacks named in manifest.ini (FUNCTION_MAIN).
windowMain = modules.alertWindow.windowMain
windowConfig = modules.configWindow.windowConfig
