-- Friends list: tagged friends on the server, kept in memory only.
local modules = require('core.modules')
local Friends = modules.friends

-- Friends come from CSP's friend tags (same source as comfy_map). Only online races have other players, so solo sessions get an empty list. Car 0 is the player's own car and is skipped.
-- Names are not written to disk: the tags belong to CSP and Content Manager, and a saved copy would keep names after a tag is removed.
local friendList = {
  names = {}, dirty = true, elapsed = 0, refreshInterval = 2,
}

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
end

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
