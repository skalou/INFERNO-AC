-- Shared UI widgets: sliders and checkboxes with defaults, sound picker, colour buttons, settings theme.
local modules = require('core.modules')
local Sounds = modules.sounds
local Widgets = modules.widgets

local defaultAlertSoundFile = modules.paths.defaultAlertSoundFile
local App = modules.paths.App
local soundFolder = modules.paths.soundFolder
local settings = modules.settings.settings
local Debug = modules.debug.Debug
local playAlertSound = modules.sounds.playAlertSound
local isSoundTestPlaying = modules.sounds.isSoundTestPlaying
local refreshAlertSoundFiles = modules.sounds.refreshAlertSoundFiles
local describeAlertSound = modules.sounds.describeAlertSound

local soundFolderStatus = ''
local comboWasOpen = {}

-- Slider and checkbox defaults and helpers, grouped in one table because Lua allows only 200 locals per chunk.
local sliders = {
  defaults = {
    masterVolume = 100,
    keywordVolume = 100,
    textSize = 48,
    duration = 3.0,
    opacity = 75,
    outlineThicknessPercent = 8,
    buttonOverflow = 5,
    soundEnabled = true,
    mentionMe = true,
    showAllChatMessages = false,
    hideWhenNotHovered = false,
    backgroundEnabled = false,
    softOutline = false,
    useVehicleDisplayProfiles = false,
    useServerKeywordProfiles = false,
    autoSaveServerSettings = false,
    debugModeEnabled = true,
    simulatorFriend = false,
  },
  modifiedColor = rgbm(1, 1, 0.4, 1),
  modifiedCheckMark = rgbm(0, 0, 0, 1),
}

-- Right-click (on release) restores the default, the label turns yellow while the value differs, the mouse wheel moves by `step`.
function sliders.withDefault(label, value, min, max, format, default, step)
  local modified = math.abs(value - default) > 0.0001
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
  return newValue
end

-- Checkbox whose box and label turn yellow while its value differs from the default; returns true when clicked, like ui.checkbox.
function sliders.checkbox(label, value, default)
  local modified = value ~= default
  if modified then
    ui.pushStyleColor(ui.StyleColor.FrameBg, sliders.modifiedColor)
    ui.pushStyleColor(ui.StyleColor.FrameBgHovered, sliders.modifiedColor)
    ui.pushStyleColor(ui.StyleColor.FrameBgActive, sliders.modifiedColor)
    ui.pushStyleColor(ui.StyleColor.CheckMark, sliders.modifiedCheckMark)
    ui.pushStyleColor(ui.StyleColor.Text, sliders.modifiedColor)
  end
  local clicked = ui.checkbox(label, value)
  if modified then ui.popStyleColor(5) end
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
  ui.textColored('Recent Sounds', rgbm(0.6, 0.6, 0.6, 1))
  if #names == 0 then
	ui.textColored('No recent sounds yet, pick one below', rgbm(0.45, 0.45, 0.45, 1))
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

