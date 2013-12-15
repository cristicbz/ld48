Killer = setmetatable({}, { __index = PhysicalEntity })

function Killer.new(cell, opts, deck, idx, verts, callback)
  local self = setmetatable(
      PhysicalEntity.new(cell), { __index = Killer })

  local fixture = createAlignedRectFromVerts(
      self:createBody_(MOAIBox2DBody.STATIC), verts,
      opts.collision_width, opts.collision_height)

  fixture:setCollisionHandler(
      function(phase, a, b, arbiter)
        arbiter:setContactEnabled(false)
        local do_callback = MOAICoroutine.new()
        do_callback:run(callback)
      end, MOAIBox2DArbiter.PRE_SOLVE, settings.collision_masks.player)

  fixture:setFilter(settings.collision_masks.lethal,
                    settings.collision_masks.player)
  
  self.prop_ = createPropFromVerts(deck, idx, verts)
  self.prop_:setPriority(settings.priorities.doodads)
  cell.fgLayer:insertProp(self.prop_)

  self.layer_ = cell.layer

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

