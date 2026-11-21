-- Settings window, Profiles tab: car and server profiles, backups, keyword sharing.
local modules = require('core.modules')
local Profiles = modules.profiles
local Backup = modules.backup
local Sharing = modules.sharing
local ProfilesTab = modules.profilesTab
local tr = modules.i18n.tr

local backupFolder = modules.paths.backupFolder
local sharedKeywordFolder = modules.paths.sharedKeywordFolder
local serverKeywordFolder = modules.paths.serverKeywordFolder
local settings = modules.settings.settings
local comboWasOpen = modules.widgets.comboWasOpen
local Widgets = modules.widgets
local sliders = modules.widgets.sliders
local getVehicleProfileKey = modules.profiles.getVehicleProfileKey
local getKeywordProfileContext = modules.profiles.getKeywordProfileContext
local captureKeywordProfile = modules.profiles.captureKeywordProfile
local sanitizeProfileInfo = modules.profiles.sanitizeProfileInfo
local newProfileInfo = modules.profiles.newProfileInfo
local saveKeywordProfile = modules.profiles.saveKeywordProfile
local resetKeywordProfile = modules.profiles.resetKeywordProfile
local saveVehicleDisplayProfile = modules.profiles.saveVehicleDisplayProfile
local resetVehicleDisplayProfile = modules.profiles.resetVehicleDisplayProfile
local saveDisplayForAllCars = modules.profiles.saveDisplayForAllCars
local syncVehicleDisplayProfile = modules.profiles.syncVehicleDisplayProfile
local syncKeywordProfile = modules.profiles.syncKeywordProfile
local pendingOverwrite = modules.backup.pendingOverwrite
local normalizeBackupName = modules.backup.normalizeBackupName
local ensureBackupFolder = modules.backup.ensureBackupFolder
local refreshBackupList = modules.backup.refreshBackupList
local saveSettingsBackup = modules.backup.saveSettingsBackup
local loadSettingsBackup = modules.backup.loadSettingsBackup
local ensureSharedKeywordFolder = modules.sharing.ensureSharedKeywordFolder
local refreshSharedKeywordFiles = modules.sharing.refreshSharedKeywordFiles
local exportSharedKeywordProfile = modules.sharing.exportSharedKeywordProfile
local stageSharedKeywordImport = modules.sharing.stageSharedKeywordImport
local applyStagedSharedKeywordImport = modules.sharing.applyStagedSharedKeywordImport
local ensureServerKeywordFolder = modules.sharing.ensureServerKeywordFolder
local refreshServerKeywordSources = modules.sharing.refreshServerKeywordSources
local applyServerKeywordSource = modules.sharing.applyServerKeywordSource

local confirmOverwriteAllCars = false
local overwriteAllCarsConfirmed = false

local function drawVehicleDisplayProfiles()
  if sliders.checkbox(tr('Use separate display settings for each car'), settings.useVehicleDisplayProfiles, sliders.defaults.useVehicleDisplayProfiles, 'useVehicleDisplayProfiles') then
	settings.useVehicleDisplayProfiles = not settings.useVehicleDisplayProfiles
	syncVehicleDisplayProfile()
  end
  local vehicleKey = getVehicleProfileKey()
  local vehicleName = ac.getCarName(0) or ac.getCarID(0) or tr('No car detected')
  Widgets.text(tr('Current car: %s', vehicleName))
  if ui.button(tr('Save display for this car'), vec2(-0.1, 0)) then
	if saveVehicleDisplayProfile(vehicleKey) then
	  Profiles.profileStatus = tr('Display profile saved for %s.', vehicleName)
	else
	  Profiles.profileStatus = tr('A car must be loaded to save a vehicle profile.')
	end
  end
  if ui.button(tr('Reset display for this car'), vec2(-0.1, 0)) then
	if resetVehicleDisplayProfile(vehicleKey) then
	  Profiles.profileStatus = tr('Display reset to defaults for %s.', vehicleName)
	else
	  Profiles.profileStatus = tr('Display settings reset, but the chat window could not be repositioned.')
	end
  end
  if ui.button(tr('Save this display for all cars (overwrite)'), vec2(-0.1, 0)) then
	confirmOverwriteAllCars = true
	overwriteAllCarsConfirmed = false
  end
  if confirmOverwriteAllCars then
	Widgets.textWrapped(tr('This permanently overwrites every saved vehicle display profile. Save a backup first if you may want to restore them.'))
	if ui.checkbox(tr('I understand and want to overwrite all car profiles') .. '##overwriteAllCarsConfirmed', overwriteAllCarsConfirmed) then
	  overwriteAllCarsConfirmed = not overwriteAllCarsConfirmed
	end
	if overwriteAllCarsConfirmed and ui.button(tr('Confirm overwrite all car displays'), vec2(-0.1, 0)) then
	  if saveDisplayForAllCars() then
		Profiles.profileStatus = tr('Current display saved for all cars; existing profiles were overwritten.')
	  else
		Profiles.profileStatus = tr('Could not overwrite all car profiles because the chat window is unavailable.')
	  end
	  confirmOverwriteAllCars = false
	  overwriteAllCarsConfirmed = false
	end
	if ui.button(tr('Cancel overwrite'), vec2(-0.1, 0)) then
	  confirmOverwriteAllCars = false
	  overwriteAllCarsConfirmed = false
	end
  end
