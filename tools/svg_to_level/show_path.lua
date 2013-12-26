#!moai
MOAISim.openWindow('Path', 1280, 720)

local viewport = MOAIViewport.new()
viewport:setScale(1, 0)
viewport:setSize(1280, 720)

local layer = MOAILayer2D.new()
layer:setViewport(viewport)
layer:showDebugLines(true)
MOAISim.pushRenderPass(layer)

local camera = MOAICamera2D.new()
camera:setLoc(0.0, 0.0)
layer:setCamera(camera)

local world = MOAIBox2DWorld.new()
world:setUnitsToMeters(0.01)
layer:setBox2DWorld(world)

local body = world:addBody(MOAIBox2DBody.STATIC)
local loader, err = loadfile('path.lua')
if not loader then
  print(err)
else
  for layerName, layer in pairs(loader()) do
    for iObject, object in pairs(layer.objects) do
      body:addChain(object.xy)
      for iCoord = 1, #object.xy / 2 do
        body:addCircle(
            object.xy[iCoord * 2 - 1], object.xy[iCoord * 2], 0.005)
      end
    end
  end
  world:start()
end
