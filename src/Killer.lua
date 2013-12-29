Killer = setmetatable({}, { __index = PhysicalEntity })

function Killer.new(cell, opts, decker, verts, callback)
  local self = setmetatable(
      PhysicalEntity.new(cell), { __index = Killer })

  local body = self:createBody_(MOAIBox2DBody.STATIC)
  local prop, cx, cy, xy = decker:makePropForFile(opts.texture_path, verts)
  prop:setPriority(settings.priorities.doodads)
  prop:setParent(body)
  prop:setLoc(0, 0)
  body:setTransform(cx, cy, 0)

  local fixture = body:addChain(
      rescaleRectChain(xy, opts.collision_width, opts.collision_height), true)

  fixture:setCollisionHandler(
      function(phase, a, b, arbiter)
        arbiter:setContactEnabled(false)
        local do_callback = MOAICoroutine.new()
        do_callback:run(callback)
      end, MOAIBox2DArbiter.PRE_SOLVE, settings.collision_masks.player)

  fixture:setFilter(settings.collision_masks.lethal,
                    settings.collision_masks.player)
  
  cell.fgLayer:insertProp(prop)
  self.layer_ = cell.fgLayer
  self.prop_ = prop

  return self
end

function Killer:getNode()
  return self.body
end

function Killer:destroy()
  self.layer_:removeProp(self.prop_)
  self.layer_ = nil
  self.prop_ = nil

  PhysicalEntity.destroy(self)
end

