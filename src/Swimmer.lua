
Swimmer = setmetatable({}, {__index = DynamicEntity})

function Swimmer.new(cell, assets)
  local self = setmetatable(
      DynamicEntity.new(cell), { __index = Swimmer })

  local opts = settings.entities.swimmer
  local body, fixture = self:addCircleFixture_(
    opts.size * opts.collision_scale, opts.mass, opts.restitution, opts.friction)

  fixture:setFilter(settings.collision_masks.player,
                    settings.collision_masks.obstacle +
                    settings.collision_masks.collectible +
                    settings.collision_masks.lethal)
    
  body:setFixedRotation(true)

  self.sprite_ = MOAIProp2D.new()
  self.sprite_:setDeck(assets.swimmer)
  self.sprite_:setIndex(1)
  self.sprite_:setParent(self.body)
  self.sprite_:setLoc(-opts.collision_offset_x, -opts.collision_offset_y)

  self.animTimer_ = MOAITimer.new()
  self.animTimer_:setSpan(1.0 / opts.anim_fps)
  self.animTimer_:setMode(MOAITimer.LOOP)
  self.animTimer_:setListener(
      MOAITimer.EVENT_TIMER_LOOP,
      function()
        self.sprite_:setIndex(
            (self.sprite_:getIndex() + 1) % opts.anim_frames + 1);
      end)
  self.moving_ = false


  self.moveForce_ = opts.move_force
  self.launcherStrength_ = opts.launcher_strength
  self.recoilStrength_ = opts.recoil_strength

  self.lightmap_ = cell.lightmap
  self.layer_ = cell.fgLayer

  self.dead_ = false

  self.layer_:insertProp(self.sprite_)
  self.sprite_:setPriority(settings.priorities.foreground)

  self.light_ = self.lightmap_:addLight()
  self.light_:setParent(self.sprite_)
  self.light_:setColor(unpack(opts.flashlight_color))
  self.light_:setLoc(opts.flashlight_pos[1], opts.flashlight_pos[2])
  self.light_:setScl(opts.flashlight_scale[1], opts.flashlight_scale[2]);

  self.ctrl_ = SwimmerController.new(self)

  self.updateCoroutine_ = MOAICoroutine.new()
  self.updateCoroutine_:run(function() self:update() end)

  self.lightBall_ = LightBall.new(cell)

  return self
end

function Swimmer:getLayer()
  return self.layer_
end

function Swimmer:destroy()
  self.dead_ = true
  self.layer_:removeProp(self.sprite_)
  self.lightmap_:removeLight(self.light_)
  self.lightBall_:destroy()
  self.updateCoroutine_:stop()
  self.ctrl_:destroy()
  DynamicEntity.destroy(self)
end

function Swimmer:update()
  while not self.dead_ do
    local ctrlX, ctrlY = self.ctrl_:getMovement()
    local centerX, centerY = self.body:getWorldCenter()
    if ctrlX < 0 then
      self.sprite_:setScl(-1,1)
    elseif ctrlX > 0 then
      self.sprite_:setScl(1,1)
    end
    if ctrlX ~= 0 or ctrlY ~= 0 then
      if not self.moving_ then
        self.animTimer_:start()
        self.moving_ = true
      end
    elseif self.moving_ then
      self.animTimer_:stop()
        self.moving_ = false
    end
        
    self.body:applyForce(
      ctrlX * self.moveForce_, ctrlY * self.moveForce_,
      centerX, centerY)
    coroutine.yield()
  end
end

function Swimmer:launchLightBallTo(x, y)
  local px, py = self.body:getWorldCenter()
  local vx, vy = x - px, y - py
  local d = math.sqrt(vx * vx + vy * vy)
  if d < 0.01 or self.lightBall_:isEnabled() then return end
  vx = vx / d * self.launcherStrength_
  vy = vy / d * self.launcherStrength_
  self.lightBall_:launch(px, py, vx, vy)
  self.body:applyLinearImpulse(-vx * self.recoilStrength_,
                               -vy * self.recoilStrength_)
end

