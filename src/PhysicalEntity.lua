PhysicalEntity = setmetatable( {
  FORCE_NON_DYNAMIC = 1
}, { __index = Entity } )

function PhysicalEntity.new( cell )
  local self = setmetatable(
    Entity.new( cell ),
    { __index = PhysicalEntity }
  )

  self.world = cell.world
  self.cell  = cell
  
  return self 
end

function PhysicalEntity:createBody_( bodyType, mode )
  self.body = self.world:addBody( bodyType )
  
  if bodyType == MOAIBox2DBody.DYNAMIC and mode ~= PhysicalEntity.FORCE_NON_DYNAMIC then
    self.isDynamic = true
    self.cell:registerDynamicBody( self.body, self )
  else
    self.isDynamic = false
    self.cell:registerStaticBody( self.body, self )
  end

  return self.body
end

function PhysicalEntity:getLoc()
  return self.body:getWorldCenter()
end

function PhysicalEntity:getAngle()
  return self.body:getAngle()
end

function PhysicalEntity:destroy()
  Entity.destroy( self )

  if self.body then
    if self.isDynamic then
      self.cell:deregisterDynamicBody( self.body )
    else
      self.cell:deregisterStaticBody( self.body )
    end

    self.body:destroy()
  
    self.body  = nil
  end

  self.world = nil
  self.cell  = nil
end
