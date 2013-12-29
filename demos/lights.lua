local debug = false
local finite = false
local EDGE = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}

-- Create window and viewport.
local worldX, worldY = 0, 0
local screenWidth, screenHeight = 1280, 720
local worldWidth, worldHeight = 100, screenHeight / screenWidth * 100
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

-- Create solid background.
local pixelTex = MOAITexture.new()
pixelTex:setWrap(true)
pixelTex:load("../assets/pixel.png")

local pixelDeck = MOAIGfxQuad2D.new()
pixelDeck:setTexture(pixelTex)
pixelDeck:setRect(-0.5, 0.5, 0.5, -0.5)

local bgprop = MOAIProp2D.new()
bgprop:setDeck(pixelDeck)
bgprop:setScl(worldWidth, worldHeight)
bgprop:setColor(0.8, 0.9, 0.9, 1.0)
bglayer:insertProp(bgprop)

-- Load light texture
local lightDeck = MOAIGfxQuad2D.new()
lightDeck:setTexture("../assets/spotlight-map.png")
lightDeck:setRect(-0.5, -0.5, 0.5, 0.5)

-- Setup light map.
local lightBuffer = MOAIFrameBufferTexture.new()
lightBuffer:init(screenWidth, screenHeight)
lightBuffer:setClearColor(0.05, 0.05, 0.05, 0.0)
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

--------------------------------------------------------------------------------
-- Rig: TriangleFanInserter                                                   --
--------------------------------------------------------------------------------
TriangleFanInserter = {}

function TriangleFanInserter.new(buffer)
  return setmetatable({
    buffer_ = buffer,
    inserted_ = 0
  }, {__index = TriangleFanInserter})
end

function TriangleFanInserter:done()
  self.inserted_ = 0
  self.startX_, self.startY_, self.prevX_, self.prevY_ = nil, nil, nil, nil
end

function TriangleFanInserter:getVertexCount()
  return self.inserted_
end

function TriangleFanInserter:insert(vx, vy)
  if vx == nil or vy == nil then error('nil coords') end


  if self.startX_ == nil then
    self.startX_, self.startY_ = vx, vy
    return
  end

  local b = self.buffer_
  function vertex(x, y)
    self.inserted_ = self.inserted_ + 1
    b:writeFloat(x, y)
    b:writeFloat(0, 0)
    b:writeColor32(1, 1, 1, 1)
  end
  
  if self.prevX_ ~= nil then
    vertex(self.startX_, self.startY_)
    vertex(self.prevX_, self.prevY_)
    vertex(vx, vy)
  end

  self.prevX_, self.prevY_ = vx, vy
end

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


--------------------------------------------------------------------------------
-- Rig: Light                                                                 --
--------------------------------------------------------------------------------
Light = {}

function Light.new(layer, lightDeck, pixelTex, pixelDeck, casters,
                   priority, radius)
  local self = setmetatable({
      layer_ = layer,
      radius_ = radius,
      casters_ = casters,
  }, {__index = Light})

  local fmt = MOAIVertexFormat.new()
  fmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)
  fmt:declareUV(2, MOAIVertexFormat.GL_FLOAT, 2)
  fmt:declareColor(3, MOAIVertexFormat.GL_UNSIGNED_BYTE)

  local shadowBuffer = MOAIVertexBuffer.new()
  shadowBuffer:setFormat(fmt)
  shadowBuffer:reserveVerts(128)

  local shadowMesh = MOAIMesh.new()
  shadowMesh:setVertexBuffer(shadowBuffer)
  shadowMesh:setPrimType(MOAIMesh.GL_TRIANGLES)
  shadowMesh:setTexture(pixelTex)

  local shadowProp = MOAIProp2D.new()
  shadowProp:setDeck(shadowMesh)
  shadowProp:setColor(0, 0, 0, 1)
  shadowProp:setPriority(priority)
  shadowProp:setBlendMode(MOAIProp.GL_ONE, MOAIProp.GL_ONE)
  layer:insertProp(shadowProp)

  local lightProp = MOAIProp2D.new()
  lightProp:setDeck(lightDeck)
  lightProp:setPriority(priority + 1)
  lightProp:setBlendMode(MOAIProp2D.GL_ONE_MINUS_DST_ALPHA, MOAIProp2D.GL_ONE)
  lightProp:setScl(radius * 2, radius * 2)
  layer:insertProp(lightProp)

  local clearProp = MOAIProp2D.new()
  clearProp:setDeck(pixelDeck)
  clearProp:setColor(1, 1, 1, 0)
  clearProp:setPriority(priority + 2)
  clearProp:setScl(radius * 2 + 10, radius* 2 + 10)
  clearProp:setBlendMode(MOAIProp2D.GL_DST_COLOR, MOAIProp2D.GL_ZERO)
  clearProp:setAttrLink(MOAIProp2D.ATTR_X_LOC, lightProp)
  clearProp:setAttrLink(MOAIProp2D.ATTR_Y_LOC, lightProp)
  clearProp:setNodeLink(lightProp)
  layer:insertProp(clearProp)

  self.inserter_ = TriangleFanInserter.new(shadowBuffer)
  self.shadowBuffer_ = shadowBuffer
  self.shadowProp_ = shadowProp
  self.lightProp_ = lightProp
  self.clearProp_ = clearProp
  self.shadowVertexCount_ = 0

  return self
end

