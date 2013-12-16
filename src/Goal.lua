Goal = setmetatable({}, { __index = PhysicalEntity })

function Goal.new(cell, opts, x, y)
  local self = setmetatable(
      PhysicalEntity.new(cell), { __index = Goal })

  local body = self:createBody_(MOAIBox2DBody.STATIC)
  local fixture = body:addCircle(0, 0, opts.activate_radius)
  body:setTransform(x, y)
  self.done_ = false
  fixture:setCollisionHandler(
      function(phase, a, b, arbiter)
        arbiter:setContactEnabled(false)
        if not self.done_ then
          self.done_ = true
          local coro = MOAICoroutine.new()
          coro:run(function() cell.level:nextLevel() end)
        end
      end, MOAIBox2DArbiter.PRE_SOLVE, settings.collision_masks.player)

  fixture:setFilter(settings.collision_masks.nonlethal,
                    settings.collision_masks.player)
end
