-- Alert popup window (manifest window "main").
local modules = require('core.modules')
local tr = modules.i18n.tr
local Alert = modules.alert
local AlertWindow = modules.alertWindow

local settings = modules.settings.settings
local maxOutlineScale = modules.settings.maxOutlineScale
local invalidatePlayerNameCache = modules.keywords.invalidatePlayerNameCache
local syncVehicleDisplayProfile = modules.profiles.syncVehicleDisplayProfile
local syncKeywordProfile = modules.profiles.syncKeywordProfile
local drawTitleMarker = modules.widgets.drawTitleMarker

local measuredTextSize = nil
local measuredTextWidth = nil
local measuredFontSize = nil
local measuredTextHeight = 0
local measuredAuthorPrefix = nil
local measuredAuthorWidth = 0
local lastWindowPos = nil

local function drawAlert(message, isPreview, dt, showInteractionBackground)
  if message == '' then
	return
  end

  local fade = isPreview and 1 or math.min(1, (Alert.alertDuration - Alert.alertTimeLeft) / 0.5, Alert.alertTimeLeft / 0.5)
  local opacity = settings.opacity / 100 * math.max(0, fade)
  local cursor = ui.getCursor()
  local available = ui.availableSpace()
  local inset = 10
  local textWidth = math.max(40, available.x - inset * 2 - 5)

  ui.pushDWriteFont('@System')
  local fontSize = ui.fontSize()
  if Alert.measuredMessage ~= message or measuredTextSize ~= settings.textSize
	  or measuredTextWidth ~= textWidth or measuredFontSize ~= fontSize then
	Alert.measuredMessage = message
    measuredTextSize = settings.textSize
    measuredTextWidth = textWidth
    measuredFontSize = fontSize
    measuredTextHeight = math.max(fontSize, ui.measureDWriteText(message, settings.textSize, textWidth).y)
    local separator = message:find(' : ', 1, true)
    measuredAuthorPrefix = separator and message:sub(1, separator + 1) or nil
    measuredAuthorWidth = measuredAuthorPrefix and ui.measureDWriteText(measuredAuthorPrefix, settings.textSize).x or 0
  end
  local textHeight = measuredTextHeight
  local textViewportHeight = math.max(1, available.y - inset * 2)
  local maxScroll = math.max(0, textHeight - textViewportHeight)
  local scrollOffset = 0
  -- Pause at each end of the scroll cycle so long alerts remain readable.
  if maxScroll > 0 then
    if not Alert.firstScrollRequired then
      Alert.firstScrollComplete = false
      Alert.textScrollElapsed = 0
    end
    Alert.firstScrollRequired = true
    Alert.textScrollElapsed = Alert.textScrollElapsed + dt
    local speed = 28
    local pause = 0.8
    local travel = maxScroll / speed
    local cycle = 2 * (pause + travel)
    local timeInCycle = Alert.textScrollElapsed % cycle
    if Alert.textScrollElapsed >= pause + travel then
      Alert.firstScrollComplete = true
    end
    if timeInCycle > pause and timeInCycle <= pause + travel then
      scrollOffset = (timeInCycle - pause) * speed
    elseif timeInCycle > pause + travel and timeInCycle <= 2 * pause + travel then
      scrollOffset = maxScroll
    elseif timeInCycle > 2 * pause + travel then
      scrollOffset = maxScroll - (timeInCycle - 2 * pause - travel) * speed
    end
  else
    Alert.firstScrollRequired = false
    Alert.firstScrollComplete = true
    Alert.textScrollElapsed = 0
  end
  if settings.backgroundEnabled then
	ui.drawRectFilled(cursor, cursor + available, rgbm(
	  settings.backgroundColor.r,
	  settings.backgroundColor.g,
	  settings.backgroundColor.b,
	  settings.backgroundColor.mult * opacity
	), 0)
  elseif showInteractionBackground then
	ui.drawRectFilled(cursor, cursor + available, rgbm(0.35, 0.35, 0.35, 0.45), 0)
  end
  ui.drawRectFilled(cursor, vec2(cursor.x + 5, cursor.y + available.y), rgbm(
	settings.accentColor.r,
	settings.accentColor.g,
	settings.accentColor.b,
	settings.accentColor.mult * opacity
  ), 0)

  local textStart = cursor + vec2(inset + 5, inset - scrollOffset)
  local textEnd = vec2(textStart.x + textWidth, textStart.y + textHeight)
  local function drawTextPass(textAlpha, outlineAlpha, outlineScale)
	if settings.outlineThicknessPercent > 0 then
	  ui.beginOutline()
	end
	ui.dwriteDrawTextClipped(
	  message,
	  settings.textSize,
	  textStart,
	  textEnd,
	  ui.Alignment.Start,
	  ui.Alignment.Start,
	  true,
	  rgbm(
		settings.textColor.r,
		settings.textColor.g,
		settings.textColor.b,
		settings.textColor.mult * opacity * textAlpha
	  )
	)
	if settings.outlineThicknessPercent > 0 then
	  ui.endOutline(rgbm(
		settings.outlineColor.r,
		settings.outlineColor.g,
		settings.outlineColor.b,
		settings.outlineColor.mult * opacity * outlineAlpha
	  ), math.min(maxOutlineScale, outlineScale))
	end
  end

  local outlineScale = math.min(maxOutlineScale, settings.outlineThicknessPercent * settings.textSize / 100)
  if settings.softOutline and outlineScale > 0 then
	drawTextPass(0.15, 0.2, outlineScale * 2)
	drawTextPass(0.45, 0.5, outlineScale * 1.4)
  end
  drawTextPass(1, 1, outlineScale)
  local prefixColor = Alert.latestAuthorColor or settings.authorColor
  if measuredAuthorPrefix and measuredAuthorWidth <= textWidth then
    ui.dwriteDrawTextClipped(
      measuredAuthorPrefix,
      settings.textSize,
      textStart,
      textEnd,
      ui.Alignment.Start,
      ui.Alignment.Start,
      true,
      rgbm(
        prefixColor.r,
        prefixColor.g,
        prefixColor.b,
        prefixColor.mult * opacity
      )
    )
  end
  ui.popDWriteFont()
