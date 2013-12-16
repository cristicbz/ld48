LightBall = setmetatable({}, { __index = DynamicEntity })

function LightBall.new(cell)
  local self = setmetatable(DynamicEntity.new(cell), { __index = LightBall })

  local opts = settings.entities.light_ball
  local deck = MOAIGfxQuad2D.new()
  local sprite_size = opts.sprite_size
  deck:setTexture(opts.texture_path)
  deck:setRect(-sprite_size, -sprite_size, sprite_size, sprite_size)


  local collision_size = sprite_size * opts.collision_ratio
  local body, fixture = self:addCircleFixture_(
      collision_size, opts.mass, opts.restitution, opts.friction)
  fixture:setFilter(settings.collision_masks.collectible,
                    settings.collision_masks.obstacle +
                    settings.collision_masks.player +
                    settings.collision_masks.nonlethal)
  fixture:setCollisionHandler(
      function(phase, a, b, arbiter)
        arbiter:setContactEnabled(false)
        if self.collectible_ then 
          local do_disable = MOAICoroutine.new()
          do_disable:run(function() self:disable() end)
        end
      end, MOAIBox2DArbiter.PRE_SOLVE, settings.collision_masks.player)

  self.sprite_ = MOAIProp2D.new()
  self.sprite_:setDeck(deck)
  self.sprite_:setParent(body)
  self.sprite_:setPriority(settings.priorities.foreground + 1)

  self.lightColor_ = opts.light_color
  self.light_ = cell.lightmap:addLight()
  self.light_:setScl(opts.light_scale, opts.light_scale)
  self.light_:setColor(0,0,0,0)
  self.light_:setParent(body)
  self.lightmap_ = cell.lightmap

  self.sprite_:setParent(body)
  self.body_ = body

  self.layer_ = cell.fgLayer
  self.layer_:insertProp(self.sprite_)

  self.level_ = cell.level
  self.enabled_ = true
  self:disable()

  return self
end

function LightBall:disable()
  self.body_:setActive(false)
  self.sprite_:setVisible(false)
  local coro = MOAICoroutine.new()
  coro:run(function()
    MOAICoroutine.blockOnAction(self.light_:seekColor(0,0,0,0,0.5, MOAIEaseType.SHARP_EASE_IN))
    self.light_:setVisible(false)
    self.enabled_ = false
    if self.level_.goal then self.level_.goal:changedWinState() end
  end)
  self.collectible_ = false
  self.timer_ = nil
end

function LightBall:launch(x, y, vx, vy)
  if not self.enabled_ then
    self.enabled_ = true
    self.body_:setTransform(x, y, 0)
    self.body_:setActive(true)
    self.sprite_:setVisible(true)
    local l = self.lightColor_
    self.light_:setVisible(true)
    self.light_:seekColor(l[1],l[2],l[3],l[4], 0.2, MOAIEaseType.EASE_IN)
    self.body_:setLinearVelocity(vx, vy)

    self.collectible_ = false
    self.collectTimer_ = MOAITimer.new()
    self.collectTimer_:setSpan(settings.entities.light_ball.min_collect_time)
    self.collectTimer_:setListener(
        MOAITimer.EVENT_TIMER_END_SPAN,
        function() self.collectible_ = true end)
    self.collectTimer_:start()

    print (self.level_, self.level_.goal)
    if self.level_.goal then self.level_.goal:changedWinState() end
  end
end

function LightBall:isCollectible()
  return self.collectible_
end

function LightBall:isEnabled()
  return self.enabled_
end

function LightBall:destroy()
  self.layer_:removeProp(self.sprite_)
  self.lightmap_:removeLight(self.light_)
  self.collectible_ = false
  self.enabled_ = false
  if self.collectTimer_ then self.collectTimer_:stop() end
  DynamicEntity.destroy(self)
end