-- Sounds other than the default, grouped by sub-folder (the root first), in the same order as the folder dropdown.
function soundPicker.groupedSounds()
  local groups = {}
  local byFolder = {}
  for _, fileName in ipairs(Sounds.alertSoundFiles) do
	if fileName ~= defaultAlertSoundFile then
	  local folder = soundPicker.folderOf(fileName)
	  if not byFolder[folder] then
		byFolder[folder] = { folder = folder, files = {} }
		groups[#groups + 1] = byFolder[folder]
	  end
	  table.insert(byFolder[folder].files, fileName)
	end
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
    ui.text(text)
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
  return folder == '' and '(sounds root)' or folder
end

-- Sound dropdown: recent sounds, the default, then every sub-folder with its sounds. defaultValue is stored for the default entry.
function soundPicker.drawFile(id, selectedSound, width, phase, defaultValue, usedSounds, onPick)
  local isDefault = not selectedSound or selectedSound == defaultAlertSoundFile
  local defaultLabel = 'Default (' .. defaultAlertSoundFile .. ')'
  soundPicker.drawSelector(id, isDefault and defaultLabel or describeAlertSound(selectedSound), width, phase, function()
	  soundPicker.drawRecent(selectedSound, usedSounds, onPick)
	if ui.selectable(defaultLabel, isDefault) then
	  onPick(defaultValue)
	end
	if isDefault then ui.setItemDefaultFocus() end
	for _, group in ipairs(soundPicker.groupedSounds()) do
	  ui.textColored(soundPicker.folderLabel(group.folder), rgbm(0.6, 0.6, 0.6, 1))
	  for _, fileName in ipairs(group.files) do
		soundPicker.drawSoundRow('list' .. fileName, fileName, fileName, selectedSound == fileName, usedSounds, onPick)
	  end
	  ui.separator()
	end
  end)
end

-- Debug colors, editable from the Tools tab and stored in settings as text.
local debugColors = {
  background = rgbm(1, 1, 1, 1),
  childBg = rgbm(0, 0, 1, 0.9),
  scrollbarBg = rgbm(0, 1, 0, 1),
  resizeGrip = rgbm(1, 0.2, 0.8, 1),
  usedSound = rgbm(1, 0.85, 0.2, 1),
  selectedSound = rgbm(1, 0.5, 0, 1),
  buttonOverflow = sliders.defaults.buttonOverflow,
}

local function encodeDebugColors()
  local parts = {}
  for _, key in ipairs({ 'background', 'childBg', 'scrollbarBg', 'resizeGrip', 'usedSound', 'selectedSound' }) do
    local c = debugColors[key]
    parts[#parts + 1] = string.format('%s:%.4f,%.4f,%.4f,%.4f', key, c.r, c.g, c.b, c.mult)
  end
  parts[#parts + 1] = string.format('buttonOverflow:%.2f', debugColors.buttonOverflow)
  return table.concat(parts, ';')
end

local function decodeDebugColors(text)
  for key, value in text:gmatch('(%a+):([^;]*)') do
    if key == 'buttonOverflow' then
      debugColors.buttonOverflow = tonumber(value) or debugColors.buttonOverflow
    elseif debugColors[key] then
      local numbers = {}
      for number in value:gmatch('[%-%d%.]+') do numbers[#numbers + 1] = tonumber(number) end
      if #numbers == 4 then debugColors[key] = rgbm(numbers[1], numbers[2], numbers[3], numbers[4]) end
    end
  end
end

local function saveDebugColors()
  local encoded = encodeDebugColors()
  if encoded ~= settings.debugColorsData then settings.debugColorsData = encoded end
end

decodeDebugColors(settings.debugColorsData)

-- The debug colour applies only while Debug mode is on; otherwise the default yellow is used.
function soundPicker.usedColor()
  return settings.debugModeEnabled and debugColors.usedSound or rgbm(1, 0.85, 0.2, 1)
end

-- The sound chosen for the alert being edited. It wins over the used colour, even when the same file is used elsewhere.
function soundPicker.selectedColor()
  return settings.debugModeEnabled and debugColors.selectedSound or rgbm(1, 0.5, 0, 1)
end

-- Draws a checkerboard slightly larger than the color button (like the picker's alpha preview), then the button on top.
local function drawColorButton(id, color, flags)
  local size = vec2(32, 20)
  local pos = ui.getCursor()
  local grow = size * (debugColors.buttonOverflow / 100)
  local topLeft = pos - grow
  local bottomRight = pos + size + grow
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
  ui.colorButton(id, color, flags, size)
end

local function drawColorSetting(label, key)
  ui.text(label)
  ui.sameLine()
  drawColorButton('##color_' .. key, settings[key], ui.ColorPickerFlags.AlphaPreview)
  ui.itemPopup('##color_popup_' .. key, ui.MouseButton.Left, function()
	ui.text('Choose ' .. label:lower())
	ui.colorPicker('##color_picker_' .. key, settings[key], bit.bor(
	  ui.ColorPickerFlags.AlphaBar,
	  ui.ColorPickerFlags.AlphaPreview,
	  ui.ColorPickerFlags.PickerHueWheel
	))
  end)
end

local function drawThemeColorSetting(label, key)
  ui.text(label)
  ui.sameLine()
  drawColorButton('##color_' .. key, settings[key], ui.ColorPickerFlags.NoAlpha)
  ui.itemPopup('##color_popup_' .. key, ui.MouseButton.Left, function()
	ui.text('Choose ' .. label:lower())
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
  ui.pushStyleColor(ui.StyleColor.ChildBg, settings.debugModeEnabled and debugColors.childBg or rgbm(0, 0, 0, 0))
  ui.pushStyleColor(ui.StyleColor.ScrollbarBg, settings.debugModeEnabled and debugColors.scrollbarBg or rgbm(0.02, 0.02, 0.02, 0.53))
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
  local grip = settings.debugModeEnabled and debugColors.resizeGrip or rgbm(color.r, color.g, color.b, 0.45)
  ui.pushStyleColor(ui.StyleColor.ResizeGrip, grip)
  ui.pushStyleColor(ui.StyleColor.ResizeGripHovered, rgbm(grip.r, grip.g, grip.b, 0.8))
  ui.pushStyleColor(ui.StyleColor.ResizeGripActive, rgbm(grip.r, grip.g, grip.b, 1))
end

local function drawSoundFolderButton()
  ui.pushID('openSoundFolder')
  if ui.iconButton(ui.Icons.Folder, vec2(22, 22)) then
    if io.dirExists(soundFolder) then
      local ok, err = pcall(os.openInExplorer, soundFolder)
      if ok then
        soundFolderStatus = ''
      else
        soundFolderStatus = 'Could not open the sounds folder: ' .. tostring(err)
        ac.log(App.displayName .. ': ' .. soundFolderStatus)
    Debug.warn(soundFolderStatus)
      end
    else
      soundFolderStatus = 'Sounds folder not found: ' .. soundFolder
      ac.log(App.displayName .. ': ' .. soundFolderStatus)
    end
  end
  ui.popID()
  ui.sameLine()
  ui.text('Open sounds folder')
  if soundFolderStatus ~= '' then ui.textWrapped(soundFolderStatus) end
end

Widgets.comboWasOpen = comboWasOpen
Widgets.sliders = sliders
Widgets.soundPicker = soundPicker
Widgets.debugColors = debugColors
Widgets.saveDebugColors = saveDebugColors
Widgets.drawColorButton = drawColorButton
Widgets.drawColorSetting = drawColorSetting
Widgets.drawThemeColorSetting = drawThemeColorSetting
Widgets.pushSettingsTheme = pushSettingsTheme
Widgets.drawSoundFolderButton = drawSoundFolderButton

return Widgets
