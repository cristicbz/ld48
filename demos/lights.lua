local EDGE = {{1, 1}, {-1, 1}, {-1, -1}, {1, -1}}

shadowVertexShaderSource = [[
uniform mat4 transform;
uniform vec4 ucolor;

attribute vec4 position;

varying vec4 colorVarying;

void main() {
  gl_Position = position * transform;
  colorVarying = ucolor;
}
]]

shadowFragShaderSource = [[
varying vec4 colorVarying;

void main() {
  gl_FragColor = colorVarying;
}
]]

local shadowShader = MOAIShader.new()
shadowShader:load(shadowVertexShaderSource, shadowFragShaderSource)
shadowShader:reserveUniforms(2)
shadowShader:declareUniform(1, 'transform', MOAIShader.UNIFORM_WORLD_VIEW_PROJ)
shadowShader:declareUniform(2, 'ucolor', MOAIShader.UNIFORM_PEN_COLOR)


shadowShader:setVertexAttribute(1, 'position')

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
pixelTex:load("pixel.png")

local pixelDeck = MOAIGfxQuad2D.new()
pixelDeck:setTexture(pixelTex)
pixelDeck:setRect(-0.5, 0.5, 0.5, -0.5)

local bgdeck = MOAIGfxQuad2D.new()
bgdeck:setTexture('full-background.png')
bgdeck:setRect(-0.5, 0.5, 0.5, -0.5)

local bgprop = MOAIProp2D.new()
bgprop:setDeck(bgdeck)
bgprop:setScl(worldWidth, worldHeight)
bgprop:setColor(1.0, 1.0, 1.0, 1.0)
bglayer:insertProp(bgprop)

-- Load light texture
local lightTex = MOAITexture.new()
lightTex:load("spotlight-map.png")
lightTex:setFilter(MOAITexture.GL_LINEAR, MOAITexture.GL_LINEAR)

local lightDeck = MOAIGfxQuad2D.new()
lightDeck:setTexture(lightTex)
lightDeck:setRect(-0.5, -0.5, 0.5, 0.5)

-- Setup light map.
local lightBuffer = MOAIFrameBufferTexture.new()
lightBuffer:init(1280*1, 720*1)
lightBuffer:setClearColor(0.0, 0.0, 0.0, 0.0)
MOAIRenderMgr.setBufferTable({ lightBuffer })

local lightBufferLayer = MOAILayer2D.new()
local viewportLow = MOAIViewport.new()
viewportLow:setSize(1280, 720)
viewportLow:setScale(worldWidth, worldHeight)

lightBufferLayer:setViewport(viewportLow)
lightBufferLayer:setSortMode(MOAILayer.SORT_PRIORITY_ASCENDING)
lightBuffer:setRenderTable({ lightBufferLayer })

local lightBufferDeck = MOAIGfxQuad2D.new()
lightBufferDeck:setTexture(lightBuffer)
lightBufferDeck:setRect(-worldWidth / 2, worldHeight / 2,
                        worldWidth / 2, -worldHeight / 2)

local lightBufferProp = MOAIProp2D.new()
lightBufferProp:setDeck(lightBufferDeck)
lightBufferProp:setBlendMode(MOAIProp2D.GL_ZERO, MOAIProp2D.GL_SRC_COLOR)
lightBufferProp:setPriority(1)
overlayer:insertProp(lightBufferProp)

local glowProp = MOAIProp2D.new()
glowProp:setDeck(glowDeck)
glowProp:setBlendMode(MOAIProp2D.GL_SRC_COLOR, MOAIProp2D.GL_ONE)
glowProp:setPriority(2)
glowProp:setColor(0.4, 0.4, 0.4, 0.4)
overlayer:insertProp(glowProp)



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
-- Rig: LightWorld                                                            --
--------------------------------------------------------------------------------

LightWorld = {}

