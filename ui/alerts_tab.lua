-- Settings window, Alerts tab: sound options and the keyword list.
local modules = require('core.modules')
local Sounds = modules.sounds
local Profiles = modules.profiles
local AlertsTab = modules.alertsTab
local tr = modules.i18n.tr

local defaultAlertSoundFile = modules.paths.defaultAlertSoundFile
local settings = modules.settings.settings
local playAlertSound = modules.sounds.playAlertSound
local isSoundTestPlaying = modules.sounds.isSoundTestPlaying
local Widgets = modules.widgets
local sliders = modules.widgets.sliders
local soundPicker = modules.widgets.soundPicker
local drawSoundFolderButton = modules.widgets.drawSoundFolderButton
local specialAlertKeys = modules.keywords.specialAlertKeys
local lowerText = modules.keywords.lowerText
local keywordKeyOf = modules.keywords.keywordKey
local parseKeywords = modules.keywords.parseKeywords
local saveKeywords = modules.keywords.saveKeywords
local loadKeywordSoundAssignments = modules.keywords.loadKeywordSoundAssignments
local saveKeywordSoundAssignments = modules.keywords.saveKeywordSoundAssignments
local loadMutedKeywords = modules.keywords.loadMutedKeywords
local saveMutedKeywords = modules.keywords.saveMutedKeywords
local keywordOptionStore = modules.keywords.keywordOptionStore
local captureKeywordProfile = modules.profiles.captureKeywordProfile
local saveKeywordProfile = modules.profiles.saveKeywordProfile

local Debug = modules.debug.Debug

local keywordDrag = modules.listDrag.new()
AlertsTab.keywordDrag = keywordDrag
local keywordRowPadding = 6
local keyEnter = 0x0D -- VK_RETURN: validates the keyword being typed.
local userKeywordDrafts = { text = {}, volume = {} }
local deleteKeywordConfirmed = false
local removedKeywordIndex = nil
local missingSoundStates = {}  -- Cache: { cachedSound, isMissing, startTime } - checked only when sound changes
local drawKeywordList
-- Track playback frame counters for sound test progress (simple approximation)
local soundTestFrameCounters = {}

-- Edits not validated yet, keyed by row index. A list is saved only when a value is validated.
local function clearKeywordDrafts(drafts)
  drafts.text, drafts.volume = {}, {}
end

-- Keyword profiles hold only the user list, so only it triggers a profile save.
local function saveUserKeywordProfile()
  if Profiles.activeKeywordProfileKey then
	saveKeywordProfile(Profiles.activeKeywordProfileKey)
  elseif settings.useServerKeywordProfiles then
	settings.keywordProfileFallback = stringify(captureKeywordProfile(), true)
  end
end

-- Data access for the user keyword list, used by drawKeywordList.
local userKeywordList = {
  keywords = parseKeywords,
  soundAssignments = loadKeywordSoundAssignments,
  mutedKeywords = loadMutedKeywords,
  options = keywordOptionStore.load,
  option = keywordOptionStore.get,
  commit = function(keywords, soundAssignments, mutedKeywords, keywordOptions)
	local activeKeywords = {}
	for _, keyword in ipairs(keywords) do
	  local activeKey = keywordKeyOf(keyword)
	  if activeKey ~= '' then activeKeywords[activeKey] = true end
	end
	for _, entries in ipairs({ soundAssignments, mutedKeywords, keywordOptions }) do
	  for keyword in pairs(entries) do
		if not activeKeywords[keyword] then entries[keyword] = nil end
	  end
	end
	saveKeywords(keywords)
	saveKeywordSoundAssignments(soundAssignments)
	saveMutedKeywords(mutedKeywords)
	keywordOptionStore.save(keywordOptions)
  end,
}

