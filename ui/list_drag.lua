-- Drag-to-reorder for a vertical list in a scrolling window. Pure logic (no ui calls), so tools\harness.lua can test it.
-- Row centres are content coordinates (ui.getCursorY). The pointer is window coordinates: ui.mouseLocalPos().y - ui.getScrollY(),
-- because CSP's mouseLocalPos already includes the scroll.
local modules = require('core.modules')
local ListDrag = modules.listDrag

local defaults = {
  startDistance = 4,  -- px the pointer must move before a press becomes a drag
  swapAt = 0.6,       -- share of the gap to a neighbour row the dragged row must cover before they swap
  edge = 36,          -- px auto-scroll zone at the top and bottom of the window
  delay = 0.35,       -- s the pointer must stay in a zone before auto-scroll starts
  rampTime = 0.6,     -- s for auto-scroll to reach its full speed
  maxSpeed = 300,     -- px/s
  maxStep = 0.05,     -- s, caps one frame of auto-scroll after a frame hitch
}
ListDrag.defaults = defaults

local Drag = {}
Drag.__index = Drag

local function clamp(value, low, high)
  return math.max(low, math.min(value, high))
end

function ListDrag.new(options)
  local self = setmetatable({}, Drag)
  for key, value in pairs(defaults) do self[key] = (options and options[key]) or value end
  self:reset()
  return self
end

function Drag:reset()
  self.index = nil
  self.moved = false
  self.pressY = 0
  self.grabOffset = nil
  self.edgeDir = 0
  self.edgeTime = 0
  self.scrolling = false
  self.itemY = nil
end

-- Call while the handle of row `index` is held. Ignored while a drag is already running.
function Drag:press(index, pointerY)
  if self.index then return end
  self:reset()
  self.index = index
  self.pressY = pointerY
end

-- Call once per frame, after the rows are drawn.
-- frame = { mouseDown, pointerY, windowHeight, scrollY, scrollMaxY, dt, centers }
-- Returns the adjacent swaps to apply in order ({ from, to } pairs), and the new scroll position or nil.
function Drag:update(frame)
  local moves = {}
  if not self.index then return moves, nil end
  local centers = frame.centers
  local count = #centers
  if not frame.mouseDown or self.index > count then
    self:reset()
    return moves, nil
  end
  local visibleY = clamp(frame.pointerY, 0, frame.windowHeight)
  -- Measured on the press frame, so the row keeps the offset of the point where it was grabbed.
  if self.grabOffset == nil then
    self.grabOffset = clamp(self.pressY, 0, frame.windowHeight) + frame.scrollY - centers[self.index]
  end
  -- The dragged row stays under the pointer: its centre follows the pointer in content coordinates,
  -- so scrolling (auto-scroll or wheel) carries it through the list at the scroll speed, never faster.
  -- self.itemY is where the drag frame is drawn, from the press on.
  local itemY = visibleY + frame.scrollY - self.grabOffset
  self.itemY = itemY
  if not self.moved then
    if math.abs(frame.pointerY - self.pressY) < self.startDistance then return moves, nil end
    self.moved = true
  end

  while true do
    local i = self.index
    if i > 1 and itemY < centers[i] - (centers[i] - centers[i - 1]) * self.swapAt then
      moves[#moves + 1] = { i, i - 1 }
      self.index = i - 1
    elseif i < count and itemY > centers[i] + (centers[i + 1] - centers[i]) * self.swapAt then
      moves[#moves + 1] = { i, i + 1 }
      self.index = i + 1
    else
      break
    end
  end

  local dir, depth = 0, 0
  if frame.pointerY < self.edge then
    dir, depth = -1, self.edge - frame.pointerY
  elseif frame.pointerY > frame.windowHeight - self.edge then
    dir, depth = 1, frame.pointerY - (frame.windowHeight - self.edge)
  end
  -- Scroll only while the row can still move that way and the window can still scroll.
  if dir < 0 and (self.index == 1 or frame.scrollY <= 0) then dir = 0 end
  if dir > 0 and (self.index == count or frame.scrollY >= frame.scrollMaxY) then dir = 0 end
  if dir ~= self.edgeDir then
    self.edgeDir = dir
    self.edgeTime = 0
  end
  self.scrolling = false
  if dir == 0 then return moves, nil end
  local dt = math.min(frame.dt, self.maxStep)
  self.edgeTime = self.edgeTime + dt
  if self.edgeTime < self.delay then return moves, nil end
  local ramp = math.min((self.edgeTime - self.delay) / self.rampTime, 1)
  local speed = self.maxSpeed * math.min(depth / self.edge, 1) * ramp
  self.scrolling = true
  return moves, clamp(frame.scrollY + dir * speed * dt, 0, frame.scrollMaxY)
end

return ListDrag
