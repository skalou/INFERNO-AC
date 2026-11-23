-- App identity, folders, version, and file formats.
local modules = require('core.modules')
local Paths = modules.paths

local defaultAlertSoundFile = '00defaultALERT.wav'

local App = {
  folderName = 'INFERNO-ChatAlerts',
  displayName = 'INFERNO-Chat Alerts',
  version = '0.5.0',
  channel = 'beta',
}
App.versionLabel = App.version .. '-' .. App.channel
App.stateFolder = ac.getFolder(ac.FolderID.ExtCfgState) .. '\\lua\\app\\' .. App.folderName
local backupFolder = App.stateFolder .. '\\Saves'
local sharedKeywordFolder = App.stateFolder .. '\\SharedKeywords'
local appFolder = ac.getFolder(ac.FolderID.ACApps) .. '\\lua\\' .. App.folderName
local soundFolder = appFolder .. '\\sounds'
local serverKeywordFolder = appFolder .. '\\ServerSharedKeywords'
local appVersion = App.version
-- A settings backup or shared keyword file is read only if its format id and format version match exactly.
-- Files written by IsuChat Alert (2.x) or by older formats are rejected, never converted.
local backupFormat = 'INFERNO-Settings'
local backupFormatVersion = 2
local sharedKeywordFormat = 'INFERNO-KeywordList'
local sharedKeywordFormatVersion = 1
local maximumBackupSize = 5 * 1024 * 1024

Paths.defaultAlertSoundFile = defaultAlertSoundFile
Paths.App = App
Paths.backupFolder = backupFolder
Paths.sharedKeywordFolder = sharedKeywordFolder
Paths.soundFolder = soundFolder
Paths.serverKeywordFolder = serverKeywordFolder
Paths.appVersion = appVersion
Paths.backupFormat = backupFormat
Paths.backupFormatVersion = backupFormatVersion
Paths.sharedKeywordFormat = sharedKeywordFormat
Paths.sharedKeywordFormatVersion = sharedKeywordFormatVersion
Paths.maximumBackupSize = maximumBackupSize

return Paths
