-- Small helpers shared by several modules.
local modules = require('core.modules')
local Util = modules.util

local Debug = modules.debug.Debug

local function unpackStoredTable(serialized, label)
  if serialized == '' then return {} end
  local parsed = stringify.tryParse(serialized, nil, nil)
  if type(parsed) ~= 'table' then
	Debug.error('Could not read stored ' .. label .. '.')
	return {}
  end
  return parsed
end

local function packColor(color)
  return { color.r, color.g, color.b, color.mult }
end

local function isFiniteNumber(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function unpackColor(color)
  if type(color) ~= 'table' then return nil end
  for index = 1, 4 do
	if not isFiniteNumber(color[index]) or color[index] < 0 or color[index] > 1 then return nil end
  end
  return rgbm(color[1], color[2], color[3], color[4])
end

local function sameValue(a, b)
  if a == b then return true end
  if type(a) ~= 'table' or type(b) ~= 'table' then return false end
  for key, value in pairs(a) do
    if not sameValue(value, b[key]) then return false end
  end
  for key in pairs(b) do
    if a[key] == nil then return false end
  end
  return true
end

Util.unpackStoredTable = unpackStoredTable
Util.packColor = packColor
Util.isFiniteNumber = isFiniteNumber
Util.unpackColor = unpackColor
Util.sameValue = sameValue

return Util
