Glower = setmetatable({}, { __index = PhysicalEntity })

function Glower.new(cell, opts, decker, verts)
  local self = setmetatable(
      PhysicalEntity.new(cell), { __index = Glower })
  
  local body = self:createBody_(MOAIBox2DBody.STATIC)
  local propOff, cx, cy, xy = decker:makePropForFile(
      opts.texture_path, verts, opts.off_uv_quad)
  local propOn = decker:makePropForFile(
      opts.texture_path, xy, opts.on_uv_quad, true)
  local dx = (xy[1] + xy[3] - xy[5] - xy[7]) * .5
  local dy = (xy[2] + xy[4] - xy[6] - xy[8]) * .5
  local d = math.sqrt(dx * dx + dy * dy)
  local fixture = body:addCircle(
      dx / d * opts.activate_offset, dy / d * opts.activate_offset,
      opts.activate_radius)

  body:setTransform(cx, cy, 0)
  propOff:setParent(body)
  propOff:setLoc(0, 0)
  propOff:setPriority(settings.priorities.doodads + 1)

  propOn:setParent(body)
  propOn:setPriority(settings.priorities.doodads + 1)
  propOn:setColor(0.0, 0.0, 0.0, 0.0)
  propOn:setVisible(false)

  fixture:setCollisionHandler(
      function(phase, a, b, arbiter)
        arbiter:setContactEnabled(false)
        self:setGlowing(true)
      end, MOAIBox2DArbiter.PRE_SOLVE,
      settings.collision_masks.collectible)

  fixture:setFilter(settings.collision_masks.nonlethal,
                    settings.collision_masks.collectible)

  self.light_ = cell.lightmap:addLight()
  self.lightColor_ = opts.light_color
  self.lightTime_ = opts.light_time
  local lr, lg, lb, la = unpack(self.lightColor_)
  self.light_:setColor(lr, lg, lb, 0)
  self.light_:setScl(opts.light_scale, opts.light_scale)
  self.light_:setVisible(false)
  self.light_:setParent(body)

  cell.fgLayer:insertProp(propOff)
  cell.fgLayer:insertProp(propOn)

  self.layer_ = cell.fgLayer
  self.lightmap_ = cell.lightmap
  self.propOn_ = propOn
  self.propOff_ = propOff
  self.on_ = false

  return self
end

function Glower:setGlowing(glow)
  if self.on_ == glow then return end
  self.on_ = glow
  
  local lr, lg, lb, la = unpack(self.lightColor_)
  local lt = self.lightTime_
  if glow then
    self.propOn_:setVisible(true)
    self.light_:setVisible(true)
    self.propOff_:seekColor(0.0, 0.0, 0.0, 0.0, lt, MOAIEaseType.EASE_IN)
    self.propOn_:seekColor(1.0, 1.0, 1.0, 1.0, lt, MOAIEaseType.EASE_IN)
    self.light_:seekColor(lr, lg, lb, la, lt, MOAIEaseType.EASE_IN)
  else
    self.propOff_:setVisible(true)
    self.propOn_:seekColor(0.0, 0.0, 0.0, 0.0, lt, MOAIEaseType.EASE_IN)
    self.light_:seekColor(lr, lg, lb, 0.0, lt, MOAIEaseType.EASE_IN)
    self.propOff_:seekColor(1.0, 1.0, 1.0, 1.0, lt, MOAIEaseType.EASE_IN)
  end
end

function Glower:destroy()
  self.layer_:removeProp(self.propOff_)
  self.layer_:removeProp(self.propOn_)
  self.lightmap_:removeLight(self.light_)
  PhysicalEntity.destroy(self)
end