end

local function drawKeywordProfiles()
  ui.separator()
  if sliders.checkbox(tr('Use separate keyword settings per server'), settings.useServerKeywordProfiles, sliders.defaults.useServerKeywordProfiles, 'useServerKeywordProfiles') then
	if not settings.useServerKeywordProfiles then
	  settings.keywordProfileFallback = stringify(captureKeywordProfile(), true)
	end
	settings.useServerKeywordProfiles = not settings.useServerKeywordProfiles
	Profiles.keywordProfileContextInitialized = false
	syncKeywordProfile()
  end
  local profileKey, contextName = getKeywordProfileContext()
  Widgets.text(tr('Current context: %s', contextName or tr('No active session')))
  if profileKey then
	if ui.button(tr('Save keywords for this context'), vec2(-0.1, 0)) then
	  if saveKeywordProfile(profileKey) then
		Profiles.profileStatus = tr('Keyword profile saved for %s.', contextName)
	  else
		Profiles.profileStatus = tr('Could not save the keyword profile for this context.')
	  end
	end
	if ui.button(tr('Reset keywords for this context'), vec2(-0.1, 0)) then
	  if resetKeywordProfile(profileKey) then
		Profiles.profileStatus = tr('Keyword profile reset for %s.', contextName)
	  else
		Profiles.profileStatus = tr('Could not reset the keyword profile for this context.')
	  end
	end
  else
	Widgets.textDisabled(tr('Save and reset are available during an active server session.'))
  end
end

local sharedExportName = ''
local sharedExportNameKey = nil

local function defaultSharedExportName(profileKey)
  local info = sanitizeProfileInfo(Profiles.keywordProfiles[profileKey] and Profiles.keywordProfiles[profileKey].info) or newProfileInfo()
  local serverName = info.serverName ~= '' and info.serverName or profileKey:sub(8)
  local creator = info.createdBy ~= '' and info.createdBy or 'unknown player'
  return serverName .. ' - ' .. creator .. ' - ' .. os.date('%Y/%m/%d-%H:%M', info.createdAt)
end

