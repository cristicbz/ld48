ObstaclePath = setmetatable({}, { __index = PhysicalEntity })

function ObstaclePath.new(cell, path, scale, offsetX, offsetY)
  local self = setmetatable(
      PhysicalEntity.new(cell), { __index = ObstaclePath })
  
  local body = self:createBody_(MOAIBox2DBody.STATIC)
  for k, points in pairs(path) do
    local verts = {}
    for i = 1, #points do
      verts[i * 2 - 1] = points[i].x * scale + offsetX
      verts[i * 2] = points[i].y * scale + offsetY
    end

    self.body:addChain(verts, true)
  end

  self.body:resetMassData()

  return self
end