end

local function windowMain(dt)
  drawTitleMarker()
  if Alert.testMessagePending then
	Alert.testMode = Alert.testMessagePending.mode
	Alert.latestMessage = Alert.testMessagePending.message
	Alert.latestAuthorColor = nil
	Alert.alertTimeLeft = Alert.testMessagePending.duration
	Alert.measuredMessage = nil
	Alert.textScrollElapsed = 0
	Alert.firstScrollRequired = false
	Alert.firstScrollComplete = false
	Alert.testMessagePending = nil
  end

  invalidatePlayerNameCache()
  syncVehicleDisplayProfile()
  syncKeywordProfile()

  local windowPos = ui.windowPos()
  local mouseDown = ui.mouseDown()
  local hovered = ui.windowHovered()
  local moving = mouseDown and lastWindowPos ~= nil
	  and (windowPos.x ~= lastWindowPos.x or windowPos.y ~= lastWindowPos.y)

  local showInteractionBackground = moving or (hovered and mouseDown)
  lastWindowPos = vec2(windowPos.x, windowPos.y)

  if Alert.alertTimeLeft > 0 then
	Alert.alertTimeLeft = math.max(0, Alert.alertTimeLeft - (dt or 0))
	-- Keep the alert up until its first slow scroll has played, for real alerts as well as previews.
	if Alert.firstScrollRequired and not Alert.firstScrollComplete then
	  Alert.alertTimeLeft = math.max(Alert.alertTimeLeft, 0.5)
	end
  end

  local resizing = ui.windowResizing()
  local normalAlert = Alert.alertTimeLeft > 0 and not Alert.testMode
  if normalAlert and not settings.hideWhenNotHovered then
	-- Only reveal the title bar while the pointer is on the window, so the alert shows alone otherwise.
	if hovered or resizing or moving then
	  ac.forceFadingIn()
	end
	drawAlert(Alert.latestMessage, false, dt or 0, showInteractionBackground)
	return
  end

  if normalAlert then
	if hovered or resizing or moving then
	  ac.forceFadingIn()
	  drawAlert(Alert.latestMessage, false, dt or 0, showInteractionBackground)
	end
	return
  end

  if settings.hideWhenNotHovered and not hovered and not resizing and not moving and not Alert.testMode then
	return
  end

  if Alert.testMode or hovered or resizing or moving then
	ac.forceFadingIn()
  end

	if Alert.testMode then
	drawAlert(Alert.latestMessage, true, dt or 0, showInteractionBackground)
  elseif hovered or resizing or moving then
	local ownName = ac.getDriverName(0) or 'Driver'
	local hoverPreviewMessage = ownName:sub(1, 15) .. ' : ' .. tr('Chat preview - move or resize this window to position your alert.')
	drawAlert(hoverPreviewMessage, true, dt or 0, showInteractionBackground)
  end
end

AlertWindow.windowMain = windowMain

return AlertWindow
