-- INFERNO-DEV - developer app: browse the icons available through ui.Icons.
-- Standalone CSP app (apps\lua\INFERNO-DEV), independent from INFERNO-ChatAlerts.

local icons = nil
local iconFilter = ''
local lastCopied = nil
local lastSymbolCopied = nil

-- Sample of Unicode symbols usable as text: { character, code point }.
local symbolGroups = {
  { 'Cercles et formes', {
    { '●', 'U+25CF' }, { '○', 'U+25CB' }, { '◉', 'U+25C9' }, { '◎', 'U+25CE' }, { '◐', 'U+25D0' }, { '◑', 'U+25D1' },
    { '■', 'U+25A0' }, { '□', 'U+25A1' }, { '▲', 'U+25B2' }, { '△', 'U+25B3' }, { '▼', 'U+25BC' }, { '▽', 'U+25BD' },
    { '◆', 'U+25C6' }, { '◇', 'U+25C7' },
  } },
  { 'Étoiles et puces', {
    { '★', 'U+2605' }, { '☆', 'U+2606' }, { '✦', 'U+2726' }, { '✧', 'U+2727' }, { '•', 'U+2022' }, { '·', 'U+00B7' },
  } },
  { 'Flèches', {
    { '→', 'U+2192' }, { '←', 'U+2190' }, { '↑', 'U+2191' }, { '↓', 'U+2193' }, { '↔', 'U+2194' },
    { '⇒', 'U+21D2' }, { '⇐', 'U+21D0' }, { '➜', 'U+279C' }, { '➤', 'U+27A4' },
  } },
  { 'Coches et croix', {
    { '✓', 'U+2713' }, { '✔', 'U+2714' }, { '✗', 'U+2717' }, { '✘', 'U+2718' }, { '✕', 'U+2715' }, { '✖', 'U+2716' },
  } },
  { 'Alertes et divers', {
    { '⚠', 'U+26A0' }, { '⚙', 'U+2699' }, { '♪', 'U+266A' }, { '♫', 'U+266B' },
    { '♠', 'U+2660' }, { '♣', 'U+2663' }, { '♥', 'U+2665' }, { '♦', 'U+2666' },
  } },
  { 'Ponctuation et maths', {
    { '–', 'U+2013' }, { '—', 'U+2014' }, { '…', 'U+2026' }, { '°', 'U+00B0' }, { '±', 'U+00B1' }, { '×', 'U+00D7' },
    { '÷', 'U+00F7' }, { '≈', 'U+2248' }, { '≠', 'U+2260' }, { '≤', 'U+2264' }, { '≥', 'U+2265' }, { '∞', 'U+221E' },
  } },
}

local function loadIcons()
  local list = {}
  for name, id in pairs(ui.Icons or {}) do
    list[#list + 1] = { name = name, id = id }
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

local function matchesFilter(name)
  if iconFilter == '' then return true end
  return string.find(string.lower(name), string.lower(iconFilter), 1, true) ~= nil
end

local function drawIconsTab()
  ui.textWrapped('Click an icon to copy its ui.Icons name to the clipboard.')
  ui.text('Filter')
  ui.setNextItemWidth(math.max(40, ui.availableSpaceX()))
  iconFilter = ui.inputText('##iconFilter', iconFilter)

  local shown = {}
  for _, icon in ipairs(icons) do
    if matchesFilter(icon.name) then shown[#shown + 1] = icon end
  end
  ui.text(#shown .. ' of ' .. #icons .. ' icons')
  if lastCopied then
    ui.textColored('Copied: ' .. lastCopied, rgbm(0.3, 1, 0.3, 1))
  end
  ui.separator()

  local columns = math.max(1, math.floor(ui.availableSpaceX() / 48))
  for i, icon in ipairs(shown) do
    ui.pushID(icon.name)
    if ui.iconButton(icon.id, vec2(32, 32)) then
      lastCopied = 'ui.Icons.' .. icon.name
      ac.setClipboardText(lastCopied)
    end
    if ui.itemHovered() then ui.setTooltip('ui.Icons.' .. icon.name) end
    ui.popID()
    if i % columns ~= 0 and i < #shown then ui.sameLine() end
  end
end

local function drawSymbolsTab()
  ui.textWrapped('Click a symbol to copy it. An empty box means the glyph is not in the CSP font.')
  if lastSymbolCopied then
    ui.textColored('Copied: ' .. lastSymbolCopied, rgbm(0.3, 1, 0.3, 1))
  end

  local columns = math.max(1, math.floor(ui.availableSpaceX() / 48))
  for _, group in ipairs(symbolGroups) do
    ui.separator()
    ui.text(group[1])
    local symbols = group[2]
    for i, symbol in ipairs(symbols) do
      ui.pushID(symbol[2])
      if ui.button(symbol[1], vec2(36, 36)) then
        lastSymbolCopied = symbol[1] .. '  (' .. symbol[2] .. ')'
        ac.setClipboardText(symbol[1])
      end
      if ui.itemHovered() then ui.setTooltip(symbol[2]) end
      ui.popID()
      if i % columns ~= 0 and i < #symbols then ui.sameLine() end
    end
  end
end

local function drawInfoTab()
  ui.text('INFERNO-DEV')
  ui.text('Icons listed: ' .. #icons)
  ui.text('CSP version: ' .. (ac.getPatchVersion and ac.getPatchVersion() or 'unknown'))
  ui.separator()
  ui.textWrapped('Use an icon in any app with: ui.icon(ui.Icons.Name, vec2(24, 24))')
end

-- Window callback named in manifest.ini (FUNCTION_MAIN).
-- Same title marker as INFERNO-ChatAlerts (kept local: this app is standalone).
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

function windowDev(dt)
  drawTitleMarker()
  if not icons then icons = loadIcons() end
  ui.tabBar('devTabs', function()
    ui.tabItem('Icons', drawIconsTab)
    ui.tabItem('Symbols', drawSymbolsTab)
    ui.tabItem('Info', drawInfoTab)
  end)
end
