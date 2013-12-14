LightMap = {}

function LightMap.new(layer)
  local self = setmetatable({}, { __index = LightMap })

  self.viewport_ = MOAIViewport.new()
  self.viewport_:setSize(Game.kScreenPixelWidth, Game.kScreenPixelHeight)
  self.viewport_:setScale(Game.kScreenWidth, -Game.kScreenHeight)

  self.layer_ = MOAILayer2D.new()
  self.layer_:setViewport(self.viewport_)

  self.framebuffer_ = MOAIFrameBufferTexture.new()
  self.framebuffer_:setRenderTable({ self.layer_ })
  self.framebuffer_:init(Game.kScreenPixelWidth, Game.kScreenPixelHeight)
  self.framebuffer_:setClearColor(0, 0, 0, 1.0)

  MOAIRenderMgr.setBufferTable({ self.framebuffer_ })

  self.lightDeck_ = MOAIGfxQuad2D.new()
  self.lightDeck_:setTexture(settings.effects.lightmap.light_texture_path)
  self.lightDeck_:setRect(
    -settings.effects.lightmap.small_light_size,
    -settings.effects.lightmap.small_light_size,
     settings.effects.lightmap.small_light_size,
     settings.effects.lightmap.small_light_size)

  self.destDeck_ = MOAIGfxQuad2D.new()
  self.destDeck_:setTexture(self.framebuffer_)
  self.destDeck_:setRect(-Game.kScreenWidth / 2, -Game.kScreenHeight / 2,
                         Game.kScreenWidth / 2, Game.kScreenHeight / 2)
  
  self.destProp_ = MOAIProp2D.new()
  self.destProp_:setDeck(self.destDeck_)
  self.destProp_:setPriority(settings.priorities.lightmap)

  self.destLayer_ = layer
  self.destLayer_:insertProp(self.destProp_)

  return self
end

function LightMap:addLight()
  local prop = MOAIProp2D.new()
  prop:setDeck(self.lightDeck_)
  prop:setBlendMode(MOAIProp.BLEND_MULTIPLY)
  self.layer_:insertProp(prop)

  return prop
end

function LightMap:removeLight(prop)
  self.layer_:removeProp(prop)
end
