-------------------------------------------------------------------------------
-- Rig:     GameState
-- Extends: nothing
-------------------------------------------------------------------------------
GameState = {}

function GameState.new( assets, viewport )
  local self = setmetatable( {}, { __index = GameState } )

  self.gravity = settings.world.gravity

  self.assets = assets
  self.started = false

  -- Create Box2D world
  self.world = MOAIBox2DWorld.new()
  self.world:setGravity( 0, self.gravity )
  self.world:setUnitsToMeters( 1.0 )

  -- Create Camera
  self.camera = MOAICamera2D.new()
  self.camera:setLoc(0.0, 0.0)

  -- Create foreground layer
  self.fgLayer = MOAILayer2D.new()
  self.fgLayer:setViewport( viewport )
  self.fgLayer:setBox2DWorld( self.world )
  self.fgLayer:setCamera( self.camera )
  self.fgLayer:showDebugLines(settings.debug.show_lines)
  self.fgLayer:setSortMode(MOAILayer2D.SORT_NONE)

  -- Create background layer
  self.bgLayer = MOAILayer2D.new()
  self.bgLayer:setViewport( viewport )
  self.bgLayer:setCamera( self.camera )

  -- Create overlay layer
  self.overlayLayer = MOAILayer2D.new()
  self.overlayLayer:setViewport(viewport)

  -- Create Level
  self.level = Level.new(self.world, self.bgLayer, self.fgLayer,
                         self.overlayLayer, assets)
  self.level:setCamera( self.camera )

  -- Add swimmer
  self.swimmer = Swimmer.new(self.level.globalCell, self.assets)
  self.level:setPlayer(self.swimmer)

  -- Push layers in correct order
  MOAISim.pushRenderPass( self.bgLayer )
  MOAISim.pushRenderPass( self.fgLayer )
  MOAISim.pushRenderPass( self.overlayLayer )

  -- Initial update
  self.level:reload()
  self.camera:setLoc(0, 0)

  self:unpause()

  return self
end

function GameState:unpause()
  self.started = true
  self.world:start()
  self.level:unpause()
end

function GameState:die()
  self.swimmer:destroy()
end

function GameState:run()
end