function LightWorld.new(casters)
  local self = setmetatable({}, {__index = LightWorld})

  local world = MOAIBox2DWorld.new()
  local casterForFixture = {}
  local lightForFixture = {}

  local body = world:addBody(MOAIBox2DBody.STATIC)
  for _, caster in pairs(casters) do
    local fixture = body:addChain(caster.poly, true)
    fixture:setSensor(true)
    fixture:setCollisionHandler(
        function(phase, a, b)
          local caster = casterForFixture[a]
          local light = lightForFixture[b]
          if caster == nil or light == nil then
            error('Unrecognized caster/light: '
                  .. tostring(caster) .. ',' .. tostring(light))
          end
          if phase == MOAIBox2DArbiter.BEGIN then
            light:markAsVisible(caster)
          else
            light:markAsHidden(caster)
          end
        end, MOAIBox2DArbiter.BEGIN + MOAIBox2DArbiter.END
    )

    fixture:setFilter(1, 1, -2)
    casterForFixture[fixture] = caster
  end

  self.world_ = world
  self.casterForFixture_ = casterForFixture
  self.lightForFixture_ = lightForFixture

  world:start()

  return self
end

function LightWorld:addLight(light)
  local body = self.world_:addBody(MOAIBox2DBody.DYNAMIC)
  local fixture = body:addCircle(0, 0, light:getRadius())
  fixture:setSensor(true)
  fixture:setFilter(1, 1, -1)
  body:setAttrLink(MOAITransform.ATTR_X_LOC,
                   light:getNode(), MOAIProp2D.ATTR_X_LOC)
  body:setAttrLink(MOAITransform.ATTR_Y_LOC,
                   light:getNode(), MOAIProp2D.ATTR_Y_LOC)
  body:setNodeLink(light:getNode())
  self.lightForFixture_[fixture] = light
end

--------------------------------------------------------------------------------
-- Rig: Light                                                                 --
--------------------------------------------------------------------------------
Light = {}

function Light.new(layer, lightDeck, pixelTex, pixelDeck, priority, radius)
  local self = setmetatable({
      layer_ = layer,
      radius_ = radius,
      buffSize_ = 512,
      casters_ = {},
  }, {__index = Light})

  local fmt = MOAIVertexFormat.new()
  fmt:declareCoord(1, MOAIVertexFormat.GL_FLOAT, 2)

  local shadowBuffer = MOAIVertexBuffer.new()
  shadowBuffer:setFormat(fmt)
  shadowBuffer:reserveVerts(self.buffSize_)

  local shadowMesh = MOAIMesh.new()
  shadowMesh:setVertexBuffer(shadowBuffer)
  shadowMesh:setPrimType(MOAIMesh.GL_TRIANGLE_STRIP)
  shadowMesh:setShader(shadowShader)

  local shadowProp = MOAIProp2D.new()
  shadowProp:setDeck(shadowMesh)
  shadowProp:setColor(0, 0, 0, 1.0)
  shadowProp:setPriority(priority)
  shadowProp:setBlendMode(MOAIProp.GL_ONE, MOAIProp.GL_ONE)
  layer:insertProp(shadowProp)

  local lightProp = MOAIProp2D.new()
  lightProp:setDeck(lightDeck)
  lightProp:setColor(1, 1, 1, 0)
  lightProp:setPriority(priority + 1)
  lightProp:setBlendMode(MOAIProp2D.GL_ONE_MINUS_DST_ALPHA, MOAIProp2D.GL_ONE)
  lightProp:setScl(radius * 2, radius * 2)
  layer:insertProp(lightProp)

  local clearProp = MOAIProp2D.new()
  clearProp:setDeck(shadowMesh)
  clearProp:setColor(1.0, 1.0, 1.0, 0.0)
  clearProp:setPriority(priority + 2)
  clearProp:setBlendMode(MOAIProp2D.GL_DST_COLOR, MOAIProp2D.GL_ZERO)
  layer:insertProp(clearProp)

  self.shadowBuffer_ = shadowBuffer
  self.shadowProp_ = shadowProp
  self.lightProp_ = lightProp
  self.clearProp_ = clearProp
  self.shadowVertexCount_ = 0
  self.root_ = self.lightProp_

  return self
end

function Light:getRadius()
  return self.radius_
end

function Light:markAsVisible(caster)
  self.casters_[caster] = true
end

function Light:markAsHidden(caster)
  self.casters_[caster] = nil
end

