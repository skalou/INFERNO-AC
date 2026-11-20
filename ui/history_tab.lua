-- Settings window, History tab, and the history list shown in Tools.
local modules = require('core.modules')
local HistoryTab = modules.historyTab

local alertHistory = modules.history.alertHistory

-- Lists the session's alerts, newest first. Used by the History tab and Tools > Debug.
function alertHistory.drawEntries()
  local grey = rgbm(0.6, 0.6, 0.6, 1)
  if #alertHistory.items == 0 then
    ui.textColored('No alerts triggered yet this session.', grey)
    return
  end
  for i = #alertHistory.items, 1, -1 do
    local entry = alertHistory.items[i]
    ui.textColored(entry.time .. '  ' .. entry.trigger, rgbm(1, 1, 1, 1))
    ui.sameLine(0, 10)
    ui.icon(entry.hidden and ui.Icons.Hide or ui.Icons.Eye, 14)
    ui.sameLine(0, 4)
    ui.textColored(entry.hidden and 'no popup' or 'popup', grey)
    ui.sameLine(0, 10)
    ui.icon(entry.muted and ui.Icons.Mute or ui.Icons.VolumeHigh, 14)
    ui.sameLine(0, 4)
    ui.textColored((entry.muted and 'muted, ' or '') .. entry.soundName, grey)
    ui.textColored(entry.author, entry.authorColor)
    ui.pushStyleColor(ui.StyleColor.Text, entry.textColor)
    ui.textWrapped(entry.message)
    ui.popStyleColor()
    for _, event in ipairs(entry.events) do
      ui.textColored('  ' .. event.time .. '  ' .. event.text, grey)
    end
    ui.separator()
  end
end

-- Copy and clear for the History tab.
function alertHistory.drawTab()
  ui.textWrapped(#alertHistory.items .. ' of ' .. alertHistory.max .. ' alerts this session. Kept in memory only and cleared when the app closes.')
  if ui.button('Copy history', vec2(-0.1, 0)) then
    local lines = {}
    for _, entry in ipairs(alertHistory.items) do
      table.insert(lines, alertHistory.formatEntry(entry))
    end
    ac.setClipboardText(table.concat(lines, '\n'))
  end
  if ui.button('Clear history', vec2(-0.1, 0)) then
    alertHistory.clear()
  end
  ui.separator()
  alertHistory.drawEntries()
end

return HistoryTab
