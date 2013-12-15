Killer = setmetatable({}, { __index = PhysicalEntity })

function Killer.new(cell, opts, deck, idx, verts, callback)
  local self = setmetatable(
      PhysicalEntity.new(cell), { __index = Killer })

  local body = self:createBody_(MOAIBox2DBody.STATIC)

  local dx, dy = verts[2].x - verts[1].x, verts[2].y - verts[1].y
  local angle = math.atan2(dy, dx)
  local sprite_width = math.sqrt(dx * dx + dy * dy)
  dx, dy = verts[1].x - verts[3].x, verts[1].y - verts[3].y
  local sprite_height = math.sqrt(dx * dx + dy * dy)

  local fixw, fixh =
      opts.collision_width * sprite_width,
      opts.collision_height * sprite_height 

  local fixture = body:addRect(0, 0, fixw, fixh, 0)
  body:setTransform(verts[4].x, verts[4].y, angle*180/math.pi)

  fixture:setCollisionHandler(
      function(phase, a, b, arbiter)
        arbiter:setContactEnabled(false)
        local do_callback = MOAICoroutine.new()
        do_callback:run(callback)
      end, MOAIBox2DArbiter.PRE_SOLVE, settings.collision_masks.player)

  fixture:setFilter(settings.collision_masks.lethal,
                    settings.collision_masks.player)
  

  deck:setQuad(idx,
               verts[1].x, verts[1].y, verts[2].x, verts[2].y,
               verts[3].x, verts[3].y, verts[4].x, verts[4].y)

  local prop = MOAIProp2D.new()
  prop:setDeck(deck)
  prop:setIndex(idx)
  cell.fgLayer:insertProp(prop)

  self.body_ = body
  self.prop_ = prop
  self.layer_ = cell.layer

  return self
end

function Killer:getNode()
  return self.body_
end

function Killer:destroy()
  self.layer_:removeProp(self.prop_)

  self.layer_ = nil
  self.body_ = nil
  self.prop_ = nil

  PhysicalEntity.destroy(self)
end