function Light:polyCaster_(poly, circle)
  local lightX, lightY = self.lightProp_:getWorldLoc()
  local lightRad = self.radius_

  local inserted = 0
  local buf = self.shadowBuffer_

  local nverts = #poly / 2
  local px, py = poly[nverts * 2 - 1], poly[nverts * 2]
  local pdot = (poly[nverts * 2 - 2] - py) * (lightX - px) +
               (px - poly[nverts * 2 - 3]) * (lightY - py)
  local ax, ay, bx, by

  for i = 1, nverts do
    local vx, vy = poly[i * 2 - 1], poly[i * 2]
    local dot = (py - vy) * (lightX - vx) + (vx - px) * (lightY - vy)

    if dot > 0 then
      if pdot < 0 then
        ax, ay = px, py
        if bx ~= nil then break end
      end
    elseif pdot > 0 then
      bx, by = px, py
      if ax ~= nil then break end
    end

    px, py, pdot = vx, vy, dot
  end

  if ax and bx then
    local alx, aly = ax - lightX, ay - lightY
    local blx, bly = bx - lightX, by - lightY

    local outA = alx < -lightRad or alx > lightRad or 
                 aly < -lightRad or aly > lightRad
    local outB = blx < -lightRad or blx > lightRad or 
                 bly < -lightRad or bly > lightRad

    if (not outA) or (not outB) then 
      if outA then
        ax, ay = intersectWithLight(
            bx, by, ax - bx, ay - by, lightX, lightY, lightRad)
        alx, aly = ax - lightX, ay - lightY
      elseif outB then
        bx, by = intersectWithLight(
            ax, ay, bx - ax, by - ay, lightX, lightY, lightRad)
        blx, bly = bx - lightX, by - lightY
      end

      local aix, aiy, edgeA = 
          intersectWithLight(ax, ay, alx, aly, lightX, lightY, lightRad)
      local bix, biy, edgeB =
          intersectWithLight(bx, by, blx, bly, lightX, lightY, lightRad)

      if self.shadowVertexCount_ > 0 then
        inserted = inserted + 1
        buf:writeFloat(ax, ay)
      end

      buf:writeFloat(ax, ay, aix, aiy, bx, by)
      inserted = inserted + 3

      if edgeA ~= edgeB then
        local ea = EDGE[edgeA + 1]
        buf:writeFloat(lightX + ea[1] * lightRad, lightY + ea[2] * lightRad)
        inserted = inserted + 1

        if (edgeB - edgeA) % 4 == 2 then
          local eb = EDGE[(edgeB - 1) % 4 + 1]
          buf:writeFloat(lightX + eb[1] * lightRad, lightY + eb[2] * lightRad)
          inserted = inserted + 1
        end
      end
      buf:writeFloat(bix, biy, bix, biy)
      inserted = inserted + 2
    end
  else
    if self.shadowVertexCount_ > 0 then
      buf:writeFloat(lightX - lightRad, lightY - lightRad)
      inserted = inserted + 1
    end
    buf:writeFloat(lightX - lightRad, lightY - lightRad,
                   lightX + lightRad, lightY - lightRad,
                   lightX - lightRad, lightY + lightRad,
                   lightX + lightRad, lightY + lightRad,
                   lightX + lightRad, lightY + lightRad)
    inserted = inserted + 5
  end

  return inserted
end

function Light:updateShadows()
  local oldVertexCount = self.shadowVertexCount_
  local buffer = self.shadowBuffer_
  local prop = self.shadowProp_
  local vertexCount = 0

  if oldVertexCount > 0 then buffer:reset() end
  for caster, _ in pairs(self.casters_) do
    if caster.poly then 
      vertexCount = vertexCount +
          self:polyCaster_(caster.poly, caster.boundingCircle)
    end
  end

  if vertexCount > 0 then
    buffer:bless()
    if oldVertexCount == 0 then prop:setVisible(true) end
    if vertexCount > self.buffSize_ then
      print('WARNING: Shadow buffer overrun with '.. tostring(vertexCount))
    end
  elseif oldVertexCount > 0 then
    prop:setVisible(false)
  end

  self.shadowVertexCount_ = vertexCount
end

function Light:getNode()
  return self.lightProp_
end

function Light:getRoot()
  return self.root_
end

