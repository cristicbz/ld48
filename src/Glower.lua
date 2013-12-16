Glower = setmetatable({}, { __index = PhysicalEntity })

function Glower.new(cell, opts, deckOn, deckOff, idx, verts)
  local self = setmetatable(
      PhysicalEntity.new(cell), { __index = Glower })

  local body = self:createBody_(MOAIBox2DBody.STATIC)
  local fixture = body:addCircle(0, 0, opts.activate_radius)
  local bx = (verts[1].x + verts[2].x + verts[3].x + verts[4].x) * .25
  local by = (verts[1].y + verts[2].y + verts[3].y + verts[4].y) * .25
  body:setTransform(bx, by, 0)

  fixture:setCollisionHandler(
      function(phase, a, b, arbiter)
        arbiter:setContactEnabled(false)
        self:setGlowing(true)
      end, MOAIBox2DArbiter.PRE_SOLVE, settings.collision_masks.collectible)

  fixture:setFilter(settings.collision_masks.nonlethal,
                    settings.collision_masks.collectible)
  
  self.propOn_ = createPropFromVerts(deckOn, idx, verts)
  self.propOn_:setBlendMode(MOAIProp.BLEND_NORMAL)
  deckOn:setUVRect(idx, 0.5, 1.0, 1.0, 0.0)
  self.propOn_:setPriority(settings.priorities.doodads + 1)
  self.propOn_:setColor(0.0, 0.0, 0.0, 0.0)
  self.propOn_:setVisible(false)

  self.propOff_ = createPropFromVerts(deckOff, idx, verts)
  self.propOff_:setBlendMode(MOAIProp.BLEND_NORMAL)
  deckOff:setUVRect(idx, 0.0, 1.0, 0.5, 0.0)
  self.propOff_:setPriority(settings.priorities.doodads + 1)
  self.propOff_:setColor(1.0, 1.0, 1.0, 1.0)

  self.light_ = cell.lightmap:addLight()
  self.lightColor_ = opts.light_color
  local lr, lg, lb, la = unpack(self.lightColor_)
  self.light_:setColor(lr, lg, lb, 0)
  self.light_:setScl(opts.light_scale, opts.light_scale)
  self.light_:setVisible(false)
  self.light_:setParent(body)

  cell.fgLayer:insertProp(self.propOff_)
  cell.fgLayer:insertProp(self.propOn_)

  self.layer_ = cell.fgLayer
  self.lightmap_ = cell.lightmap
  self.on_ = false
  

  return self
end

function Glower:setGlowing(glow)
  if self.on_ == glow then return end
  self.on_ = glow
  
  local lr, lg, lb, la = unpack(self.lightColor_)
  if glow then
    self.propOn_:setVisible(true)
    self.light_:setVisible(true)
    self.propOff_:seekColor(0.0, 0.0, 0.0, 0.0, 1.0, MOAIEaseType.EASE_IN)
    self.propOn_:seekColor(1.0, 1.0, 1.0, 1.0, 1.0, MOAIEaseType.EASE_IN)
    self.light_:seekColor(lr, lg, lb, la, 1.0, MOAIEaseType.EASE_IN)
  else
    self.propOff_:setVisible(true)
    self.propOn_:seekColor(0.0, 0.0, 0.0, 0.0, 1.0, MOAIEaseType.EASE_IN)
    self.light_:seekColor(lr, lg, lb, 0.0, 1.0, MOAIEaseType.EASE_IN)
    self.propOff_:seekColor(1.0, 1.0, 1.0, 1.0, 1.0, MOAIEaseType.EASE_IN)
  end
end

function Glower:destroy()
  self.layer_:removeProp(self.propOff_)
  self.layer_:removeProp(self.propOn_)
  self.lightmap_:removeLight(self.light_)
  PhysicalEntity.destroy(self)
end