local function drawSharedKeywordProfiles()
  ui.separator()
  Widgets.text(tr('Share server keyword profile'))
  local profileKey, contextName = getKeywordProfileContext()
  if profileKey then
	if sharedExportNameKey ~= profileKey then
	  sharedExportNameKey = profileKey
	  sharedExportName = defaultSharedExportName(profileKey)
	end
	Widgets.text(tr('Shared file name'))
	ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
	sharedExportName = ui.inputText('##sharedExportName', sharedExportName)
	if ui.button(tr('Export current profile for sharing'), vec2(-0.1, 0)) then
	  exportSharedKeywordProfile(profileKey, contextName, sharedExportName)
	end
	if pendingOverwrite.export and normalizeBackupName(sharedExportName):sub(1, 80) == pendingOverwrite.export then
	  if ui.button(tr('Confirm overwrite of this shared file'), vec2(-0.1, 0)) then
		exportSharedKeywordProfile(profileKey, contextName, sharedExportName)
	  end
	  if ui.button(tr('Cancel shared file overwrite'), vec2(-0.1, 0)) then pendingOverwrite.export = nil end
	end
	ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
	local selectedFileLabel = Sharing.selectedSharedKeywordFile ~= '' and Sharing.selectedSharedKeywordFile or tr('No shared files found')
	if ui.beginCombo('##sharedKeywordFiles', selectedFileLabel) then
	  if not comboWasOpen['##sharedKeywordFiles'] then
		refreshSharedKeywordFiles()
		comboWasOpen['##sharedKeywordFiles'] = true
	  end
	  for _, fileName in ipairs(Sharing.sharedKeywordFiles) do
		if ui.selectable(fileName, Sharing.selectedSharedKeywordFile == fileName) then
		  Sharing.selectedSharedKeywordFile = fileName
		  Sharing.pendingSharedKeywordImport = nil
		end
	  end
	  ui.endCombo()
	else
	  comboWasOpen['##sharedKeywordFiles'] = false
	end
	ui.sameLine()
	ui.pushID('openSharedKeywordFolder')
	if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
	  if ensureSharedKeywordFolder() then os.openInExplorer(sharedKeywordFolder) end
	end
	ui.popID()
	if ui.button(tr('Prepare import into this server'), vec2(-0.1, 0)) then
	  stageSharedKeywordImport(Sharing.selectedSharedKeywordFile, profileKey, contextName)
	end
	if Sharing.pendingSharedKeywordImport then
	  Widgets.textWrapped(tr('Import from "%s" into %s? This replaces this server-specific keyword profile.', Sharing.pendingSharedKeywordImport.serverLabel, Sharing.pendingSharedKeywordImport.targetLabel))
	  if ui.button(tr('Confirm import and replace server profile'), vec2(-0.1, 0)) then
		applyStagedSharedKeywordImport(profileKey)
	  end
	  if ui.button(tr('Cancel import'), vec2(-0.1, 0)) then Sharing.pendingSharedKeywordImport = nil end
	end
	Widgets.textDisabled(tr('Copy shared .json files into this folder. Import enables server-specific keyword profiles.'))
	Widgets.textDisabled(tr('Share folder: %s', sharedKeywordFolder))
  else
	Widgets.textDisabled(tr('Connect to a server to export or import its keyword profile.'))
  end
end

local function drawSettingsBackup()
  ui.separator()
  Widgets.text(tr('Backup name (used by Save)'))
  ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
  settings.backupName = ui.inputText('##backupName', settings.backupName)
  ui.sameLine()
  ui.pushID('openSettingsBackupFolder')
  if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
	if ensureBackupFolder() then
	  os.openInExplorer(backupFolder)
	else
	  Profiles.profileStatus = Backup.backupFolderStatus
	end
  end
  ui.popID()
  local selectedBackupName = normalizeBackupName(Backup.selectedBackupToLoad)
  local backupPreview = selectedBackupName ~= '' and selectedBackupName or tr('Select a backup')
  if selectedBackupName:lower() == 'default' then backupPreview = tr('Default (built-in)') end
  Widgets.text(tr('Selected backup (used by Load)'))
  if ui.beginCombo('##backupList', backupPreview) then
	if not comboWasOpen['##backupList'] then
	  refreshBackupList()
	  comboWasOpen['##backupList'] = true
	end
	for _, backupName in ipairs(Backup.availableBackups) do
	  local label = backupName == 'Default' and tr('Default (built-in)') or backupName
	  if ui.selectable(label, selectedBackupName:lower() == backupName:lower()) then
		Backup.selectedBackupToLoad = backupName
	  end
	end
	ui.endCombo()
  else
	comboWasOpen['##backupList'] = false
  end
  Widgets.textDisabled(tr('Your own settings backups folder: %s', backupFolder))
  if Backup.backupFolderStatus ~= '' then Widgets.textWrapped(tr('Backup status: %s', Backup.backupFolderStatus)) end
  if ui.button(tr('Save current settings'), vec2(-0.1, 0)) then
	saveSettingsBackup()
  end
  if pendingOverwrite.backup and normalizeBackupName(settings.backupName) == pendingOverwrite.backup then
	if ui.button(tr('Confirm overwrite of this backup'), vec2(-0.1, 0)) then
	  saveSettingsBackup()
	end
	if ui.button(tr('Cancel backup overwrite'), vec2(-0.1, 0)) then pendingOverwrite.backup = nil end
  end
  Widgets.textDisabled(tr('Will load: %s', backupPreview))
  if ui.button(tr('Load selected backup'), vec2(-0.1, 0)) then
	loadSettingsBackup()
  end
end

local function drawServerSourceCombo(comboId, kind, previewText, emptyText)
  ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
  if not ui.beginCombo(comboId, previewText) then
    comboWasOpen[comboId] = false
    return
  end
  if not comboWasOpen[comboId] then
    refreshServerKeywordSources()
    comboWasOpen[comboId] = true
  end
  local found = false
  for _, source in ipairs(Sharing.serverKeywordSources) do
    if source.kind == kind then
      found = true
      if ui.selectable(source.label, Sharing.selectedServerKeywordSource ~= nil and Sharing.selectedServerKeywordSource.id == source.id) then
        Sharing.selectedServerKeywordSource = source
      end
    end
  end
  if not found then Widgets.textDisabled(emptyText) end
  ui.endCombo()
