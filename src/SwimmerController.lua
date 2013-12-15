SwimmerController = {}

function SwimmerController.new(swimmer)
  local self = setmetatable({}, {__index = SwimmerController})
  self.keyboard_ = MOAIInputMgr.device.keyboard
  self.pointer_ = MOAIInputMgr.device.pointer
  self.button_ = MOAIInputMgr.device.mouseLeft
  self.swimmer_ = swimmer

  self.boundCallback_ = function(down) self:callback_(down) end
  self.button_:setCallback(self.boundCallback_)

  return self
end

function SwimmerController:getMovement()
  local x, y = 0.0, 0.0
  if not self.keyboard_ then return x, y end

  if self.keyboard_:keyIsDown("a") then
    x = -1.0
  elseif self.keyboard_:keyIsDown("d") then
    x = 1.0
  end

  if self.keyboard_:keyIsDown("w") then
    y = 1.0
  elseif self.keyboard_:keyIsDown("s") then
    y = -1.0
  end

  return x, y
end

function SwimmerController:callback_(down)
  local x, y = self.swimmer_:getLayer():wndToWorld(self.pointer_:getLoc())
  self.swimmer_:launchLightBallTo(x, y)
end

function SwimmerController:destroy()
  self.button_:setCallback(nil)
  self.keyboard_ = nil
  self.swimmer_ = nil
  self.pointer_ = nil
end

