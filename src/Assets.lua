--------------------------------------------------------------------------------
-- Assets Rig
--------------------------------------------------------------------------------

Assets = {}

function Assets.new()
  local self = setmetatable({}, { __index = Assets })

  self.swimmer = MOAIGfxQuad2D.new()
  self.swimmer:setTexture(settings.entities.swimmer.texture_path)
  self.swimmer:setRect(
      -settings.entities.swimmer.size, -settings.entities.swimmer.size,
      settings.entities.swimmer.size, settings.entities.swimmer.size)

  return self
end
