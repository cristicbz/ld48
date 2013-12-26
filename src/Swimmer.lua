Gib = setmetatable({}, {__index = DynamicEntity})

Gib.particleScript_ = makeParticleScript(function()
    r1 = ease( 0.2, 0.02,       EaseType.EASE_OUT      )
    r2 = ease( 4, 80,         EaseType.EASE_IN       )
    r3 = ease(0.1, ease( 0.4, 0.0, EaseType.EASE_IN ), EaseType.SHARP_EASE_IN)

    p.y = p.y + r1 * p.dy --+ ease( 0, 0.05 )
    p.x = p.x + r1 * p.dx

    sprite()
    sp.opacity = r3 
    sp.r = 0.5
    sp.g = 0.5
    sp.b = 0.5
    sp.rot     = sp.rot + ease(90,0,EaseType.EASE_IN) * r1
    sp.sx      = r2
    sp.sy      = r2
end)


function Gib.new(cell, gib_deck, particle_deck, opts, idx)
  local self = setmetatable(DynamicEntity.new(cell), {__index = Gib})

  local body = self:createBody_(MOAIBox2DBody.DYNAMIC)

  local tile = opts.tiles[idx]
  local scale = {opts.tile_scale[1] * opts.sprite_scale,
                 opts.tile_scale[2] * opts.sprite_scale}
  local x, y = tile[1] * scale[1], tile[2] * scale[2]
  local w, h = tile[3] * scale[1], tile[4] * scale[2] * 2
  self.fixture = self.body:addRect(-w/2 * opts.collision_scale,
                                   -h/2 * opts.collision_scale,
                                    w/2 * opts.collision_scale,
                                    h/2 * opts.collision_scale)
  self.dragCoefficient = 0.5 * (0.47) * (w + h) * .5 

  self.fixture:setRestitution(opts.restitution)
  self.fixture:setFriction(opts.friction)
  self.fixture:setDensity(opts.mass / (w * h))
  self.body:resetMassData()

  self.layer_ = cell.fgLayer

  self.prop_ = MOAIProp2D.new()
  self.prop_:setDeck(gib_deck)
  self.prop_:setColor(1,1,1,1)
  self.prop_:setPriority(settings.priorities.foreground+2)
  self.prop_:setIndex(idx)
  self.prop_:setScl(opts.sprite_scale, opts.sprite_scale)
  self.prop_:setParent(body)
  self.layer_:insertProp(self.prop_)

  local reg     = {}
  local system  = MOAIParticleSystem.new()
  local emitter = MOAIParticleDistanceEmitter.new()
  local state1  = MOAIParticleState.new()
  
  -- Initialise system.
  system:reserveParticles(16, 1)
  system:reserveSprites(16)
  system:reserveStates(1)
  system:setDeck(particle_deck)

  -- Create single state.
  state1:setTerm(14, 16)
  state1:setRenderScript(Gib.particleScript_)

  system:setState(1, state1)

  -- Initialise emmiter.
  emitter:setLoc(0.2, 0)
  emitter:setParent(self.body)
  emitter:setSystem(system)
  emitter:setRadius(0.3)
  emitter:setDistance(0.7)
  emitter:setMagnitude(0.0)
  emitter:surge()

  -- Insert system prop
  self.layer_:insertProp( system )
  system:setPriority(settings.priorities.foreground + 1)
  system:capParticles(true)

  -- Start up everything.
  emitter:start()
  system:start()

  -- Save system for removal on destruction
  self.system_  = system
  self.emitter_ = emitter

  return self
end

function Gib:destroy()
  self.emitter_:stop()
  self.layer_:removeProp(self.system_)
  self.layer_:removeProp(self.prop_)
  DynamicEntity.destroy(self)
