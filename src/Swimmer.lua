SwimmerController = {}

function SwimmerController.new()
  local self = setmetatable({}, {__index = SwimmerController})

  self.keyboard_ = MOAIInputMgr.device.keyboard
  return self
end

function SwimmerController:getMovement()
  local x, y = 0.0, 0.0
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

Swimmer = setmetatable({}, {__index = DynamicEntity})

function Swimmer.new(cell, assets)
  local self = setmetatable(
      DynamicEntity.new(cell), { __index = Swimmer })

  local body, fixture = self:addCircleFixture_(
    settings.entities.swimmer.size,
    settings.entities.swimmer.mass,
    settings.entities.swimmer.restitution,
    settings.entities.swimmer.friction)
    
  body:setAngularDamping(0.9)

  self.sprite_ = MOAIProp2D.new()
  self.sprite_:setDeck(assets.swimmer)
  self.sprite_:setParent(self.body)

  self.moveForce_ = settings.entities.swimmer.move_force

  self.lightmap_ = cell.lightmap
  self.layer_ = cell.fgLayer

  self.dead_ = false

  self.layer_:insertProp(self.sprite_)
  self.sprite_:setPriority(settings.priorities.foreground)

  self.light_ = self.lightmap_:addLight()
  self.light_:setParent(self.sprite_)

  self.ctrl_ = SwimmerController.new()

  self.updateCoroutine_ = MOAICoroutine.new()
  self.updateCoroutine_:run(function() self:update() end)

  return self
end

function Swimmer:destroy()
  self.dead_ = true
  self.layer_:removeProp(self.sprite_)
  self.lightmap_:removeLight(self.light_)
  DynamicEntity.destroy(self)
end

function Swimmer:update()
  while not self.dead_ do
    local ctrlX, ctrlY = self.ctrl_:getMovement()
    local centerX, centerY = self.body:getWorldCenter()
    self.body:applyForce(
      ctrlX * self.moveForce_, ctrlY * self.moveForce_,
      centerX, centerY)
    coroutine.yield()
  end
end

