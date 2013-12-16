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

  self.fader = MOAIGfxQuad2D.new()
  self.fader:setTexture(settings.misc.pixel_texture_path)
  self.fader:setRect(-Game.kScreenWidth / 2, -Game.kScreenHeight / 2,
                     Game.kScreenWidth / 2, Game.kScreenHeight / 2)

  self.coral_killer = MOAITexture.new()
  self.coral_killer:load(settings.entities.coral_killer.texture_path)

  self.rock_killer = MOAITexture.new()
  self.rock_killer:load(settings.entities.rock_killer.texture_path)

  self.algae_glower = MOAITexture.new()
  self.algae_glower:load(settings.entities.algae_glower.texture_path)

  self.red_algae_glower = MOAITexture.new()
  self.red_algae_glower:load(settings.entities.red_algae_glower.texture_path)

  self.cosmetics = MOAITexture.new()
  self.cosmetics:load(settings.entities.cosmetics.texture_path)

  self.music = MOAIUntzSound.new()
  self.music:load(settings.sounds.music_path)
  self.music:setVolume(settings.sounds.music_volume)

  self.throw_sound = MOAIUntzSound.new()
  self.throw_sound:load(settings.sounds.throw_path)
  self.throw_sound:setVolume(settings.sounds.throw_volume)

  return self
end
