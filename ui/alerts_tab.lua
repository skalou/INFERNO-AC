-- Settings window, Alerts tab: sound options and the keyword list.
local modules = require('core.modules')
local Sounds = modules.sounds
local Profiles = modules.profiles
local AlertsTab = modules.alertsTab

local defaultAlertSoundFile = modules.paths.defaultAlertSoundFile
local settings = modules.settings.settings
local playAlertSound = modules.sounds.playAlertSound
local isSoundTestPlaying = modules.sounds.isSoundTestPlaying
local sliders = modules.widgets.sliders
local soundPicker = modules.widgets.soundPicker
local drawSoundFolderButton = modules.widgets.drawSoundFolderButton
local specialAlertKeys = modules.keywords.specialAlertKeys
local lowerText = modules.keywords.lowerText
local saveKeywords = modules.keywords.saveKeywords
local parseKeywords = modules.keywords.parseKeywords
local loadKeywordSoundAssignments = modules.keywords.loadKeywordSoundAssignments
local saveKeywordSoundAssignments = modules.keywords.saveKeywordSoundAssignments
local loadMutedKeywords = modules.keywords.loadMutedKeywords
local saveMutedKeywords = modules.keywords.saveMutedKeywords
local keywordOptionStore = modules.keywords.keywordOptionStore
local captureKeywordProfile = modules.profiles.captureKeywordProfile
local saveKeywordProfile = modules.profiles.saveKeywordProfile

local draggingKeywordIndex = nil

