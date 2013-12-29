local debug = false
local finite = false
local EDGE = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}

-- Create window and viewport.
local worldX, worldY = 0, 0
local screenWidth, screenHeight = 1280, 720
local worldWidth, worldHeight = 100, screenHeight / screenWidth * 100
local lightRad = 10
MOAISim.openWindow("Lights", screenWidth, screenHeight)

local viewport = MOAIViewport.new()
viewport:setScale(worldWidth, 0)
viewport:setSize(1280, 720)

-- Create and setup layers.
local bglayer = MOAILayer2D.new()
bglayer:setViewport(viewport)
MOAISim.pushRenderPass(bglayer)

local fglayer = MOAILayer2D.new()
fglayer:setViewport(viewport)
MOAISim.pushRenderPass(fglayer)

local overlayer = MOAILayer2D.new()
overlayer:setViewport(viewport)
MOAISim.pushRenderPass(overlayer)

MOAIGfxDevice.getFrameBuffer():setClearDepth(true)

-- Create solid background.
local pixelTex = MOAITexture.new()
pixelTex:setWrap(true)
pixelTex:load("../assets/pixel.png")

local bgdeck = MOAIGfxQuad2D.new()
bgdeck:setTexture(pixelTex)
bgdeck:setRect(-worldWidth / 2, -worldHeight / 2,
               worldWidth / 2, worldHeight / 2)

local bgprop = MOAIProp2D.new()
bgprop:setDeck(bgdeck)
bgprop:setColor(0.1, 0.6, 0.6, 1.0)
bglayer:insertProp(bgprop)

-- Load light texture
local lightDeck = MOAIGfxQuad2D.new()
if debug then
  lightDeck:setTexture("../assets/pixel.png")
  lightRad = lightRad + .5
  lightDeck:setRect(-lightRad, -lightRad, lightRad, lightRad)
  lightRad = lightRad - .5
else
  lightDeck:setTexture("../assets/spotlight-map.png")
  lightDeck:setRect(-lightRad, -lightRad, lightRad, lightRad)
end

-- Setup light map.
local lightBuffer = MOAIFrameBufferTexture.new()
lightBuffer:init(screenWidth, screenHeight, MOAITexture.GL_RGBA8, MOAITexture.GL_DEPTH_COMPONENT16)
lightBuffer:setClearColor(0.15, 0.15, 0.15, 1.0)
lightBuffer:setClearDepth(true)
MOAIRenderMgr.setBufferTable({ lightBuffer })

local lightBufferLayer = MOAILayer2D.new()
lightBufferLayer:setViewport(viewport)
lightBuffer:setRenderTable({ lightBufferLayer })

local lightBufferDeck = MOAIGfxQuad2D.new()
lightBufferDeck:setTexture(lightBuffer)
lightBufferDeck:setRect(-worldWidth / 2, worldHeight / 2,
                        worldWidth / 2, -worldHeight / 2)

local lightBufferProp = MOAIProp2D.new()
lightBufferProp:setDeck(lightBufferDeck)
lightBufferProp:setBlendMode(MOAIProp2D.GL_DST_COLOR, MOAIProp2D.GL_ZERO)
overlayer:insertProp(lightBufferProp)

-- Setup mouse light.
local mouseLightProp = MOAIProp2D.new()
mouseLightProp:setDeck(lightDeck)
mouseLightProp:setBlendMode(MOAIProp.GL_SRC_ALPHA, MOAIProp.GL_ONE)
mouseLightProp:setDepthTest(MOAIProp.DEPTH_TEST_LESS)
mouseLightProp:setDepthMask(true)
mouseLightProp:setPriority(101)
lightBufferLayer:insertProp(mouseLightProp)

local lightX, lightY = 0, 0
MOAICoroutine.new():run(function()
  while true do
    local mx, my = fglayer:wndToWorld(MOAIInputMgr.device.pointer:getLoc())
    if math.abs(mx) < 50 and math.abs(my) < 50 then
      lightX, lightY = mx, my
      mouseLightProp:setLoc(lightX, lightY)
    end
    coroutine.yield()
  end
end)

