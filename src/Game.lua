-------------------------------------------------------------------------------
-- File:        game.lua
-- Project:     RatOut
-- Author:      Cristian Cobzarenco
-- Description: Game rig, root rig which manages application state.
--
-- All rights reserved. Copyright (c) 2011-2012 Cristian Cobzarenco.
-- See http://www.nwydo.com
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Game rig
-------------------------------------------------------------------------------
Game = {
  kPixelToWorld =
      settings.world.screen_width / settings.world.screen_pixel_width,
  kAspectRatio =
      settings.world.screen_pixel_height / settings.world.screen_pixel_width,
  kScreenPixelWidth = settings.world.screen_pixel_width,
  kScreenPixelHeight = settings.world.screen_pixel_height,
  kScreenWidth = settings.world.screen_width,
}

Game.kScreenHeight = settings.world.screen_pixel_height * Game.kPixelToWorld

function Game.new()
  local self = setmetatable( {}, { __index = Game } )

  MOAISim.setStep( Game.SMALL_STEP_SIZE )
  MOAISim.clearLoopFlags()
  MOAISim.setLoopFlags( MOAISim.LOOP_FLAGS_FIXED )
  MOAISim.setLoopFlags ( MOAISim.SIM_LOOP_ALLOW_SPIN )

  MOAISim.openWindow("LD48", Game.kScreenPixelWidth, Game.kScreenPixelHeight)

  -- Create viewport
  self.viewport = MOAIViewport.new()
  self.viewport:setScale(Game.kScreenWidth, 0)
  self.viewport:setSize(Game.kScreenPixelWidth, Game.kScreenPixelHeight)
  
  if not settings.debug.no_sound then
    MOAIUntzSystem.initialize()
    MOAIUntzSystem.setVolume(1.0)
  end

  -- Create assets
  self.assets = Assets.new()

  -- Create game state. There will be multiple states (menu etc.).
  self.state = GameState.new(self.assets, self.viewport)
 
  return self
end

function Game:run()
  self.state:run()
end