function Light:polyCaster_(poly)
  local ins = self.inserter_
  local lightX, lightY = self.lightProp_:getWorldLoc()
  local lightRad = self.radius_
  ins:done()

  local nverts = #poly / 2
  local px, py, pdot = poly[nverts * 2 - 1], poly[nverts * 2], 0.0
  local limitA, limitB

  for j = 1, nverts + 1 do
    local i = (j - 1) % nverts + 1
    local vx, vy = poly[i * 2 - 1], poly[i * 2]
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

  if limitA ~= limitB then
    local ax, ay = poly[limitA * 2 - 1], poly[limitA * 2]
    local alx, aly = ax - lightX, ay - lightY
    local bx, by = poly[limitB * 2 - 1], poly[limitB * 2]
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

      ins:insert(ax, ay)
      ins:insert(aix, aiy)
      if edgeA ~= edgeB then
        ins:insert(lightX + EDGE[edgeA + 1][1] * lightRad,
                   lightY + EDGE[edgeA + 1][2] * lightRad)

        if (edgeB - edgeA) % 4 == 2 then
          edgeB = (edgeB - 1) % 4
          ins:insert(lightX + EDGE[edgeB + 1][1] * lightRad,
                     lightY + EDGE[edgeB + 1][2] * lightRad)
        end
      end

      ins:insert(bix, biy)
      ins:insert(bx, by)
    end
  else
      ins:insert(lightX - lightRad, lightY - lightRad)
      ins:insert(lightX + lightRad, lightY - lightRad)
      ins:insert(lightX + lightRad, lightY + lightRad)
      ins:insert(lightX - lightRad, lightY + lightRad)
  end

  return ins:getVertexCount()
end

function Light:updateShadows()
  local oldVertexCount = self.shadowVertexCount_
  local buffer = self.shadowBuffer_
  local prop = self.shadowProp_
  local vertexCount = 0

  if oldVertexCount > 0 then buffer:reset() end
  for _, caster in pairs(self.casters_) do
    if caster.poly then 
      vertexCount = vertexCount + self:polyCaster_(caster.poly)
    end
  end

  if vertexCount > 0 then
    buffer:bless()
    if oldVertexCount == 0 then prop:setVisible(true) end
  elseif oldVertexCount > 0 then
    prop:setVisible(false)
  end

  self.shadowVertexCount_ = vertexCount
end

function Light:getNode()
  return self.lightProp_
end

-- Load world.
local worldDef, err = loadfile('path.lua')()

local mouseLight = Light.new(
    lightBufferLayer, lightDeck, pixelTex, pixelDeck, worldDef.walls, 100, 15)

local k, lights = 110, {}
for _, light in pairs(worldDef.lights) do
  local l = Light.new(
      lightBufferLayer, lightDeck, pixelTex, pixelDeck, worldDef.walls, k, 10)
  l:getNode():setLoc(light.circle[1], light.circle[2])
  l:getNode():setColor(0.1 + math.random() * .9,
                       0.1 + math.random() * .9,
                       0.1 + math.random() * .9,
                       1.0)
  l:updateShadows()
  table.insert(lights, l)
  k = k + 10
end

MOAICoroutine.new():run(function()
  while true do
    local mx, my = fglayer:wndToWorld(MOAIInputMgr.device.pointer:getLoc())
    if math.abs(mx) < 50 and math.abs(my) < 50 then
      lightX, lightY = mx, my
      mouseLight:getNode():setLoc(lightX, lightY)
      mouseLight:updateShadows()
      for _, l in pairs(lights) do
        l:updateShadows()
      end
    end
    coroutine.yield()
  end
end)


local geomfmt = MOAIVertexFormat.new()
geomfmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)
geomfmt:declareUV(2, MOAIVertexFormat.GL_FLOAT, 2)
geomfmt:declareColor(3, MOAIVertexFormat.GL_UNSIGNED_BYTE)

objects = {}
function writeFlat(buff, x, y)
  buff:writeFloat(x, y)
  buff:writeFloat(0, 0)
  buff:writeColor32(1, 1, 1, 1)
end

local prevX, prevY
for _, wall in pairs(worldDef.walls) do
  local nverts = #wall.poly / 2 - 1
  wall.poly[#wall.poly], wall.poly[#wall.poly - 1] = nil
  local geombuffer = MOAIVertexBuffer.new()
  geombuffer:setFormat(geomfmt)
  geombuffer:reserveVerts(nverts)

  for i = 1, nverts do
    writeFlat(geombuffer, wall.poly[i * 2 - 1], wall.poly[i * 2])
  end
  geombuffer:bless()

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

end


--local shadowbuffer = MOAIVertexBuffer.new()
--shadowbuffer:setFormat(shadowfmt)
--shadowbuffer:reserveVerts(128)

--local shadowmesh = MOAIMesh.new()
--if debug then
--  shadowmesh:setPrimType(MOAIMesh.GL_LINE_LOOP)
--  shadowmesh:setPenWidth(7.0)
--elseif finite then
--  shadowmesh:setPrimType(MOAIMesh.GL_TRIANGLE_STRIP)
--else
--  shadowmesh:setPrimType(MOAIMesh.GL_TRIANGLES)
--end
--shadowmesh:setVertexBuffer(shadowbuffer)
--shadowmesh:setTexture(pixelTex)
  
--local shadowprop = MOAIProp2D.new()
--shadowprop:setDeck(shadowmesh)
--shadowprop:setColor(0, 0, 0, 1.0)
--shadowprop:setPriority(100)
--if debug then
--  overlayer:insertProp(shadowprop)
--else
--  shadowprop:setBlendMode(MOAIProp.GL_ONE, MOAIProp.GL_ONE)
--  lightBufferLayer:insertProp(shadowprop)
--end

--function shadowsForPoly(buffer, poly)
