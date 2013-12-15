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


  self.coral_killer = MOAITexture.new()
  self.coral_killer:load(settings.entities.coral_killer.texture_path)

  self.rock_killer = MOAITexture.new()
  self.rock_killer:load(settings.entities.rock_killer.texture_path)

  return self
end
