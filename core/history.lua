-- Alerts triggered this session (memory only).
local modules = require('core.modules')
local Alert = modules.alert
local History = modules.history

-- Alerts triggered this session, newest last. Kept in memory only and cleared when the app closes.
local alertHistory = { items = {}, max = 100, current = nil }

function alertHistory.add(entry)
  entry.events = {}
  table.insert(alertHistory.items, entry)
  while #alertHistory.items > alertHistory.max do
    table.remove(alertHistory.items, 1)
  end
  return entry
end

function alertHistory.addEvent(entry, text)
  if not entry then return end
  table.insert(entry.events, { time = os.date('%H:%M:%S'), text = text })
end

-- A newer popup replaces the one still on screen, so the older entry gets a note.
function alertHistory.popupReplaced()
  if alertHistory.current and Alert.alertTimeLeft > 0 then
    alertHistory.addEvent(alertHistory.current, 'Replaced on screen by a newer alert')
  end
end

function alertHistory.clear()
  alertHistory.items = {}
  alertHistory.current = nil
end

function alertHistory.formatEntry(entry)
  local visual = entry.hidden and 'no popup' or 'popup'
  local audio = entry.muted and 'muted' or 'sound'
  local lines = { entry.time .. ' [' .. entry.trigger .. '] ' .. entry.author .. ' : ' .. entry.message, '  ' .. visual .. ' | ' .. audio .. ': ' .. entry.soundName }
  for _, event in ipairs(entry.events) do
    table.insert(lines, '  ' .. event.time .. '  ' .. event.text)
  end
  return table.concat(lines, '\n')
end

History.alertHistory = alertHistory

return History
