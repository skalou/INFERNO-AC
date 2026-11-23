-- Shared UI widgets: sliders and checkboxes with defaults, sound picker, colour buttons, settings theme.
local modules = require('core.modules')
local Sounds = modules.sounds
local Widgets = modules.widgets
local tr = modules.i18n.tr

local defaultAlertSoundFile = modules.paths.defaultAlertSoundFile
local App = modules.paths.App
local soundFolder = modules.paths.soundFolder
local settings = modules.settings.settings
local colorDefaults = modules.settings.colorDefaults
local Debug = modules.debug.Debug
local playAlertSound = modules.sounds.playAlertSound
local isSoundTestPlaying = modules.sounds.isSoundTestPlaying
local refreshAlertSoundFiles = modules.sounds.refreshAlertSoundFiles
local describeAlertSound = modules.sounds.describeAlertSound

local soundFolderStatus = ''
local comboWasOpen = {}

-- In DEBUG mode, text is drawn as a read-only input without frame or padding, so it can be selected and copied but looks the same.
-- Inputs need a unique ID within a frame, hence the per-frame counter; the text is part of the ID so a changed text starts a new input.
local selectableText = { frame = -1, count = 0, grey = rgbm(0.5, 0.5, 0.5, 1) }

local function drawSelectableLine(text, color)
  local frame = ui.frameCount()
  if frame ~= selectableText.frame then
    selectableText.frame = frame
    selectableText.count = 0
  end
  selectableText.count = selectableText.count + 1
  local transparent = rgbm(0, 0, 0, 0)
  ui.pushStyleVar(ui.StyleVar.FramePadding, vec2(0, 0))
  ui.pushStyleColor(ui.StyleColor.FrameBg, transparent)
  ui.pushStyleColor(ui.StyleColor.FrameBgHovered, transparent)
  ui.pushStyleColor(ui.StyleColor.FrameBgActive, transparent)
  if color then ui.pushStyleColor(ui.StyleColor.Text, color) end
  ui.setNextItemWidth(ui.measureText(text).x + 6)
  ui.inputText('##selectable' .. selectableText.count .. text, text, ui.InputTextFlags.ReadOnly + ui.InputTextFlags.NoHorizontalScroll)
  ui.popStyleColor(color and 4 or 3)
  ui.popStyleVar(1)
end