-- Load world.
local worldDef, err = loadfile('path.lua')()
local geomfmt = MOAIVertexFormat.new()
geomfmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)
geomfmt:declareUV(2, MOAIVertexFormat.GL_FLOAT, 2)
geomfmt:declareColor(3, MOAIVertexFormat.GL_UNSIGNED_BYTE)

local shadowfmt = MOAIVertexFormat.new()
shadowfmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)

objects = {}
function intersectWithLight(vx, vy, dx, dy, lx, ly, rad, bias)
  local px, py
  bias = bias or 0.0

  if dx < 0 then
    px = (lx - rad - vx) / dx
  elseif dx > 0 then
    px = (lx + rad - vx) / dx
  else
    px = 10000
  end

  if dy < 0 then
    py = (ly - rad - vy) / dy
  elseif dy > 0 then
    py = (ly + rad - vy) / dy
  else
    py = 10000
  end

  local edge, p
  if math.abs(px) < math.abs(py) then
    if dx < 0 then edge = 2
    else edge = 0 end
    p = px
  else
    if dy < 0 then edge = 3
    else edge = 1 end
    p = py
  end

  if p < 0 then p = p + bias else p = p - bias end

  return vx + dx * p, vy + dy * p, edge
end

local prevX, prevY
for _, wall in pairs(worldDef.walls) do
  local nverts = #wall.poly / 2 - 1
  wall.poly[#wall.poly], wall.poly[#wall.poly - 1] = nil
  local geombuffer = MOAIVertexBuffer.new()
  geombuffer:setFormat(geomfmt)
  geombuffer:reserveVerts(nverts)

  local shadowbuffer = MOAIVertexBuffer.new()
  shadowbuffer:setFormat(shadowfmt)
  shadowbuffer:reserveVerts(nverts * 2 + 2)

  for i = 1, nverts do
    geombuffer:writeFloat(wall.poly[i * 2 - 1], wall.poly[i * 2])
    geombuffer:writeFloat(0, 0)
    geombuffer:writeColor32(1, 1, 1, 1)
  end
  geombuffer:bless()
  shadowbuffer:bless()

  local geommesh = MOAIMesh.new()
  geommesh:setPrimType(MOAIMesh.GL_TRIANGLE_FAN)
  geommesh:setVertexBuffer(geombuffer)
  geommesh:setTexture(pixelTex)

  local geomprop = MOAIProp2D.new()
  geomprop:setDeck(geommesh)
  if debug or finite then 
    geomprop:setColor(1,0,0,1)
  else
    geomprop:setColor(0,0,0,1)
  end
  fglayer:insertProp(geomprop)

  local shadowmesh = MOAIMesh.new()
  if debug then
    shadowmesh:setPrimType(MOAIMesh.GL_LINE_LOOP)
    shadowmesh:setPenWidth(7.0)
  elseif finite then
    shadowmesh:setPrimType(MOAIMesh.GL_TRIANGLE_STRIP)
  else
    shadowmesh:setPrimType(MOAIMesh.GL_TRIANGLE_FAN)
  end
  shadowmesh:setVertexBuffer(shadowbuffer)
  shadowmesh:setTexture(pixelTex)
  
  local shadowprop = MOAIProp2D.new()
  shadowprop:setDeck(shadowmesh)
  shadowprop:setDepthTest(MOAIProp2D.DEPTH_TEST_ALWAYS)
  shadowprop:setDepthMask(true)
  shadowprop:setColor(1,1,1,1.0)
  shadowprop:setPriority(100)
  if debug then
    overlayer:insertProp(shadowprop)
  else
    shadowprop:setBlendMode(MOAIProp.GL_ZERO, MOAIProp.GL_ONE)
    lightBufferLayer:insertProp(shadowprop)
  end

  MOAICoroutine.new():run(
      function()
        while true do

          local px, py = wall.poly[nverts * 2 - 1], wall.poly[nverts * 2]
          local pdot = 0.0
          local limitA, limitB
          for j = 1, nverts + 1 do
            local i = (j - 1) % nverts + 1
            local vx, vy = wall.poly[i * 2 - 1], wall.poly[i * 2]
            local nx, ny = py - vy, vx - px
            local lx, ly = lightX - vx, lightY - vy
            local dot = nx * lx + ly * ny

            local m = i - 1
            if m == 0 then m = nverts end

            if dot >= 0 and pdot < 0 then
              limitA = m 
              if limitB then break end
            elseif dot <= 0 and pdot > 0 then
              limitB = m
              if limitA then break end
            end

            px, py, pdot = vx, vy, dot
          end

          if limitA == nil then limitA = limitB
          elseif limitB == nil then limitB = limitA end

          if finite then
            shadowbuffer:reset()
            if limitA == limitB then limitA, limitB = 1, nverts + 1
            elseif limitB < limitA then limitB = nverts + limitB end

            for j = limitA, limitB do
              local i = (j - 1) % nverts + 1
              local vx, vy = wall.poly[i * 2 - 1], wall.poly[i * 2]
              local lx, ly = vx - lightX, vy - lightY
              lx, ly = lx / 4, ly / 4

              shadowbuffer:writeFloat(vx, vy)
              shadowbuffer:writeFloat(vx + lx, vy + ly)
            end
            shadowbuffer:bless()
          else
            shadowprop:setVisible(false)
            if limitA ~= limitB then
                local ax, ay = wall.poly[limitA * 2 - 1], wall.poly[limitA * 2]
                local alx, aly = ax - lightX, ay - lightY
                local bx, by = wall.poly[limitB * 2 - 1], wall.poly[limitB * 2]
                local blx, bly = bx - lightX, by - lightY

                local outA = math.max(math.abs(alx), math.abs(aly)) > lightRad
                local outB = math.max(math.abs(blx), math.abs(bly)) > lightRad

                if (not outA) or (not outB) then 
                  if outA then
                    ax, ay = intersectWithLight(
                        bx, by, ax - bx, ay - by, lightX, lightY, lightRad, 0.0)
                    alx, aly = ax - lightX, ay - lightY
                  elseif outB then
                    bx, by = intersectWithLight(
                        ax, ay, bx - ax, by - ay, lightX, lightY, lightRad, 0.0)
                    blx, bly = bx - lightX, by - lightY
                  end

                  local aix, aiy, edgeA = 
                      intersectWithLight(ax, ay, alx, aly, lightX, lightY, lightRad)
                  local bix, biy, edgeB =
                      intersectWithLight(bx, by, blx, bly, lightX, lightY, lightRad)

                  shadowprop:setVisible(true)
                  shadowbuffer:reset()
                  shadowbuffer:writeFloat(ax, ay)
                  shadowbuffer:writeFloat(aix, aiy)
                  if edgeA ~= edgeB then
                    shadowbuffer:writeFloat(lightX + EDGE[edgeA + 1][1] * lightRad,
                                            lightY + EDGE[edgeA + 1][2] * lightRad)

                    if (edgeB - edgeA) % 4 == 2 then
                      edgeB = (edgeB - 1) % 4
                      shadowbuffer:writeFloat(lightX + EDGE[edgeB + 1][1] * lightRad,
                                              lightY + EDGE[edgeB + 1][2] * lightRad)
                    end
                  end

                  shadowbuffer:writeFloat(bix, biy)
                  shadowbuffer:writeFloat(bx, by)
                  shadowbuffer:bless()
                end
              else
                  shadowprop:setVisible(true)
                  shadowbuffer:reset()
                  shadowbuffer:writeFloat(lightX - lightRad, lightY - lightRad)
                  shadowbuffer:writeFloat(lightX + lightRad, lightY - lightRad)
                  shadowbuffer:writeFloat(lightX + lightRad, lightY + lightRad)
                  shadowbuffer:writeFloat(lightX - lightRad, lightY + lightRad)
                  shadowbuffer:bless()
              end
            end
            coroutine.yield()
          end
      end
  )

end