function Light:replaceRoot(newRoot)
  self.root_:setAttrLink(MOAITransform.ATTR_X_LOC, newRoot)
  self.root_:setAttrLink(MOAITransform.ATTR_Y_LOC, newRoot)
  self.root_ = newRoot
end

-- Load world.
local worldDef, err = loadfile('path.lua')()

for _, wall in pairs(worldDef.walls) do
  local nverts = #wall.poly / 2
  local cx, cy = 0, 0
  for j = 1, nverts do
    cx, cy = cx + wall.poly[j * 2 - 1], cy + wall.poly[j * 2]
  end

  cx, cy = cx / nverts, cy / nverts
  local maxd = 0.0
  for j = 1, nverts do
    local dx, dy = cx - wall.poly[j * 2 - 1], cy - wall.poly[j * 2]
    local d = dx * dx + dy * dy
    if d > maxd then maxd = d end
  end

  wall.boundingCircle = {cx, cy, math.sqrt(maxd)}
end

local lightWorld = LightWorld.new(worldDef.walls)
local mouseLight = Light.new(
    lightBufferLayer, lightDeck, pixelTex, pixelDeck, 1, 30)
lightWorld:addLight(mouseLight)
mouseLight:updateShadows()

local world = MOAIBox2DWorld.new()
world:setUnitsToMeters(1.0)
world:setGravity(0.0)

local k, lights = 4, {mouseLight}
for _, light in pairs(worldDef.lights) do
  local l = Light.new(
      lightBufferLayer, lightDeck, pixelTex, pixelDeck, k, 20)
  lightWorld:addLight(l)
  local b = world:addBody(MOAIBox2DBody.DYNAMIC)
  local f = b:addCircle(0, 0, 0.2)
  f:setDensity(40)
  f:setRestitution(0.2)
  f:setFriction(0.0)
  b:resetMassData()
  b:setFixedRotation(true)
  local vx, vy = math.random() * 1.0 - 0.5, math.random() * 1.0 - 0.5
  local v = math.sqrt(vx * vx + vy * vy)
  vx, vy = vx / v * 10.0, vy / v * 10.0
  --b:setLinearVelocity(vx, vy)
  b:setTransform(light.circle[1], light.circle[2], 0)
  l.body = b

  --l:getNode():setColor(math.random() > 0.5 and 0.8 or 0.01,
  --                     math.random() > 0.5 and 0.8 or 0.01,
  --                     math.random() > 0.5 and 0.8 or 0.01, 0.0)
  l:getNode():setColor(0.025, 0.25, 0.6*0.25, 0.0)
  l:updateShadows()
  l:replaceRoot(b)
  table.insert(lights, l)
  k = k + 4 
end
world:start()

local accum,n = 0, 0
MOAICoroutine.new():run(function()
  while true do
    local mx, my = fglayer:wndToWorld(MOAIInputMgr.device.pointer:getLoc())
    if math.abs(mx) < 50 and math.abs(my) < 50 then
      mouseLight:getNode():setLoc(mx, my)
    end
    for _, l in pairs(lights) do
      if l.body then
        local fx, fy = l:getNode():getWorldLoc()
        fx, fy = mx - fx, my - fy
        local fnorm = math.sqrt(fx * fx + fy * fy)
        fx, fy = fx / fnorm, fy / fnorm
        local fstrength = 2e4 / (fnorm * fnorm + 20) - 5e4 / (fnorm * fnorm * fnorm * fnorm + 100)
        fx, fy = fx * fstrength, fy * fstrength
        l.body:applyForce(fx, fy)
      end
      l:updateShadows()
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
local wallsBody = world:addBody(MOAIBox2DBody.STATIC)
wallsBody:addChain(
    {-worldWidth / 2, -worldHeight / 2,
     -worldWidth / 2, worldHeight / 2,
     worldWidth / 2, worldHeight / 2,
     worldWidth / 2, -worldHeight / 2}, true)
for _, wall in pairs(worldDef.walls) do
  wallsBody:addChain(wall.poly, true)

  local nverts = #wall.poly / 2
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
  geomprop:setColor(0,0,0,1)
  geomprop:setPriority(3)
  overlayer:insertProp(geomprop)

end