end

local function drawServerSpecificSettings()
  ui.separator()
  if sliders.checkbox(tr('Auto-save settings for each server'), settings.autoSaveServerSettings, sliders.defaults.autoSaveServerSettings, 'autoSaveServerSettings') then
	settings.autoSaveServerSettings = not settings.autoSaveServerSettings
  end
  Widgets.textWrapped(tr('When enabled, your settings are automatically saved for each server you join and restored when you return.'))
  Widgets.text(tr('Keyword list from a saved server'))
  Widgets.textDisabled(tr('Saved by you (your server profiles)'))
  local selectedProfileLabel = Sharing.selectedServerKeywordSource and Sharing.selectedServerKeywordSource.kind == 'profile' and Sharing.selectedServerKeywordSource.label or tr('Select a list saved by you')
  drawServerSourceCombo('##serverProfileSources', 'profile', selectedProfileLabel, tr('No lists saved by you yet.'))
  Widgets.textDisabled(tr('Server shared keywords folder (mod install folder):'))
  Widgets.textDisabled(serverKeywordFolder)
  local selectedFileLabel = Sharing.selectedServerKeywordSource and Sharing.selectedServerKeywordSource.kind == 'file' and Sharing.selectedServerKeywordSource.label or tr('Select a list from this folder')
  drawServerSourceCombo('##serverFileSources', 'file', selectedFileLabel, tr('No lists in this folder yet.'))
  Widgets.textDisabled(tr('Manual lists: .json (share format) or .txt with one keyword per line.'))
  Widgets.text(tr('Selected list (read-only, pick another list above to replace it)'))
  ui.setNextItemWidth(math.max(40, ui.availableSpaceX() - 30))
  ui.inputText('##selectedServerKeywordSource', Sharing.selectedServerKeywordSource and Sharing.selectedServerKeywordSource.label or tr('(nothing selected)'), ui.InputTextFlags.ReadOnly)
  if Sharing.selectedServerKeywordSource then
	Widgets.textWrapped(tr('Apply "%s" to your current keyword list?', Sharing.selectedServerKeywordSource.label))
	if ui.button(tr('Add to the end of the current list'), vec2(-0.1, 0)) then
	  applyServerKeywordSource(Sharing.selectedServerKeywordSource, false)
	end
	if ui.button(tr('Replace the current list'), vec2(-0.1, 0)) then
	  applyServerKeywordSource(Sharing.selectedServerKeywordSource, true)
	end
  end
  ui.pushID('openServerKeywordFolder')
  if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
	if ensureSharedKeywordFolder() then
	  os.openInExplorer(sharedKeywordFolder)
	else
	  Profiles.profileStatus = tr('Could not access the shared keyword folder: %s', sharedKeywordFolder)
	end
  end
  ui.popID()
  ui.sameLine()
  Widgets.text(tr('Your saved keyword lists (created by you, exports)'))
  Widgets.textDisabled(sharedKeywordFolder)
  ui.pushID('openServerBackupFolder')
  if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
	if ensureServerKeywordFolder() then
	  os.openInExplorer(serverKeywordFolder)
	else
	  Profiles.profileStatus = tr('Could not access the server keyword folder: %s', serverKeywordFolder)
	end
  end
  ui.popID()
  ui.sameLine()
  Widgets.text(tr('Server keyword lists to share or import (manual files)'))
  Widgets.textDisabled(serverKeywordFolder)
  Widgets.textDisabled(tr('Automatic server backups are kept in the Servers subfolder, separate from your manual backups.'))
end

local function drawProfilesTab()
  ui.header(tr('My settings'))
  drawVehicleDisplayProfiles()
  drawSettingsBackup()
  ui.header(tr('Servers (auto)'))
  drawServerSpecificSettings()
  drawKeywordProfiles()
  ui.header(tr('Keyword sharing'))
  drawSharedKeywordProfiles()
  if Profiles.profileStatus ~= '' then 
	ui.separator()
	Widgets.textWrapped(tr('Status: %s', Profiles.profileStatus)) 
  end
end

ProfilesTab.drawProfilesTab = drawProfilesTab

return ProfilesTab