local function drawAlertsTab()
  if sliders.checkbox('Play alert sound', settings.soundEnabled, sliders.defaults.soundEnabled) then
	settings.soundEnabled = not settings.soundEnabled
  end
  settings.masterVolume = sliders.withDefault('Master volume', settings.masterVolume, 0, 300, '%.0f%%', sliders.defaults.masterVolume, 1)
  drawSoundFolderButton()
  ui.textWrapped('Available sounds: .wav and .mp3 files in the sounds folder and its subfolders. If a selected file is missing or cannot be loaded, ' .. defaultAlertSoundFile .. ' is used instead.')
  if not Sounds.alertSoundFileSet[defaultAlertSoundFile] then
    ui.textWrapped('Warning: the default sound ' .. defaultAlertSoundFile .. ' is missing from the sounds folder. Alerts with a missing sound will be silent.')
  end
  ui.separator()
  if sliders.checkbox('Alert when my name is mentioned', settings.mentionMe, sliders.defaults.mentionMe) then
	settings.mentionMe = not settings.mentionMe
  end
  ui.separator()
  ui.header('Alert keywords (priority order)')
  ui.textWrapped('When several entries match, the first one in this list selects the sound. Drag the handle to reorder. The player mention and friend entries can be moved, muted or hidden, but not deleted.')
  local keywords = parseKeywords()
  local keywordSoundAssignments = loadKeywordSoundAssignments()
  local mutedKeywords = loadMutedKeywords()
  local keywordOptions = keywordOptionStore.load()
  local keywordRowCenters = {}
  local keywordSettingsChanged = false
  local removedKeywordIndex = nil
  local insertAfterIndex = nil
  if #keywords == 0 then
	ui.text('No alert keywords yet.')
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = 0
	end
  end
  for index, keyword in ipairs(keywords) do
	ui.pushID('keyword' .. index)
	local specialPrefix = keyword == specialAlertKeys.player and 'mention' or (keyword == specialAlertKeys.friend and 'friend') or nil
	local isSpecial = specialPrefix ~= nil
	local fieldText = specialAlertKeys.labels[keyword] or keyword
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = index - 1
	end
	ui.separator()
	local rowTop = ui.getCursorY()
	ui.iconButton(ui.Icons.Menu, vec2(22, 22))
	if not draggingKeywordIndex and ui.itemActive() and ui.mouseDown() then
	  draggingKeywordIndex = index
	end
	ui.sameLine()
	ui.text('#' .. index)
	ui.sameLine()
	if isSpecial then
	  ui.dummy(vec2(22, 22))
	elseif ui.iconButton(ui.Icons.Trash, vec2(22, 22)) then
	  removedKeywordIndex = index
	end
	ui.text(isSpecial and 'Built-in alert' or 'Keyword or trigger phrase')
	ui.sameLine()
	local keywordWidth = math.max(40, ui.availableSpaceX())
	local keywordContentWidth = math.max(keywordWidth, ui.measureText(fieldText).x + 24)
	ui.pushStyleVar(ui.StyleVar.WindowPadding, vec2(0, 0))
	ui.setNextWindowContentSize(vec2(keywordContentWidth, 0))
	local updatedKeyword = keyword
	if ui.beginChild('##keywordScroll', vec2(keywordWidth, 22), false, ui.WindowFlags.NoScrollbar) then
	  ui.setNextItemWidth(keywordContentWidth)
	  local keywordEmpty = keyword:match('^%s*$') ~= nil
	  if keywordEmpty then
		local themeBgColor = settings.themeBgColor
		local emptyFrameBg = rgbm(themeBgColor.r * 0.08, themeBgColor.g * 0.08, themeBgColor.b * 0.08, 0.96)
		ui.pushStyleColor(ui.StyleColor.FrameBg, emptyFrameBg)
		ui.pushStyleColor(ui.StyleColor.FrameBgHovered, emptyFrameBg)
		ui.pushStyleColor(ui.StyleColor.FrameBgActive, emptyFrameBg)
	  end
	  local typedKeyword = ui.inputText('##keywordValue', fieldText, isSpecial and ui.InputTextFlags.ReadOnly or 0)
	  if not isSpecial then updatedKeyword = typedKeyword end
	  if keywordEmpty then
		ui.popStyleColor(3)
	  end
	  local maxKeywordScroll = ui.getScrollMaxX()
	  if not ui.itemActive() then
		if maxKeywordScroll > 0 then
		  local speed = 35
		  local pause = 0.8
		  local travel = maxKeywordScroll / speed
		  local cycle = 2 * (pause + travel)
		  local elapsed = (ui.time() + index * 0.4) % cycle
		  local offset = 0
		  if elapsed > pause and elapsed <= pause + travel then
			offset = (elapsed - pause) * speed
		  elseif elapsed > pause + travel and elapsed <= 2 * pause + travel then
			offset = maxKeywordScroll
		  elseif elapsed > 2 * pause + travel then
			offset = maxKeywordScroll - (elapsed - 2 * pause - travel) * speed
		  end
		  ui.setScrollX(offset)
		else
		  ui.setScrollX(0)
		end
	  end
	end
	ui.endChild()
	ui.popStyleVar()
	local oldKey = lowerText(keyword:match('^%s*(.-)%s*$'))
	local newKey = lowerText(updatedKeyword:match('^%s*(.-)%s*$'))
	if updatedKeyword ~= keyword then
	  if oldKey ~= '' and newKey ~= '' and oldKey ~= newKey then
		if keywordSoundAssignments[oldKey] and not keywordSoundAssignments[newKey] then
		  keywordSoundAssignments[newKey] = keywordSoundAssignments[oldKey]
		end
		if mutedKeywords[oldKey] then mutedKeywords[newKey] = true end
		if keywordOptions[oldKey] and not keywordOptions[newKey] then keywordOptions[newKey] = keywordOptions[oldKey] end
	  end
	  keywords[index] = updatedKeyword
	  keywordSettingsChanged = true
	end
	ui.indent(22)
	local keywordKey = newKey
	local selectedSound
	if isSpecial then selectedSound = settings[specialPrefix .. 'Sound'] else selectedSound = keywordSoundAssignments[keywordKey] end
	local option = keywordOptionStore.get(keywordKey)
	local function setSelectedSound(value)
		  soundPicker.remember(value)
	  if isSpecial then
		settings[specialPrefix .. 'Sound'] = value
	  else
		keywordSoundAssignments[keywordKey] = value
	  end
	  keywordSettingsChanged = true
	end
	if keywordKey ~= '' then
	  if ui.iconButton(option.hidden and ui.Icons.Hide or ui.Icons.Eye, vec2(22, 22)) then
		keywordOptions[keywordKey] = { volume = option.volume, hidden = not option.hidden }
		keywordSettingsChanged = true
	  end
	else
	  ui.dummy(vec2(22, 22))
	end
	ui.sameLine()
	local soundMuted
	if isSpecial then
	  soundMuted = settings[specialPrefix .. 'SoundMuted']
	else
	  soundMuted = mutedKeywords[keywordKey]
	end
	if ui.iconButton(soundMuted and ui.Icons.Mute or ui.Icons.VolumeHigh, vec2(22, 22)) then
	  if isSpecial then
		settings[specialPrefix .. 'SoundMuted'] = not soundMuted
	  else
		mutedKeywords[keywordKey] = not soundMuted
	  end

	  keywordSettingsChanged = true
	end
	ui.sameLine()
	local keywordTestKey = specialPrefix or ('keyword:' .. keywordKey)
	if ui.iconButton(isSoundTestPlaying(keywordTestKey) and ui.Icons.Stop or ui.Icons.Play, vec2(22, 22)) then
	  playAlertSound(selectedSound or defaultAlertSoundFile, true, keywordTestKey, option.volume)
	end
	ui.sameLine()
	ui.setNextItemWidth(90)
	local volume = sliders.withDefault('##keywordVolume', option.volume, 0, 300, '%.0f%%', sliders.defaults.keywordVolume, 1)
	if keywordKey ~= '' and volume ~= option.volume then
	  keywordOptions[keywordKey] = { volume = volume, hidden = option.hidden }
	  keywordSettingsChanged = true
	end
	ui.sameLine()
	local keywordSoundWidth = ui.availableSpaceX()
	soundPicker.drawFile('##keywordSound', selectedSound, keywordSoundWidth, index, nil, soundPicker.usedSounds(keywordSoundAssignments), setSelectedSound)
	keywordRowCenters[index] = (rowTop + ui.getCursorY() + 22) / 2
	ui.unindent(22)
	ui.separator()
	ui.popID()
  end
  if #keywords > 0 then
	ui.pushID('keywordAppend')
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = #keywords
	end
	ui.popID()
  end
  if removedKeywordIndex then
	table.remove(keywords, removedKeywordIndex)
	keywordSettingsChanged = true
  elseif insertAfterIndex then
	table.insert(keywords, insertAfterIndex + 1, '')
	keywordSettingsChanged = true
  end

  if draggingKeywordIndex and ui.mouseDown() and #keywords > 1 then
	local mouseY = ui.mouseLocalPos().y
	local previousIndex = draggingKeywordIndex - 1
	local nextIndex = draggingKeywordIndex + 1
	if previousIndex >= 1 and mouseY < keywordRowCenters[previousIndex] then
	  keywords[draggingKeywordIndex], keywords[previousIndex] = keywords[previousIndex], keywords[draggingKeywordIndex]
	  draggingKeywordIndex = previousIndex
	  keywordSettingsChanged = true
	elseif nextIndex <= #keywords and mouseY > keywordRowCenters[nextIndex] then
	  keywords[draggingKeywordIndex], keywords[nextIndex] = keywords[nextIndex], keywords[draggingKeywordIndex]
	  draggingKeywordIndex = nextIndex
	  keywordSettingsChanged = true
	end
  end
  if not ui.mouseDown() then draggingKeywordIndex = nil end
  if keywordSettingsChanged then
	local activeKeywords = {}
	for _, keyword in ipairs(keywords) do
	  local keywordKey = lowerText(keyword:match('^%s*(.-)%s*$'))
	  if keywordKey ~= '' then activeKeywords[keywordKey] = true end
	end
	for keyword in pairs(keywordSoundAssignments) do
	  if not activeKeywords[keyword] then keywordSoundAssignments[keyword] = nil end
	end
	for keyword in pairs(mutedKeywords) do
	  if not activeKeywords[keyword] then mutedKeywords[keyword] = nil end
	end
	for keyword in pairs(keywordOptions) do
	  if not activeKeywords[keyword] then keywordOptions[keyword] = nil end
	end
	saveKeywords(keywords)
	saveKeywordSoundAssignments(keywordSoundAssignments)
	saveMutedKeywords(mutedKeywords)
	keywordOptionStore.save(keywordOptions)
	if Profiles.activeKeywordProfileKey then
	  saveKeywordProfile(Profiles.activeKeywordProfileKey)
	elseif settings.useServerKeywordProfiles then
	  settings.keywordProfileFallback = stringify(captureKeywordProfile(), true)
	end
  end
end

AlertsTab.drawAlertsTab = drawAlertsTab

return AlertsTab
