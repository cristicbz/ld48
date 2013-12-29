Goal = setmetatable({}, { __index = PhysicalEntity })

function Goal.new(cell, opts, x, y, radius)
  local self = setmetatable(
      PhysicalEntity.new(cell), { __index = Goal })

  local body = self:createBody_(MOAIBox2DBody.STATIC)
  local fixture = body:addCircle(0, 0, radius)
  body:setTransform(x, y)
  self.done_ = false
  fixture:setCollisionHandler(
      function(phase, a, b, arbiter)
        arbiter:setContactEnabled(false)
        if not self.done_ and self.level_.player:canWin() then
          self.done_ = true
          local coro = MOAICoroutine.new()
          coro:run(function() cell.level:nextLevel() end)
        end
      end, MOAIBox2DArbiter.PRE_SOLVE, settings.collision_masks.player)

  fixture:setFilter(settings.collision_masks.nonlethal,
                    settings.collision_masks.player)

  self.winLight_ = opts.light_color
  self.fadeTimeWin_ = opts.fade_time_win
  self.fadeTimeNoWin_ = opts.fade_time_no_win

  self.light_ = cell.lightmap:addLight()
  self.light_:setParent(self.body)
  self.light_:setScl(opts.light_scale, opts.light_scale)
  self.level_ = cell.level
  self.winState_ = false

  self:changedWinState()

  return self
end

function Goal:changedWinState()
  local l = self.winLight_
  local canWin = self.level_.player:canWin()
  if canWin == self.winState_ then return end
  self.winState_ = canWin

  if canWin then
    self.light_:setColor(0,0,0,0)
    self.light_:seekColor(l[1], l[2], l[3], l[4], self.fadeTimeWin_,
                          MOAIEaseType.EASE_IN)
  else
    self.light_:setColor(l[1], l[2], l[3], l[4])
    self.light_:seekColor(0, 0, 0, 0, self.fadeTimeNoWin_,
                          MOAIEaseType.EASE_IN)
  end
end

function Goal:destroy()
  self.level_.lightmap:removeLight(self.light_)
  PhysicalEntity.destroy(self)
end
