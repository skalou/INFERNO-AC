-- App identity, folders, version constants, and one-time migration of data from the old app names.
local modules = require('core.modules')
local Paths = modules.paths

-- INFERNO-Chat Alerts - Assetto Corsa chat alert app (CSP Lua)
-- ============================================================
-- Shows a popup and plays a sound when a chat message matches a keyword,
-- mentions the player or comes from a friend.
-- Features: per-server and per-car profiles, settings backups, shared
-- keyword lists, a sound queue for hidden alerts, friends list.
-- See README.md and README_AI_NOTES.md for development notes.

local defaultAlertSoundFile = '00defaultALERT.wav'

local App = {
  folderName = 'INFERNO-ChatAlerts',
  displayName = 'INFERNO-Chat Alerts',
  migrateFrom = { 'isuChatAlertLua' },
}
App.stateFolder = ac.getFolder(ac.FolderID.ExtCfgState) .. '\\lua\\app\\' .. App.folderName

-- Settings and data used to live under the old folder names. Copy them once, only into empty locations.
do
  local function migrateAppData()
    local stateRoot = ac.getFolder(ac.FolderID.ExtCfgState) .. '\\lua\\app\\'
    local ownStorageFile = App.stateFolder .. '.ini'
    for _, oldName in ipairs(App.migrateFrom) do
      if oldName ~= App.folderName then
        local oldStorageFile = stateRoot .. oldName .. '.ini'
        if not io.fileExists(ownStorageFile) and io.fileExists(oldStorageFile) then
          io.copyFile(oldStorageFile, ownStorageFile, true)
          ac.log('INFERNO: settings migrated from ' .. oldName)
        end
        local oldStateFolder = stateRoot .. oldName
        if io.dirExists(oldStateFolder) then
          io.createDir(App.stateFolder)
          for _, sub in ipairs({ 'Saves', 'SharedKeywords', 'Friends' }) do
            local src, dst = oldStateFolder .. '\\' .. sub, App.stateFolder .. '\\' .. sub
            if io.dirExists(src) and not io.dirExists(dst) then
              io.createDir(dst)
              for _, fileName in ipairs(io.scanDir(src, '*')) do
                io.copyFile(src .. '\\' .. fileName, dst .. '\\' .. fileName, true)
              end
            end
          end
        end
      end
    end
  end
  migrateAppData()
end
local backupFolder = App.stateFolder .. '\\Saves'
local sharedKeywordFolder = App.stateFolder .. '\\SharedKeywords'
local appFolder = ac.getFolder(ac.FolderID.ACApps) .. '\\lua\\' .. App.folderName
local soundFolder = appFolder .. '\\sounds'
local serverKeywordFolder = appFolder .. '\\ServerSharedKeywords'
local appVersion = '2.8.2'
local backupFormatVersion = 1
-- Format id is part of shared files, so it stays unchanged for compatibility.
local sharedKeywordFormat = 'IsuChatAlertServerKeywords'
local sharedKeywordFormatVersion = 1
local maximumBackupSize = 5 * 1024 * 1024

Paths.defaultAlertSoundFile = defaultAlertSoundFile
Paths.App = App
Paths.backupFolder = backupFolder
Paths.sharedKeywordFolder = sharedKeywordFolder
Paths.soundFolder = soundFolder
Paths.serverKeywordFolder = serverKeywordFolder
Paths.appVersion = appVersion
Paths.backupFormatVersion = backupFormatVersion
Paths.sharedKeywordFormat = sharedKeywordFormat
Paths.sharedKeywordFormatVersion = sharedKeywordFormatVersion
Paths.maximumBackupSize = maximumBackupSize

return Paths
