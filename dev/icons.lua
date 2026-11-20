-- Developer tools window (manifest window "dev"): browse the icons available through ui.Icons.
-- Formerly the separate INFERNO-DEV app.
local modules = require('core.modules')
local DevTools = modules.dev

local icons = nil
local iconFilter = ''
local lastCopied = nil

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

local function drawInfoTab()
  ui.text('INFERNO-DEV')
  ui.text('Icons listed: ' .. #icons)
  ui.text('CSP version: ' .. (ac.getPatchVersion and ac.getPatchVersion() or 'unknown'))
  ui.separator()
  ui.textWrapped('Use an icon in any app with: ui.icon(ui.Icons.Name, vec2(24, 24))')
end

function DevTools.windowDev(dt)
  if not icons then icons = loadIcons() end
  ui.tabBar('devTabs', function()
    ui.tabItem('Icons', drawIconsTab)
    ui.tabItem('Info', drawInfoTab)
  end)
end

return DevTools
