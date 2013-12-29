ObstaclePath = setmetatable({}, { __index = PhysicalEntity })

function ObstaclePath.new(cell, path)
  local self = setmetatable(
      PhysicalEntity.new(cell), { __index = ObstaclePath })
  
  local body = self:createBody_(MOAIBox2DBody.STATIC)
  self.body:addChain(path)
  self.body:resetMassData()

  return self
end