-- Header content for Alerts tab: shown in sticky header frame
local function drawAlertsTabHeader()
  if sliders.checkbox(tr('Play alert sound'), settings.soundEnabled, sliders.defaults.soundEnabled, 'soundEnabled') then
	settings.soundEnabled = not settings.soundEnabled
  end
  settings.masterVolume = sliders.withDefault(tr('Master volume'), settings.masterVolume, 0, 300, '%.0f%%', sliders.defaults.masterVolume, 1, 'masterVolume', ui.Icons.Levels)
  ui.separator()
  if sliders.checkbox(tr('Alert when my name is mentioned'), settings.mentionMe, sliders.defaults.mentionMe, 'mentionMe') then
	settings.mentionMe = not settings.mentionMe
  end
  if sliders.checkbox(tr('Alert when the author is a friend'), settings.alertFriendMessage, sliders.defaults.alertFriendMessage, 'alertFriendMessage') then
	settings.alertFriendMessage = not settings.alertFriendMessage
  end
  ui.separator()
end

local function drawAlertsTab()
  -- Refresh the list of available sounds each time the tab is displayed
  Sounds.refreshAlertSoundFiles()

  drawSoundFolderButton()
  Widgets.textWrapped(tr('Available sounds: .wav and .mp3 files in the sounds folder and its subfolders. If a selected file is missing or cannot be loaded, %s is used instead.', defaultAlertSoundFile))
  if not Sounds.alertSoundFileSet[defaultAlertSoundFile] then
	Widgets.textWrapped(tr('Warning: the default sound %s is missing from the sounds folder. Alerts with a missing sound will be silent.', defaultAlertSoundFile))
  end
  ui.separator()
  ui.header(tr('Alert keywords (priority order)'))
  Widgets.textWrapped(tr('When several entries match, the first one in this list selects the sound. Drag the handle to reorder. The player mention and friend entries can be moved, muted or hidden, but not deleted. Text changes are saved when you press Enter or leave the field.'))
  drawKeywordList(userKeywordList, userKeywordDrafts, keywordDrag, { idPrefix = 'keyword', testPrefix = 'keyword:', isUser = true, afterSave = saveUserKeywordProfile })
  end

