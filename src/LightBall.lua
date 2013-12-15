LightBall = setmetatable({}, { __index = DynamicEntity })

function LightBall.new(cell)
  local self = setmetatable(DynamicEntity.new(cell), { __index = LightBall })

  local opts = settings.entities.light_ball
  local deck = MOAIGfxQuad2D.new()
  local sprite_size = opts.sprite_size
  deck:setTexture(opts.texture_path)
  deck:setRect(-sprite_size, -sprite_size, sprite_size, sprite_size)

  self.sprite_ = MOAIProp2D.new()
  self.sprite_:setDeck(deck)
  self.sprite_:setParent(self.body)
  self.sprite_:setPriority(settings.priorities.foreground)

  self.light_ = cell.lightmap:addLight()
  self.light_:setScl(opts.light_scale, opts.light_scale)
  self.light_:setColor(unpack(opts.light_color))
  self.light_:setParent(self.sprite_)
  self.lightmap_ = cell.lightmap

  local collision_size = sprite_size * opts.collision_ratio
  local body, fixture = self:addCircleFixture_(
      collision_size, opts.mass, opts.restitution, opts.friction)
  fixture:setFilter(settings.collision_masks.collectible,
                    settings.collision_masks.obstacle +
                    settings.collision_masks.player)
  fixture:setCollisionHandler(
      function(phase, a, b, arbiter)
        arbiter:setContactEnabled(false)
        if self.collectible_ then 
          local do_disable = MOAICoroutine.new()
          do_disable:run(function() self:disable() end)
        end
      end, MOAIBox2DArbiter.PRE_SOLVE, settings.collision_masks.player)

  self.sprite_:setParent(body)
  self.body_ = body

  self:disable()

  self.layer_ = cell.fgLayer
  self.layer_:insertProp(self.sprite_)

  return self
end

function LightBall:disable()
  self.sprite_:setVisible(false)
  self.body_:setActive(false)
  self.enabled_ = false
  self.light_:setVisible(false)
  self.collectible_ = false
  self.timer_ = nil
end

function LightBall:launch(x, y, vx, vy)
  if not self.enabled_ then
    self.enabled_ = true
    self.body_:setTransform(x, y, 0)
    self.body_:setActive(true)
    self.sprite_:setVisible(true)
    self.light_:setVisible(true)
    self.body_:setLinearVelocity(vx, vy)

    self.collectible_ = false
    self.collectTimer_ = MOAITimer.new()
    self.collectTimer_:setSpan(settings.entities.light_ball.min_collect_time)
    self.collectTimer_:setListener(
        MOAITimer.EVENT_TIMER_END_SPAN,
        function() self.collectible_ = true end)
    self.collectTimer_:start()
  end
end

function LightBall:isCollectible()
  return self.collectible_
end

function LightBall:destroy()
  self.layer_:removeProp(self.sprite_)
  self.lightmap_:removeLight(self.light_)
  self.collectible_ = false
  self.enabled_ = false
  if self.collectTimer_ then self.collectTimer_:stop() end
  DynamicEntity.destroy(self)
end
