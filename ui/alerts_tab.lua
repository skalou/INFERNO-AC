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
local saveKeywords = modules.keywords.saveKeywords
local parseKeywords = modules.keywords.parseKeywords
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

local function drawAlertsTab()
  if sliders.checkbox(tr('Play alert sound'), settings.soundEnabled, sliders.defaults.soundEnabled, 'soundEnabled') then
	settings.soundEnabled = not settings.soundEnabled
  end
  settings.masterVolume = sliders.withDefault(tr('Master volume'), settings.masterVolume, 0, 300, '%.0f%%', sliders.defaults.masterVolume, 1, 'masterVolume', ui.Icons.Levels)
  drawSoundFolderButton()
  Widgets.textWrapped(tr('Available sounds: .wav and .mp3 files in the sounds folder and its subfolders. If a selected file is missing or cannot be loaded, %s is used instead.', defaultAlertSoundFile))
  if not Sounds.alertSoundFileSet[defaultAlertSoundFile] then
    Widgets.textWrapped(tr('Warning: the default sound %s is missing from the sounds folder. Alerts with a missing sound will be silent.', defaultAlertSoundFile))
  end
  ui.separator()
  if sliders.checkbox(tr('Alert when my name is mentioned'), settings.mentionMe, sliders.defaults.mentionMe, 'mentionMe') then
	settings.mentionMe = not settings.mentionMe
  end
  ui.separator()
  ui.header(tr('Alert keywords (priority order)'))
  Widgets.textWrapped(tr('When several entries match, the first one in this list selects the sound. Drag the handle to reorder. The player mention and friend entries can be moved, muted or hidden, but not deleted.'))
  local keywords = parseKeywords()
  local keywordSoundAssignments = loadKeywordSoundAssignments()
  local mutedKeywords = loadMutedKeywords()
  local keywordOptions = keywordOptionStore.load()
  local keywordRowCenters = {}
  local keywordRowBounds = {}
  local keywordSettingsChanged = false
  local removedKeywordIndex = nil
  local insertAfterIndex = nil
  if #keywords == 0 then
	Widgets.text(tr('No alert keywords yet.'))
	if ui.iconButton(ui.Icons.Plus, vec2(22, 22)) then
	  insertAfterIndex = 0
	end
  end
  for index, keyword in ipairs(keywords) do
	ui.pushID('keyword' .. index)
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
	if isSpecial then
	  ui.dummy(vec2(22, 22))
	elseif ui.iconButton(ui.Icons.Trash, vec2(22, 22)) then
	  removedKeywordIndex = index
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
	local keywordSoundWidth = ui.availableSpaceX() - keywordRowPadding
	soundPicker.drawFile('##keywordSound', selectedSound, keywordSoundWidth, index, nil, soundPicker.usedSounds(keywordSoundAssignments), setSelectedSound)
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
