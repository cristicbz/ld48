-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------
dofile("src/ParticleHelper.lua" )
dofile("src/Settings.lua")
dofile("src/Assets.lua")
dofile("src/GameState.lua")
dofile("src/Util.lua")
dofile("src/EventSource.lua")
dofile("src/Entity.lua")
dofile("src/ActiveSet.lua")
dofile("src/PhysicalEntity.lua")
dofile("src/DynamicEntity.lua")
dofile("src/LightMap.lua")
dofile("src/Level.lua")
dofile("src/Game.lua")
dofile("src/Swimmer.lua")

-------------------------------------------------------------------------------
-- Entry point
-------------------------------------------------------------------------------
game = Game.new()
game:run()

