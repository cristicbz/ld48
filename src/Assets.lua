--------------------------------------------------------------------------------
-- Assets Rig
--------------------------------------------------------------------------------

Assets = {}

function Assets.new()
  local self = setmetatable({}, { __index = Assets })

  self.swimmer = MOAITileDeck2D.new()
  self.swimmer:setTexture(settings.entities.swimmer.texture_path)
  self.swimmer:setSize(4, 4)
  self.swimmer:setRect(
      -settings.entities.swimmer.size, -settings.entities.swimmer.size,
      settings.entities.swimmer.size, settings.entities.swimmer.size)


  self.coral_killer = MOAITexture.new()
  self.coral_killer:load(settings.entities.coral_killer.texture_path)

  self.rock_killer = MOAITexture.new()
  self.rock_killer:load(settings.entities.rock_killer.texture_path)

  self.algae_glower = MOAITexture.new()
  self.algae_glower:load(settings.entities.algae_glower.texture_path)

  self.red_algae_glower = MOAITexture.new()
  self.red_algae_glower:load(settings.entities.red_algae_glower.texture_path)

  return self
end
