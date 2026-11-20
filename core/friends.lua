-- Friends list: tagged friends on the server, saved to Friends\friends.json.
local modules = require('core.modules')
local Friends = modules.friends

local App = modules.paths.App

-- Friends come from CSP's friend tags (same source as comfy_map). Only online races have other players, so solo sessions get an empty list. Car 0 is the player's own car and is skipped.
-- Saved friends are kept in a JSON file so the list survives restarts.
local friendList = {
  names = {}, known = {}, dirty = true, elapsed = 0, refreshInterval = 2, status = '',
  folder = App.stateFolder .. '\\Friends',
}
friendList.file = friendList.folder .. '\\friends.json'

function friendList.ensureFolder()
  if io.dirExists(friendList.folder) then return true end
  return io.createDir(friendList.folder) and io.dirExists(friendList.folder)
end

-- A missing or unreadable file just means an empty list.
function friendList.load()
  friendList.known = {}
  if not io.fileExists(friendList.file) then return end
  local ok, parsed = pcall(JSON.parse, io.load(friendList.file) or '')
  if ok and type(parsed) == 'table' then
    for _, name in ipairs(parsed) do
      if type(name) == 'string' and name ~= '' then table.insert(friendList.known, name) end
    end
  end
end

function friendList.save()
  if not friendList.ensureFolder() then
    friendList.status = 'Could not create the friends folder.'
    return false
  end
  if not io.save(friendList.file, JSON.stringify(friendList.known), true) then
    friendList.status = 'Could not save the friends list.'
    return false
  end
  return true
end

function friendList.isKnown(name)
  for _, knownName in ipairs(friendList.known) do
    if knownName == name then return true end
  end
  return false
end

function friendList.refresh()
  local names = {}
  local sim = ac.getSim()
  if sim.isOnlineRace and ac.isTaggedAsFriend then
    for i = 1, sim.carsCount - 1 do
      if ac.getCar(i).isConnected then
        local name = ac.getDriverName(i)
        if name and name ~= '' and ac.isTaggedAsFriend(name) then
          table.insert(names, name)
        end
      end
    end
  end
  friendList.names = names
  friendList.dirty = false

  local added = false
  for _, name in ipairs(names) do
    if not friendList.isKnown(name) then
      table.insert(friendList.known, name)
      added = true
    end
  end
  if added then friendList.save() end
end

-- Clears the saved list. Friends connected at that moment are saved again on the next refresh if still tagged.
function friendList.reset()
  friendList.known = {}
  if io.fileExists(friendList.file) then io.deleteFile(friendList.file) end
  if io.fileExists(friendList.file) then
    friendList.status = 'Could not delete the friends file.'
    return
  end
  friendList.status = 'Friends list reset.'
  friendList.dirty = true
end

friendList.load()

function friendList.update(dt)
  friendList.elapsed = friendList.elapsed + dt
  if friendList.dirty or friendList.elapsed >= friendList.refreshInterval then
    friendList.elapsed = 0
    friendList.refresh()
  end
end

-- Returns the names of connected friends. Read-only copy so callers cannot change the cache.
function friendList.get()
  local copy = {}
  for i, name in ipairs(friendList.names) do copy[i] = name end
  return copy
end

function friendList.isFriend(name)
  for _, friendName in ipairs(friendList.names) do
    if friendName == name then return true end
  end
  return false
end

ac.onClientConnected(function()
  friendList.dirty = true
end)

Friends.friendList = friendList

return Friends