end

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
                    settings.collision_masks.lethal +
                    settings.collision_masks.nonlethal)
    
  body:setFixedRotation(true)
  self.offsetX_ = opts.collision_offset_x
  self.offsetY_ = opts.collision_offset_y

  if not settings.debug.no_sound then
    self.throwSound_ = assets.throw_sound
    self.breatheSound_ = assets.breathe_sound
    self.killSound_ = assets.kill_sound
    self.breatheSound_:setLooping(true)
    self.breatheSound_:play()
  end

  self.sprite_ = MOAIProp2D.new()
  self.sprite_:setDeck(assets.swimmer)
  self.sprite_:setIndex(1)
  self.sprite_:setParent(self.body)
  self.sprite_:setLoc(-opts.collision_offset_x, -opts.collision_offset_y)

  self.idleScale_ = opts.idle_fps_scale
  self.animTimer_ = MOAITimer.new()
  self.animTimer_:setSpan(1.0 / opts.anim_fps)
  self.animTimer_:setMode(MOAITimer.LOOP)
  self.animTimer_:setListener(
      MOAITimer.EVENT_TIMER_LOOP,
      function()
        self.sprite_:setIndex(
            (self.sprite_:getIndex() % opts.anim_frames) + 1)
      end)
  self.animTimer_:setSpeed(self.idleScale_)
  self.animTimer_:start()
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

  self.ctrl_ = SwimmerController.new(cell.level, self)

  self.updateCoroutine_ = MOAICoroutine.new()
  self.updateCoroutine_:run(function() self:update() end)

  self.lightBall_ = LightBall.new(cell)

  self.cell_ = cell
  self.level_ = cell.level
  self.gibDeck_ = assets.swimmer_gibs
  self.bloodDeck_ = assets.blood_particle

  return self
end

function Swimmer:getLayer()
  return self.layer_
end

function Swimmer:explode()
  local px, py = self.body:getWorldCenter()
  self.lightBall_:launch(px, py, randomf(-0.1, 0.1), randomf(-0.1, 0.1))
  for i = 1, 8 do
    local gib = Gib.new(self.cell_, self.gibDeck_, self.bloodDeck_,
                        settings.entities.swimmer_gibs, i)
    local angle  = randomf(0, 360)
    local gx, gy = px + randomf(-.5, .5), py + randomf(-.5, .5), angle
    gib.body:setTransform(gx, gy)
    gib.body:applyLinearImpulse((gx - px)*.1, (gy - py)*.1)
    gib.body:setAngularDamping(20)

    if not settings.debug.no_sound then
      self.killSound_:play()
      self.breatheSound_:stop()
    end
  end

  local coro = MOAICoroutine.new()
  local light = self.light_
  local lightmap = self.lightmap_
  coro:run(function()
    light:setScl(2.0, 2.0)
    light:setColor(1,0.5,0.5,0.4)
    MOAICoroutine.blockOnAction(
        light:seekColor(0,0,0,0,1.2, MOAIEaseType.EASE_OUT))
    lightmap:removeLight(light)
  end)
  self.light_ = nil

  self:destroy()
  self.level_:lose()
end

function Swimmer:destroy()
  self.dead_ = true
  self.layer_:removeProp(self.sprite_)
  if self.light_ then self.lightmap_:removeLight(self.light_) end
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
      self.sprite_:setLoc(self.offsetX_, -self.offsetY_)
    elseif ctrlX > 0 then
      self.sprite_:setScl(1,1)
      self.sprite_:setLoc(-self.offsetX_, -self.offsetY_)
    end
    if ctrlX ~= 0 or ctrlY ~= 0 then
      if not self.moving_ then
      self.animTimer_:setSpeed(1.0)
        self.moving_ = true
      end
    elseif self.moving_ then
      self.animTimer_:setSpeed(self.idleScale_)
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
  local svx, svy = self.body:getLinearVelocity()
  local d = math.sqrt(vx * vx + vy * vy)
  if d < 0.01 or self.lightBall_:isEnabled() then return end
  vx = vx / d * self.launcherStrength_
  vy = vy / d * self.launcherStrength_
  if not settings.debug.no_sound then
    self.throwSound_:stop();
    self.throwSound_:play();
  end
  self.lightBall_:launch(px, py, svx + vx, svy + vy)
  self.body:applyLinearImpulse(-vx * self.recoilStrength_,
                               -vy * self.recoilStrength_)
end

function Swimmer:canWin()
  return not self.lightBall_:isEnabled()
end