function drawKeywordList(list, drafts, drag, options)
  local keywordDrag = drag
  local keywords = list.keywords()
  local keywordSoundAssignments = list.soundAssignments()
  local mutedKeywords = list.mutedKeywords()
  local keywordOptions = list.options()
  local keywordRowCenters = {}
  local keywordRowBounds = {}
  local keywordSettingsChanged = false
  local insertAfterIndex = nil

  local shownBuiltInHeader = false
  local shownCustomHeader = false
  if #keywords == 0 then
	Widgets.text(tr('No alert keywords yet.'))
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = 0
	end
  end
  for index, keyword in ipairs(keywords) do
	local isBuiltIn = keyword == specialAlertKeys.player or keyword == specialAlertKeys.friend

	if isBuiltIn and not shownBuiltInHeader then
	  if index > 1 then ui.separator() end
	  Widgets.textWrapped(tr('Built-in Alerts - Player mention and friend messages'))
	  shownBuiltInHeader = true
	end

	if options.isUser and not isBuiltIn and not shownCustomHeader then
	  ui.separator()
	  Widgets.textWrapped(tr('Custom Keywords - Sorted by priority (drag to reorder)'))
	  shownCustomHeader = true
	end

	ui.pushID(options.idPrefix .. index)
	local specialPrefix = keyword == specialAlertKeys.player and 'mention' or (keyword == specialAlertKeys.friend and 'friend') or nil
	local isSpecial = specialPrefix ~= nil
	local fieldText = specialAlertKeys.labels[keyword] and tr(specialAlertKeys.labels[keyword]) or keyword
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = index - 1
	end
	ui.separator()
	local rowTop = ui.getCursorY()
	local rowLeft = ui.getCursorX()
	local rowRight = rowLeft + ui.availableSpaceX()
	ui.indent(keywordRowPadding)
	ui.dummy(vec2(0, keywordRowPadding))
	ui.iconButton(ui.Icons.Menu, vec2(22, 22))
	if ui.itemActive() and ui.mouseDown() then
	  keywordDrag:press(index, ui.mouseLocalPos().y - ui.getScrollY())
	end
	ui.sameLine()
	Widgets.text('#' .. index)
	ui.sameLine()
	local isSpecial = specialPrefix ~= nil
	if isSpecial then
	  local isPlayerAlert = keyword == specialAlertKeys.player
	  if isPlayerAlert then
		if sliders.checkbox('##playerAlertEnabled', settings.mentionMe, sliders.defaults.mentionMe, 'mentionMe') then
		  settings.mentionMe = not settings.mentionMe
		end
		ui.sameLine()
	  elseif keyword == specialAlertKeys.friend then
		if sliders.checkbox('##friendAlertEnabled', settings.alertFriendMessage, sliders.defaults.alertFriendMessage, 'alertFriendMessage') then
		  settings.alertFriendMessage = not settings.alertFriendMessage
		end
		ui.sameLine()
	  else
		ui.dummy(vec2(22, 22))
	  end
	else
	  if ui.iconButton(ui.Icons.Trash, vec2(22, 22)) then
		if removedKeywordIndex == index then
		  -- Deuxième click: cancel la suppression
		  removedKeywordIndex = nil
		  deleteKeywordConfirmed = false
		else
		  -- Premier click: marquer pour suppression
		  removedKeywordIndex = index
		  deleteKeywordConfirmed = false
		end
	  end
	  ui.sameLine()
	  if removedKeywordIndex == index then
		-- Pulsing orange background (blinking effect)
		local pulse = math.sin(ui.time() * 4) * 0.5 + 0.5  -- 0 to 1, pulsing at 4 Hz
		local bgColor = rgbm(1, 0.6, 0, pulse * 0.6)  -- orange with pulsing alpha
		local deleteLabel = tr('Delete this alert?')
		local labelOrigin = ui.getCursor()
		ui.drawRectFilled(labelOrigin, labelOrigin + ui.measureText(deleteLabel), bgColor, 0)
		ui.pushStyleColor(ui.StyleColor.FrameBg, bgColor)
		Widgets.text(deleteLabel)
		ui.sameLine()
		if ui.checkbox('##deleteConfirm_' .. index, deleteKeywordConfirmed) then
		  deleteKeywordConfirmed = not deleteKeywordConfirmed
		end
		ui.popStyleColor()
	  end
	end
	Widgets.text(isSpecial and tr('Built-in alert') or tr('Keyword or trigger phrase'))
	if isSpecial then
	  ui.sameLine()
	  -- Befriend is a placeholder for the friends alert; change it when a dedicated icon is chosen.
	  local isPlayerAlert = keyword == specialAlertKeys.player
	  ui.icon(isPlayerAlert and ui.Icons.Driver or ui.Icons.Befriend, vec2(18, 18), isPlayerAlert and settings.playerColor or settings.friendColor)
	end
	ui.sameLine()
	local keywordWidth = math.max(40, ui.availableSpaceX() - keywordRowPadding)
	local keywordContentWidth = math.max(keywordWidth, ui.measureText(fieldText).x + 24)
	ui.pushStyleVar(ui.StyleVar.WindowPadding, vec2(0, 0))
	ui.setNextWindowContentSize(vec2(keywordContentWidth, 0))
	local validatedKeyword = nil
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
	  local typedKeyword = ui.inputText('##keywordValue', drafts.text[index] or fieldText, isSpecial and ui.InputTextFlags.ReadOnly or 0)
	  if not isSpecial then
		local validated = ui.itemDeactivatedAfterEdit() or (ui.itemActive() and ui.keyboardButtonPressed(keyEnter, false))
		if validated then
		  drafts.text[index] = nil
		  validatedKeyword = typedKeyword
		else
		  drafts.text[index] = typedKeyword ~= keyword and typedKeyword or nil
		end
	  end
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
	local newKey = lowerText((validatedKeyword or keyword):match('^%s*(.-)%s*$'))
	if validatedKeyword and validatedKeyword ~= keyword then
	  if oldKey ~= '' and newKey ~= '' and oldKey ~= newKey then
		if keywordSoundAssignments[oldKey] and not keywordSoundAssignments[newKey] then
		  keywordSoundAssignments[newKey] = keywordSoundAssignments[oldKey]
		end
		if mutedKeywords[oldKey] then mutedKeywords[newKey] = true end
		if keywordOptions[oldKey] and not keywordOptions[newKey] then keywordOptions[newKey] = keywordOptions[oldKey] end
	  end
	  keywords[index] = validatedKeyword
	  keywordSettingsChanged = true
	end
	ui.indent(22)
	local keywordKey = newKey
	local selectedSound
	if isSpecial then selectedSound = settings[specialPrefix .. 'Sound'] else selectedSound = keywordSoundAssignments[keywordKey] end
	local option = list.option(keywordKey)
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
	local keywordTestKey = specialPrefix or (options.testPrefix .. keywordKey)
	if ui.iconButton(isSoundTestPlaying(keywordTestKey) and ui.Icons.Stop or ui.Icons.Play, vec2(22, 22)) then
	  playAlertSound(selectedSound or defaultAlertSoundFile, true, keywordTestKey, option.volume)
	  -- Reset frame counter for progress bar
	  if isSoundTestPlaying(keywordTestKey) then
		soundTestFrameCounters[keywordTestKey] = 0
	  else
		soundTestFrameCounters[keywordTestKey] = nil
	  end
	end
	ui.sameLine()
	ui.setNextItemWidth(90)
	local volume = sliders.withDefault('##keywordVolume', drafts.volume[index] or option.volume, 0, 300, '%.0f%%', sliders.defaults.keywordVolume, 1)
	local sliderSize = ui.getItemRectSize()
	-- Volume is saved when slider is released, not on every frame of a drag
	drafts.volume[index] = keywordKey ~= '' and volume ~= option.volume and volume or nil
	if drafts.volume[index] and not ui.itemActive() then
	  drafts.volume[index] = nil
	  keywordOptions[keywordKey] = { volume = volume, hidden = option.hidden }
	  keywordSettingsChanged = true
	end
	ui.sameLine()
	local soundToCheck = selectedSound or defaultAlertSoundFile
	local soundDuration = soundPicker.durationOf(soundToCheck) or 1.0
	-- Update elapsed time (frame counter ~60fps approximation)
	local elapsedTime = 0
	if soundTestFrameCounters[keywordTestKey] ~= nil and isSoundTestPlaying(keywordTestKey) then
	  soundTestFrameCounters[keywordTestKey] = soundTestFrameCounters[keywordTestKey] + 1
	  elapsedTime = soundTestFrameCounters[keywordTestKey] / 60
	  elapsedTime = math.min(elapsedTime, soundDuration)
	end
	-- Display progress slider (reuses volume slider interface)
	ui.setNextItemWidth(90)
	ui.slider('##soundProgress', elapsedTime, 0, soundDuration, string.format('%.1fs/%.3fs', elapsedTime, soundDuration))
	-- Slider value is read-only (progress controlled by frame counter)
	ui.sameLine()
	local keywordSoundWidth = ui.availableSpaceX() - keywordRowPadding

	-- Capture position BEFORE drawing the sound picker
	local soundTextPos = ui.getCursor()

	soundPicker.drawFile('##keywordSound', selectedSound, keywordSoundWidth, index, nil, soundPicker.usedSounds(keywordSoundAssignments), setSelectedSound)
	-- Sound selector size measured, unused (kept for future reference)
	local soundSelectorSize = ui.getItemRectSize()

	-- Check if sound has changed: if so, verify if it's missing (only once per change)
	local state = missingSoundStates[index]
	if not state or state.cachedSound ~= selectedSound then
	  -- Sound changed or first time: check if file exists in sounds list
	  local isSoundMissing = selectedSound and selectedSound ~= '' and not Sounds.alertSoundFileSet[selectedSound]
	  missingSoundStates[index] = {
		cachedSound = selectedSound,
		isMissing = isSoundMissing,
		startTime = isSoundMissing and ui.time() or nil
	  }
	  state = missingSoundStates[index]
	end

	-- Draw red/white blinking background for missing sounds (using cached state)
	if state.isMissing then
	  local elapsed = ui.time() - state.startTime
	  local isBlink = math.floor(elapsed * 2) % 2 == 0  -- Alternate every 0.5s

	  local rectSize = vec2(keywordSoundWidth, 20)

	  if isBlink then
		-- RED phase
		local bgColor = rgbm(1, 0, 0, 0.5)  -- Red with 50% opacity
		ui.drawRectFilled(soundTextPos, soundTextPos + rectSize, bgColor, 2)
	  else
		-- WHITE phase
		local bgColor = rgbm(1, 1, 1, 0.3)  -- White with 30% opacity
		ui.drawRectFilled(soundTextPos, soundTextPos + rectSize, bgColor, 2)
	  end
	end

	ui.dummy(vec2(0, keywordRowPadding))
	local rowBottom = ui.getCursorY()
	local frameColor = modules.widgets.rowFrameColor()
	ui.drawRect(vec2(rowLeft, rowTop), vec2(rowRight, rowBottom), frameColor, 0, ui.CornerFlags.All, 1)
	keywordRowCenters[index] = (rowTop + rowBottom) / 2
	keywordRowBounds[index] = { left = rowLeft, right = rowRight, top = rowTop, bottom = rowBottom }
	ui.unindent(22)
	ui.unindent(keywordRowPadding)
	ui.separator()
	ui.popID()
  end
  if #keywords > 0 then
	ui.pushID(options.idPrefix .. 'Append')
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = #keywords
	end
	ui.popID()
   end

   if insertAfterIndex then
	clearKeywordDrafts(drafts)
		table.insert(keywords, insertAfterIndex + 1, '')
	keywordSettingsChanged = true
   end

   -- Delete keyword if confirmed
   if removedKeywordIndex and deleteKeywordConfirmed then
	clearKeywordDrafts(drafts)
	table.remove(keywords, removedKeywordIndex)
	keywordSettingsChanged = true
	deleteKeywordConfirmed = false
	removedKeywordIndex = nil
   end

   if removedKeywordIndex or insertAfterIndex then
	keywordDrag:reset()
  elseif keywordDrag.index then
	local wasMoved, wasScrolling, wasIndex = keywordDrag.moved, keywordDrag.scrolling, keywordDrag.index
	local heldBounds = keywordRowBounds[wasIndex]
	local currentScrollY = ui.getScrollY()
	-- ui.mouseLocalPos() includes the scroll; the drag wants the pointer relative to the visible window.
	local moves, scrollY = keywordDrag:update({
	  mouseDown = ui.mouseDown(),
	  pointerY = ui.mouseLocalPos().y - currentScrollY,
	  windowHeight = ui.windowHeight(),
	  scrollY = currentScrollY,
	  scrollMaxY = ui.getScrollMaxY(),
	  dt = ui.deltaTime(),
	  centers = keywordRowCenters,
	})
	if keywordDrag.moved and not wasMoved then
	  Debug.trace(string.format('Keyword drag: start #%d', wasIndex))
	end
	for _, move in ipairs(moves) do
	  clearKeywordDrafts(drafts)
			keywords[move[1]], keywords[move[2]] = keywords[move[2]], keywords[move[1]]
	  keywordSettingsChanged = true
	  Debug.trace(string.format('Keyword drag: #%d -> #%d', move[1], move[2]))
	end
	if keywordDrag.scrolling ~= wasScrolling then
	  Debug.trace(keywordDrag.scrolling and 'Keyword drag: auto-scroll start' or 'Keyword drag: auto-scroll stop')
	end
	if scrollY then
	  ui.setScrollY(scrollY, false, false)
	end
	if keywordDrag.itemY and heldBounds then
	  -- The floating frame follows the pointer while the list rows swap around it.
	  local color = modules.widgets.rowFrameColor()
	  local halfHeight = (heldBounds.bottom - heldBounds.top) / 2
	  local frameTop = vec2(heldBounds.left, keywordDrag.itemY - halfHeight)
	  local frameBottom = vec2(heldBounds.right, keywordDrag.itemY + halfHeight)
	  ui.drawRectFilled(frameTop, frameBottom, rgbm(color.r, color.g, color.b, 0.15), 0)
	  ui.drawRect(frameTop, frameBottom, color, 0, ui.CornerFlags.All, 3)
	end
	if not keywordDrag.index and wasMoved then
	  Debug.trace(string.format('Keyword drag: dropped at #%d', wasIndex))
	end
  end
  if keywordSettingsChanged then
	list.commit(keywords, keywordSoundAssignments, mutedKeywords, keywordOptions)
	if options.afterSave then options.afterSave() end
  end
end

AlertsTab.drawAlertsTab = drawAlertsTab
AlertsTab.drawAlertsTabHeader = drawAlertsTabHeader

return AlertsTab

