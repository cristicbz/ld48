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

  self.glowers = MOAITexture.new()
  self.glowers:load(settings.entities.green_algae_glower.texture_path)

  if not settings.debug.no_sound then
    self.music = MOAIUntzSound.new()
    self.music:load(settings.sounds.music_path)
    self.music:setVolume(settings.sounds.music_volume)

    self.throw_sound = MOAIUntzSound.new()
    self.throw_sound:load(settings.sounds.throw_path)
    self.throw_sound:setVolume(settings.sounds.throw_volume)

    self.breathe_sound = MOAIUntzSound.new()
    self.breathe_sound:load(settings.sounds.breathe_path)
    self.breathe_sound:setVolume(settings.sounds.breathe_volume)

    self.kill_sound = MOAIUntzSound.new()
    self.kill_sound:load(settings.sounds.kill_path)
    self.kill_sound:setVolume(settings.sounds.kill_volume)
  end

  self.swimmer_gibs = MOAIGfxQuadDeck2D.new()
  self.swimmer_gibs:setTexture(settings.entities.swimmer_gibs.texture_path)
  local tiles = settings.entities.swimmer_gibs.tiles
  local n_gibs = #tiles
  local scale = settings.entities.swimmer_gibs.tile_scale
  self.swimmer_gibs:reserve(n_gibs)
  for i = 1, n_gibs do
    local tile = tiles[i]
    local x, y = tile[1] * scale[1], tile[2] * scale[2]
    local w, h = tile[3] * scale[1], tile[4] * scale[2]

    self.swimmer_gibs:setUVRect(i, x, y + h, x + w, y)
    self.swimmer_gibs:setRect(i, -w / 2, -h, w / 2, h)
  end

  local sz = settings.effects.blood.size
  self.blood_particle = MOAIGfxQuad2D.new()
  self.blood_particle:setTexture(settings.effects.blood.texture_path)
  self.blood_particle:setRect(-sz, -sz, sz, sz)

  local width = settings.effects.game_over_text.width * Game.kPixelToWorld
  local height = settings.effects.game_over_text.height * Game.kPixelToWorld
  self.game_over_text = MOAIGfxQuad2D.new()
  self.game_over_text:setTexture(settings.effects.game_over_text.texture_path)
  self.game_over_text:setRect( -width / 2, -height / 2, width / 2, height / 2)

  local width = settings.effects.thankyou_text.width * Game.kPixelToWorld
  local height = settings.effects.thankyou_text.height * Game.kPixelToWorld
  self.thankyou_text = MOAIGfxQuad2D.new()
  self.thankyou_text:setTexture(settings.effects.thankyou_text.texture_path)
  self.thankyou_text:setRect( -width / 2, -height / 2, width / 2, height / 2)

  local width = settings.effects.vote_text.width * Game.kPixelToWorld
  local height = settings.effects.vote_text.height * Game.kPixelToWorld
  self.vote_text = MOAIGfxQuad2D.new()
  self.vote_text:setTexture(settings.effects.vote_text.texture_path)
  self.vote_text:setRect( -width / 2, -height / 2, width / 2, height / 2)

  return self
end
