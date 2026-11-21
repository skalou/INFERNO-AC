-- Settings window, History tab, and the history list shown in Tools.
local modules = require('core.modules')
local HistoryTab = modules.historyTab
local Widgets = modules.widgets
local tr = modules.i18n.tr

local alertHistory = modules.history.alertHistory

-- Lists the session's alerts, newest first. Used by the History tab and Tools > Debug (limit 3).
function alertHistory.drawEntries(limit)
  local grey = rgbm(0.6, 0.6, 0.6, 1)
  if #alertHistory.items == 0 then
    Widgets.text(tr('No alerts triggered yet this session.'), grey)
    return
  end
  local firstIndex = math.max(1, #alertHistory.items - (limit or #alertHistory.items) + 1)
  for i = #alertHistory.items, firstIndex, -1 do
    local entry = alertHistory.items[i]
    Widgets.text(entry.time .. '  ' .. entry.trigger, rgbm(1, 1, 1, 1))
    ui.sameLine(0, 10)
    ui.icon(entry.hidden and ui.Icons.Hide or ui.Icons.Eye, 14)
    ui.sameLine(0, 4)
    Widgets.text(entry.hidden and tr('no popup') or tr('popup'), grey)
    ui.sameLine(0, 10)
    ui.icon(entry.muted and ui.Icons.Mute or ui.Icons.VolumeHigh, 14)
    ui.sameLine(0, 4)
    Widgets.text((entry.muted and (tr('muted') .. ', ') or '') .. entry.soundName, grey)
    Widgets.text(entry.author, entry.authorColor)
    ui.pushStyleColor(ui.StyleColor.Text, entry.textColor)
    Widgets.textWrapped(entry.message)
    ui.popStyleColor()
    for _, event in ipairs(entry.events) do
      Widgets.text('  ' .. event.time .. '  ' .. event.text, grey)
    end
    ui.separator()
  end
end

-- Copy and clear for the History tab.
function alertHistory.drawTab()
  Widgets.textWrapped(tr('%d of %d alerts this session. Kept in memory only and cleared when the app closes.', #alertHistory.items, alertHistory.max))
  if ui.button(tr('Copy history'), vec2(-0.1, 0)) then
    local lines = {}
    for _, entry in ipairs(alertHistory.items) do
      table.insert(lines, alertHistory.formatEntry(entry))
    end
    ac.setClipboardText(table.concat(lines, '\n'))
  end
  if ui.button(tr('Clear history'), vec2(-0.1, 0)) then
    alertHistory.clear()
  end
  ui.separator()
  alertHistory.drawEntries()
end

return HistoryTab
