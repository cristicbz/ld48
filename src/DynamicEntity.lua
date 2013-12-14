DynamicEntity = setmetatable( {}, { __index = PhysicalEntity } )

function DynamicEntity.new( cell )
  local base = PhysicalEntity.new( cell )
  local self = setmetatable( base, { __index = DynamicEntity })
  
  self.dragCoefficient = 0
  self.volume          = 0

  return self
end

function DynamicEntity:addCircleFixture_( radius, mass, restitution, friction, x, y, angle )
  self:createBody_( MOAIBox2DBody.DYNAMIC )

  self.volume          = radius * radius * math.pi
  self.dragCoefficient = 0.5 * (0.47) * (radius * 2)

  self.fixture = self.body:addCircle( 0, 0, radius )
  self.fixture:setRestitution( restitution )
  self.fixture:setFriction( friction )
  self.fixture:setDensity( mass / self.volume )

  self.body:setTransform( x or 0, y or 0, angle or 0 )
  self.body:resetMassData()

  return self.body, self.fixture
end