-- Greedy word wrap, one entry per line; each newline in the text starts a new line.
local function wrapLines(text, maxWidth)
  local lines = {}
  for paragraph in (text .. '\n'):gmatch('(.-)\n') do
    local line = ''
    for word in paragraph:gmatch('%S+') do
      local candidate = line == '' and word or line .. ' ' .. word
      if line ~= '' and ui.measureText(candidate).x > maxWidth then
        lines[#lines + 1] = line
        line = word
      else
        line = candidate
      end
    end
    lines[#lines + 1] = line
  end
  return lines
end

-- Replaces ui.text / ui.textColored: selectable in DEBUG mode, plain text otherwise.
function Widgets.text(text, color)
  if settings.debugEnabled then
    drawSelectableLine(text, color)
  elseif color then
    ui.textColored(text, color)
  else
    ui.text(text)
  end
end

-- Replaces ui.textDisabled.
function Widgets.textDisabled(text)
  if settings.debugEnabled then
    drawSelectableLine(text, selectableText.grey)
  else
    ui.textDisabled(text)
  end
end

-- Replaces ui.textWrapped. In DEBUG mode each wrapped line is its own input, so a paragraph is copied one line at a time.
function Widgets.textWrapped(text)
  if settings.debugEnabled then
    for _, line in ipairs(wrapLines(text, ui.availableSpaceX())) do
      drawSelectableLine(line)
    end
  else
    ui.textWrapped(text)
  end
end

-- Hover help for a setting, from ui/setting_help.lua. In DEBUG mode the technical details are added: key, storage, default, current value and range.
-- Call it right after the widget. Nothing is shown when the last item is not hovered, or when the setting has no help text.
function Widgets.settingTooltip(key, current, default, min, max, step)
  local help = modules.settingHelp
  local text = key and help.texts[key]
  if not text or not ui.itemHovered() then return end
  local lines = wrapLines(tr(text), 360)
  if settings.debugEnabled then
    local function format(value)
      if type(value) == 'boolean' then return tostring(value) end
      if type(value) == 'number' then return string.format('%g', value) end
      return string.format('RGBA %d, %d, %d, %d', math.floor(value.r * 255 + 0.5), math.floor(value.g * 255 + 0.5), math.floor(value.b * 255 + 0.5), math.floor(value.mult * 255 + 0.5))
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = tr('Key: %s', key)
    lines[#lines + 1] = tr('Storage: %s', help.storage[key] or ('INFERNO_' .. key))
    if default ~= nil then lines[#lines + 1] = tr('Default: %s', format(default)) end
    lines[#lines + 1] = tr('Current: %s', format(current))
    if min then
      local range = tr('Range: %s to %s', format(min), format(max))
      if step then range = range .. ', step ' .. format(step) end
      lines[#lines + 1] = range
    end
  end
  ui.setTooltip(table.concat(lines, '\n'))
end

-- Slider and checkbox defaults and helpers, grouped in one table because Lua allows only 200 locals per chunk.
local sliders = {
  defaults = {
    masterVolume = 100,
    keywordVolume = 100,
    textSize = 20,
    duration = 3.0,
    opacity = 75,
    outlineThicknessPercent = 5.2631556987762,
    buttonOverflow = 5,
    soundEnabled = true,
    mentionMe = true,
    alertFriendMessage = true,
    showAllChatMessages = false,
    hideWhenNotHovered = false,
    backgroundEnabled = false,
    softOutline = true,
    useVehicleDisplayProfiles = false,
    useServerKeywordProfiles = false,
    autoSaveServerSettings = false,
    debugEnabled = false,
    debugTraceEnabled = false,
    debugModeEnabled = false,
    simulatorFriend = false,
  },
  modifiedColor = rgbm(1, 1, 0.4, 1),
  modifiedCheckMark = rgbm(0, 0, 0, 1),
}

-- Right-click (on release) restores the default, the label turns yellow while the value differs, the mouse wheel moves by `step`.
-- An optional icon is drawn on the left of the slider.
function sliders.withDefault(label, value, min, max, format, default, step, key, icon)
  local modified = math.abs(value - default) > 0.0001
  if icon then
    ui.icon(icon, ui.fontSize())
    ui.sameLine()
  end
  if modified then ui.pushStyleColor(ui.StyleColor.Text, sliders.modifiedColor) end
  local newValue = ui.slider(label, value, min, max, format)
  if modified then ui.popStyleColor(1) end
  if ui.itemHovered() then
    local wheel = ui.mouseWheel()
    if wheel ~= 0 then
      newValue = math.clamp(math.floor(newValue / step + wheel + 0.5) * step, min, max)
    end
  end
  if ui.itemClicked(ui.MouseButton.Right, true) then newValue = default end
  Widgets.settingTooltip(key, newValue, default, min, max, step)
  return newValue
end

-- Checkbox whose box and label turn yellow while its value differs from the default; returns true when clicked, like ui.checkbox.
-- With an icon, the icon sits between the box and the label, and the label is a button so clicking the text also toggles it.
function sliders.checkbox(label, value, default, key, icon)
  local modified = value ~= default
  if modified then
    ui.pushStyleColor(ui.StyleColor.FrameBg, sliders.modifiedColor)
    ui.pushStyleColor(ui.StyleColor.FrameBgHovered, sliders.modifiedColor)
    ui.pushStyleColor(ui.StyleColor.FrameBgActive, sliders.modifiedColor)
    ui.pushStyleColor(ui.StyleColor.CheckMark, sliders.modifiedCheckMark)
    ui.pushStyleColor(ui.StyleColor.Text, sliders.modifiedColor)
  end
  local clicked
  if icon then
    clicked = ui.checkbox('##box_' .. key, value)
    Widgets.settingTooltip(key, value, default)
    ui.sameLine()
    ui.icon(icon, ui.fontSize())
    ui.sameLine()
    ui.pushStyleColor(ui.StyleColor.Button, rgbm(0, 0, 0, 0))
    if ui.button(label .. '##label_' .. key) then clicked = true end
    ui.popStyleColor(1)
  else
    clicked = ui.checkbox(label, value)
  end
  if modified then ui.popStyleColor(5) end
  Widgets.settingTooltip(key, value, default)
  return clicked
end

local soundPicker = {}

-- Recently chosen sounds, most recent first. Stored as file names separated by '|', which Windows does not allow in file names.
soundPicker.recentLimit = 5
soundPicker.durations = {}

function soundPicker.recentNames()
  local names = {}
  for fileName in (settings.recentSounds or ''):gmatch('[^|]+') do
	if Sounds.alertSoundFileSet[fileName] and fileName ~= defaultAlertSoundFile then
	  names[#names + 1] = fileName
	end
  end
  return names
end

-- The default is not recorded, because it always has its own entry in the list.
function soundPicker.remember(fileName)
  if not fileName or fileName == defaultAlertSoundFile or not Sounds.alertSoundFileSet[fileName] then return end
  local names = { fileName }
  for _, name in ipairs(soundPicker.recentNames()) do
	if name ~= fileName and #names < soundPicker.recentLimit then names[#names + 1] = name end
  end
  settings.recentSounds = table.concat(names, '|')
end

-- Length in seconds, read once per file. Not cached while audio is unavailable, so it is retried later.
function soundPicker.durationOf(fileName)
  local cached = soundPicker.durations[fileName]
  if cached == nil then
	if not ac.isAudioReady() then return nil end
	if not Sounds.alertSoundFileSet[fileName] then return nil end
	local ok, sound = pcall(ac.AudioEvent.fromFile, {
	  filename = soundFolder .. '\\' .. Sounds.alertSoundFileSet[fileName],
	  use3D = false,
	  loop = false
	})
	cached = -1
	if ok and sound then
	  local read, duration = pcall(function() return sound:getDuration() end)
	  if read and type(duration) == 'number' and duration >= 0 then cached = duration end
	  pcall(function() sound:dispose() end)
	end
	soundPicker.durations[fileName] = cached
  end
  return cached >= 0 and cached or nil
end

-- Sounds already used by an alert (mention, friend and keyword assignments). They are drawn in another colour in the lists.
function soundPicker.usedSounds(keywordAssignments)
  local used = {}
  if settings.mentionSound then used[settings.mentionSound] = true end
  if settings.friendSound then used[settings.friendSound] = true end
  for _, fileName in pairs(keywordAssignments) do used[fileName] = true end
  return used
end

function soundPicker.drawRecent(selectedSound, usedSounds, onPick)
  local names = soundPicker.recentNames()
  Widgets.text(tr('Recent Sounds'), rgbm(0.6, 0.6, 0.6, 1))
  if #names == 0 then
	Widgets.text(tr('No recent sounds yet, pick one below'), rgbm(0.45, 0.45, 0.45, 1))
	ui.separator()
	return
  end
  for index, fileName in ipairs(names) do
	soundPicker.drawSoundRow('recent' .. index, fileName, '\\' .. Sounds.alertSoundFileSet[fileName], selectedSound == fileName, usedSounds, onPick)
  end
  ui.separator()
end

-- One sound in a dropdown: play/stop button, then the name and duration. Clicking the name picks the sound.
function soundPicker.drawSoundRow(rowId, fileName, label, selected, usedSounds, onPick)
  ui.pushID(rowId)
  local testKey = 'sound:' .. fileName
  if ui.iconButton(isSoundTestPlaying(testKey) and ui.Icons.Stop or ui.Icons.Play, vec2(16, 16)) then
	playAlertSound(fileName, true, testKey, 100)
  end
  ui.sameLine(0, 8)
  local duration = soundPicker.durationOf(fileName)
  if duration then label = label .. '  ' .. string.format('%.1fs', duration) end

  local color = nil
  if selected then
	color = soundPicker.selectedColor()
  elseif fileName == defaultAlertSoundFile then
	-- Default sound gets its diagnostic color (debug or normal depending on settings)
	color = soundPicker.defaultColor()
  elseif usedSounds[fileName] == true then
	color = soundPicker.usedColor()
  end

  if color then ui.pushStyleColor(ui.StyleColor.Text, color) end
  local picked = ui.selectable(label, selected)
  if color then ui.popStyleColor() end
  if picked then
	onPick(fileName)
  end
  if selected then ui.setItemDefaultFocus() end
  ui.popID()
end

-- All sounds grouped by sub-folder (the root first), in the same order as the folder dropdown.
function soundPicker.groupedSounds()
  local groups = {}
  local byFolder = {}
  for _, fileName in ipairs(Sounds.alertSoundFiles) do
	local folder = soundPicker.folderOf(fileName)
	if not byFolder[folder] then
	  byFolder[folder] = { folder = folder, files = {} }
	  groups[#groups + 1] = byFolder[folder]
	end
	table.insert(byFolder[folder].files, fileName)
  end
  table.sort(groups, function(a, b) return a.folder:lower() < b.folder:lower() end)
  return groups
end

-- The sound list may use this share of the screen height, leaving a margin above and below.
soundPicker.listHeightRatio = 0.8

function soundPicker.listHeight()
  return math.floor(ac.getUI().windowSize.y * soundPicker.listHeightRatio)
end

function soundPicker.drawSelector(id, text, width, phase, drawOptions)
  local arrowWidth = 24
  local previewWidth = math.max(20, width - arrowWidth - 4)
  local contentWidth = math.max(previewWidth, ui.measureText(text).x + 12)
  ui.pushStyleVar(ui.StyleVar.WindowPadding, vec2(0, 0))
  ui.setNextWindowContentSize(vec2(contentWidth, 0))
  if ui.beginChild(id .. 'Preview', vec2(previewWidth, 22), true, ui.WindowFlags.NoScrollbar) then
    Widgets.text(text)
    local maxScroll = ui.getScrollMaxX()
    if maxScroll > 0 and not ui.itemHovered() then
      local speed = 35
      local pause = 0.8
      local travel = maxScroll / speed
      local cycle = 2 * (pause + travel)
      local elapsed = (ui.time() + phase) % cycle
      local offset = 0
      if elapsed > pause and elapsed <= pause + travel then
        offset = (elapsed - pause) * speed
      elseif elapsed > pause + travel and elapsed <= 2 * pause + travel then
        offset = maxScroll
      elseif elapsed > 2 * pause + travel then
        offset = maxScroll - (elapsed - 2 * pause - travel) * speed
      end
      ui.setScrollX(offset, false, false)
    else
      ui.setScrollX(0, false, false)
    end
  end
  ui.endChild()
  ui.popStyleVar()
  ui.sameLine(0, 0)
  ui.setNextItemWidth(arrowWidth)
  -- Keyword rows share the same id, so the phase (row index) is part of the key.
  local openKey = id .. ':' .. tostring(phase)
  -- The combo flags are separate bits, so adding them works like OR. The width is kept between the selector width and 480 px.
  ui.setNextWindowSizeConstraints(vec2(width, 0), vec2(math.max(width, 480), 100000))
  if ui.beginCombo(id .. 'Dropdown', '', ui.ComboFlags.NoPreview + ui.ComboFlags.HeightLargest) then
	-- Rebuild the sound list once per opening, so files and folders added while settings are open show up.
	if not comboWasOpen[openKey] then
	  refreshAlertSoundFiles()
	  comboWasOpen[openKey] = true
	end
	if ui.beginChild(id .. 'List', vec2(0, soundPicker.listHeight()), false) then
	  drawOptions()
	end
	ui.endChild()
	ui.endCombo()
  else
	comboWasOpen[openKey] = false
  end
end

function soundPicker.folderOf(fileName)
  return (Sounds.alertSoundFileSet[fileName] or fileName):match('^(.*)\\[^\\]+$') or ''
end

function soundPicker.folderLabel(folder)
  return folder == '' and tr('(sounds root)') or folder
end

-- Sound dropdown: recent sounds, the default, then every sub-folder with its sounds. defaultValue is stored for the default entry.
function soundPicker.drawFile(id, selectedSound, width, phase, defaultValue, usedSounds, onPick)
  local isDefault = not selectedSound or selectedSound == defaultAlertSoundFile
  local defaultLabel = tr('Default (%s)', defaultAlertSoundFile)
  soundPicker.drawSelector(id, isDefault and defaultLabel or describeAlertSound(selectedSound), width, phase, function()
	  soundPicker.drawRecent(selectedSound, usedSounds, onPick)

	-- Draw default sound with diagnostic color (debug or normal depending on settings)
	local defaultColor = soundPicker.defaultColor()
	if defaultColor then ui.pushStyleColor(ui.StyleColor.Text, defaultColor) end
	if ui.selectable(defaultLabel, isDefault) then
	  onPick(defaultValue)
	end
	if defaultColor then ui.popStyleColor() end
	if isDefault then ui.setItemDefaultFocus() end

	for _, group in ipairs(soundPicker.groupedSounds()) do
	  Widgets.text(soundPicker.folderLabel(group.folder), rgbm(0.6, 0.6, 0.6, 1))
	  for _, fileName in ipairs(group.files) do
		soundPicker.drawSoundRow('list' .. fileName, fileName, fileName, selectedSound == fileName, usedSounds, onPick)
	  end
	  ui.separator()
	end
  end)
end

-- Debug colors, editable from the Tools tab and stored in settings as text.
local rowFrameDefault = rgbm(1, 0.5, 0, 1)
local function newDebugColors()
  return {
    background = rgbm(1, 1, 1, 1),
    childBg = rgbm(0, 0, 1, 0.9),
    scrollbarBg = rgbm(0, 1, 0, 1),
    usedSound = rgbm(1, 0.85, 0.2, 1),
    selectedSound = rgbm(1, 0.5, 0, 1),
    defaultSound = rgbm(1, 0.3, 0.8, 1),
    rowFrame = rowFrameDefault:clone(),
    buttonOverflow = sliders.defaults.buttonOverflow,
  }
end
local debugColors = newDebugColors()
-- Untouched copy of the default debug colours, shown read-only and used by the per-colour reset.
local debugColorDefaults = newDebugColors()

local debugColorKeys = { 'background', 'childBg', 'scrollbarBg', 'usedSound', 'selectedSound', 'defaultSound', 'rowFrame' }
  -- Colours switched off with their checkbox. A colour absent from this table is enabled.
  local debugColorDisabled = {}
-- Normal (non-debug) colour of each diagnostic colour, used while Diagnostic colors or its checkbox is off. Editable from the Tools tab and stored in settings as text.
local normalColorDefaults = {
  background = rgbm(0.14, 0.14, 0.14, 0.96),
  childBg = rgbm(0, 0, 0, 0),
  scrollbarBg = rgbm(0.02, 0.02, 0.02, 0.53),
  usedSound = rgbm(1, 0.85, 0.2, 1),
  selectedSound = rgbm(1, 0.5, 0, 1),
  defaultSound = rgbm(1, 0.3, 0.8, 1),
  rowFrame = rowFrameDefault:clone(),
}
local normalColors = {}
for key, value in pairs(normalColorDefaults) do normalColors[key] = value:clone() end

function Widgets.debugColorNormal(key)
  return normalColors[key]
end

function Widgets.debugColorDefault(key)
  return debugColorDefaults[key]
end

function Widgets.debugColorNormalDefault(key)
  return normalColorDefaults[key]
end

local function formatColor(c)
  return string.format('%.4f,%.4f,%.4f,%.4f', c.r, c.g, c.b, c.mult)
end

local function parseColor(value)
  local numbers = {}
  for number in value:gmatch('[%-%d%.]+') do numbers[#numbers + 1] = tonumber(number) end
  if #numbers == 4 then return rgbm(numbers[1], numbers[2], numbers[3], numbers[4]) end
end

local function encodeDebugColors()
  local parts = {}
  local disabled = {}
  for _, key in ipairs(debugColorKeys) do
    parts[#parts + 1] = key .. ':' .. formatColor(debugColors[key])
    if debugColorDisabled[key] then disabled[#disabled + 1] = key end
  end
  parts[#parts + 1] = string.format('buttonOverflow:%.2f', debugColors.buttonOverflow)
  if #disabled > 0 then parts[#parts + 1] = 'off:' .. table.concat(disabled, ',') end
  return table.concat(parts, ';')
end

local function decodeDebugColors(text)
  for key, value in text:gmatch('(%a+):([^;]*)') do
    if key == 'buttonOverflow' then
      debugColors.buttonOverflow = tonumber(value) or debugColors.buttonOverflow
    elseif key == 'off' then
      for disabledKey in value:gmatch('[^,]+') do debugColorDisabled[disabledKey] = true end
    elseif debugColors[key] then
      debugColors[key] = parseColor(value) or debugColors[key]
    end
  end
end

local function encodeNormalColors()
  local parts = {}
  for _, key in ipairs(debugColorKeys) do parts[#parts + 1] = key .. ':' .. formatColor(normalColors[key]) end
  return table.concat(parts, ';')
end

local function decodeNormalColors(text)
  for key, value in text:gmatch('(%a+):([^;]*)') do
    if normalColors[key] then normalColors[key] = parseColor(value) or normalColors[key] end
  end
end

local function saveDebugColors()
  local encoded = encodeDebugColors()
  if encoded ~= settings.debugColorsData then settings.debugColorsData = encoded end
  local encodedNormal = encodeNormalColors()
  if encodedNormal ~= settings.normalColorsData then settings.normalColorsData = encodedNormal end
end

decodeDebugColors(settings.debugColorsData)
decodeNormalColors(settings.normalColorsData)

-- Restores the default debug and normal colours and the debug checkboxes.
function Widgets.resetDebugColors()
  for key, value in pairs(newDebugColors()) do debugColors[key] = value end
  for key, value in pairs(normalColorDefaults) do normalColors[key] = value:clone() end
  for key in pairs(debugColorDisabled) do debugColorDisabled[key] = nil end
  saveDebugColors()
end

-- Restores one normal colour to its default and saves it.
function Widgets.resetNormalColor(key)
  normalColors[key] = normalColorDefaults[key]:clone()
  saveDebugColors()
end

-- Restores one debug colour to its default and saves it. Its checkbox is left unchanged.
function Widgets.resetDebugColor(key)
  debugColors[key] = debugColorDefaults[key]:clone()
  saveDebugColors()
end

-- The debug colour applies only while DEBUG mode, Diagnostic colors and its own checkbox are on; otherwise the normal colour is used.
local function debugColor(key)
  if Debug.colorsEnabled() and not debugColorDisabled[key] then return debugColors[key] end
  return normalColors[key]
end
Widgets.debugColor = debugColor

function Widgets.isDebugColorEnabled(key)
  return not debugColorDisabled[key]
end

function Widgets.setDebugColorEnabled(key, enabled)
  debugColorDisabled[key] = (not enabled) or nil
end

-- The debug colour applies only while DEBUG mode and Diagnostic colors are on; otherwise the normal colour is used.
function soundPicker.usedColor()
  return debugColor('usedSound')
end

-- The sound chosen for the alert being edited. It wins over the used colour, even when the same file is used elsewhere.
function soundPicker.selectedColor()
  return debugColor('selectedSound')
end

-- The default alert sound. Always shown with its diagnostic color (debug or normal depending on settings).
function soundPicker.defaultColor()
  return debugColor('defaultSound')
end

-- The keyword row frame is always shown; its debug colour applies only while DEBUG mode and Diagnostic colors are on.
function Widgets.rowFrameColor()
  return debugColor('rowFrame')
end

-- Draws a checkerboard (used behind colours to show their transparency).
local function drawChecker(topLeft, bottomRight)
  local square = 4
  local light = rgbm(0.8, 0.8, 0.8, 1)
  ui.drawRectFilled(topLeft, bottomRight, rgbm(0.5, 0.5, 0.5, 1))
  for row = 0, math.ceil((bottomRight.y - topLeft.y) / square) - 1 do
    for col = 0, math.ceil((bottomRight.x - topLeft.x) / square) - 1 do
      if (row + col) % 2 == 0 then
        local a = topLeft + vec2(col * square, row * square)
        ui.drawRectFilled(a, vec2(math.min(a.x + square, bottomRight.x), math.min(a.y + square, bottomRight.y)), light)
      end
    end
  end
end

-- Draws a checkerboard slightly larger than the color button (like the picker's alpha preview), then the button on top.
local function drawColorButton(id, color, flags)
  local size = vec2(32, 20)
  local pos = ui.getCursor()
  local grow = size * (debugColors.buttonOverflow / 100)
  drawChecker(pos - grow, pos + size + grow)
  ui.colorButton(id, color, flags, size)
end

-- Read-only swatch drawn with the same geometry as the editable colour buttons, checkerboard overflow included.
local function drawColorSwatch(color)
  local size = vec2(32, 20)
  local pos = ui.getCursor()
  local grow = size * (debugColors.buttonOverflow / 100)
  drawChecker(pos - grow, pos + size + grow)
  ui.drawRectFilled(pos, pos + size, color)
  ui.dummy(size)
end

local function resetColorSetting(key)
  settings[key] = colorDefaults[key]:clone()
end

local function isDefaultColor(key)
  local c, d = settings[key], colorDefaults[key]
  local eps = 0.001
  return math.abs(c.r - d.r) < eps and math.abs(c.g - d.g) < eps and math.abs(c.b - d.b) < eps and math.abs(c.mult - d.mult) < eps
end

local function drawColorLabel(label, key)
  local modified = not isDefaultColor(key)
  if modified then ui.pushStyleColor(ui.StyleColor.Text, sliders.modifiedColor) end
  Widgets.text(label)
  if modified then ui.popStyleColor(1) end
  ui.sameLine()
end

local function drawColorLabel(label, key)
  local modified = not isDefaultColor(key)
  if modified then ui.pushStyleColor(ui.StyleColor.Text, sliders.modifiedColor) end
  Widgets.text(label)
  if modified then ui.popStyleColor(1) end
  Widgets.settingTooltip(key, settings[key], colorDefaults[key])
  ui.sameLine()
end

local function drawColorSetting(label, key)
  drawColorLabel(label, key)
  drawColorButton('##color_' .. key, settings[key], ui.ColorPickerFlags.AlphaPreview)
  Widgets.settingTooltip(key, settings[key], colorDefaults[key])
  if ui.itemClicked(ui.MouseButton.Right, true) then
    resetColorSetting(key)
  end
  ui.itemPopup('##color_popup_' .. key, ui.MouseButton.Left, function()
	Widgets.text(tr('Choose %s', label:lower()))
	ui.colorPicker('##color_picker_' .. key, settings[key], bit.bor(
	  ui.ColorPickerFlags.AlphaBar,
	  ui.ColorPickerFlags.AlphaPreview,
	  ui.ColorPickerFlags.PickerHueWheel
	))
  end)
end

local function drawThemeColorSetting(label, key)
  drawColorLabel(label, key)
  drawColorButton('##color_' .. key, settings[key], ui.ColorPickerFlags.NoAlpha)
  Widgets.settingTooltip(key, settings[key], colorDefaults[key])
  if ui.itemClicked(ui.MouseButton.Right, true) then
    resetColorSetting(key)
  end
  ui.itemPopup('##color_popup_' .. key, ui.MouseButton.Left, function()
	Widgets.text(tr('Choose %s', label:lower()))
	local edited = ui.colorPicker('##color_picker_' .. key, settings[key], bit.bor(
	  ui.ColorPickerFlags.NoAlpha,
	  ui.ColorPickerFlags.PickerHueWheel
	))
	if edited then
	  settings[key] = rgbm(settings[key].r, settings[key].g, settings[key].b, 1)
	end
  end)
end

local function pushSettingsTheme()
  local color = settings.themeColor
  local bgColor = settings.themeBgColor
  local frameBg = rgbm(bgColor.r * 0.18, bgColor.g * 0.18, bgColor.b * 0.18, 0.96)
  local frameHovered = rgbm(bgColor.r * 0.28, bgColor.g * 0.28, bgColor.b * 0.28, 0.98)
  local frameActive = rgbm(bgColor.r * 0.38, bgColor.g * 0.38, bgColor.b * 0.38, 1)
  local button = rgbm(bgColor.r * 0.14, bgColor.g * 0.14, bgColor.b * 0.14, 0.92)
  local buttonHovered = rgbm(bgColor.r * 0.25, bgColor.g * 0.25, bgColor.b * 0.25, 0.96)
  local buttonActive = rgbm(bgColor.r * 0.35, bgColor.g * 0.35, bgColor.b * 0.35, 1)
  -- With Child background unticked in debug mode, the child area shows the normal band colour instead of letting the debug Background band show through.
  local childBg = debugColor('childBg')
  if Debug.colorsEnabled() and debugColorDisabled.childBg then childBg = normalColors.background end
  ui.pushStyleColor(ui.StyleColor.ChildBg, childBg)
  ui.pushStyleColor(ui.StyleColor.ScrollbarBg, debugColor('scrollbarBg'))
  ui.pushStyleColor(ui.StyleColor.FrameBg, frameBg)
  ui.pushStyleColor(ui.StyleColor.FrameBgHovered, frameHovered)
  ui.pushStyleColor(ui.StyleColor.FrameBgActive, frameActive)
  ui.pushStyleColor(ui.StyleColor.CheckMark, color)
  ui.pushStyleColor(ui.StyleColor.SliderGrab, color)
  ui.pushStyleColor(ui.StyleColor.SliderGrabActive, color)
  ui.pushStyleColor(ui.StyleColor.Button, button)
  ui.pushStyleColor(ui.StyleColor.ButtonHovered, buttonHovered)
  ui.pushStyleColor(ui.StyleColor.ButtonActive, buttonActive)
  ui.pushStyleColor(ui.StyleColor.Header, button)
  ui.pushStyleColor(ui.StyleColor.HeaderHovered, buttonHovered)
  ui.pushStyleColor(ui.StyleColor.HeaderActive, buttonActive)
  ui.pushStyleColor(ui.StyleColor.PopupBg, rgbm(bgColor.r * 0.1, bgColor.g * 0.1, bgColor.b * 0.1, 0.98))
  ui.pushStyleColor(ui.StyleColor.Border, rgbm(color.r, color.g, color.b, 0.28))
end

local function drawSoundFolderButton()
  ui.pushID('openSoundFolder')
  if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
    if io.dirExists(soundFolder) then
      local ok, err = pcall(os.openInExplorer, soundFolder)
      if ok then
        soundFolderStatus = ''
      else
        local message = 'Could not open the sounds folder: ' .. tostring(err)
        ac.log(App.displayName .. ': ' .. message)
        Debug.warn(message)
        soundFolderStatus = tr('Could not open the sounds folder: %s', tostring(err))
      end
    else
      local message = 'Sounds folder not found: ' .. soundFolder
      ac.log(App.displayName .. ': ' .. message)
      soundFolderStatus = tr('Sounds folder not found: %s', soundFolder)
    end
  end
  ui.popID()
  ui.sameLine()
  Widgets.text(tr('Open sounds folder'))
  if soundFolderStatus ~= '' then Widgets.textWrapped(soundFolderStatus) end
end

local flagWidth, flagHeight = 50, 30
local resetIconSize = flagHeight * 0.75

local function drawLanguageSelector(id, label)
  local language = modules.i18n.currentLanguage()
  local shownName = modules.i18n.languageName(language)
  if language.code == 'auto' then shownName = shownName .. ' (' .. modules.i18n.activeLanguage().name .. ')' end
  Widgets.text(label or tr('Language'))
  ui.sameLine()
  ui.setNextItemWidth(230)
  if ui.beginCombo(id, shownName) then
    for _, option in ipairs(modules.i18n.languages) do
      if ui.selectable(modules.i18n.languageName(option), option.code == language.code) then
        modules.i18n.setLanguage(option.code)
      end
    end
    ui.endCombo()
  end
  ui.sameLine()
  ui.alignTextToFramePadding()
  Widgets.text('Reset:')
  ui.sameLine()
  if ui.iconButton(ui.Icons.Reset, vec2(resetIconSize, resetIconSize), rgbm(1, 1, 1, 1), rgbm(0, 0, 0, 0)) then
    modules.i18n.setLanguage('auto')
  end
  ui.sameLine()
  ui.image('flag_en.png', vec2(flagWidth, flagHeight))
  if ui.itemClicked(ui.MouseButton.Left, true) then modules.i18n.setLanguage('en') end
end

-- Native title text cannot be coloured, so the marker is drawn in the title row, right after it.
-- The offsets are estimates: adjust them after an in-game check.
local titleMarkerColor = rgbm(1, 0.36, 0.2, 1)
local titleMarkerStartX = 14
local titleMarkerY = 2

local function drawTitleMarker()
  local cursorX, cursorY = ui.getCursorX(), ui.getCursorY()
  ui.setCursorX(titleMarkerStartX + ui.windowTitleWidth() + 6)
  ui.setCursorY(titleMarkerY)
  ui.textColored('◉', titleMarkerColor)
  ui.setCursorX(cursorX)
  ui.setCursorY(cursorY)
end

Widgets.drawTitleMarker = drawTitleMarker
Widgets.comboWasOpen = comboWasOpen
Widgets.sliders = sliders
Widgets.soundPicker = soundPicker
Widgets.debugColors = debugColors
Widgets.saveDebugColors = saveDebugColors
Widgets.drawColorButton = drawColorButton
Widgets.drawColorSwatch = drawColorSwatch
Widgets.drawColorSetting = drawColorSetting
Widgets.drawThemeColorSetting = drawThemeColorSetting
Widgets.pushSettingsTheme = pushSettingsTheme
Widgets.drawSoundFolderButton = drawSoundFolderButton
Widgets.drawLanguageSelector = drawLanguageSelector

return Widgets
