LightMap = {}

function LightMap.new(layer)
  local self = setmetatable({}, { __index = LightMap })

  self.viewport_ = MOAIViewport.new()
  self.viewport_:setSize(Game.kScreenPixelWidth, Game.kScreenPixelHeight)
  self.viewport_:setScale(Game.kScreenWidth, -Game.kScreenHeight)

  self.layer_ = MOAILayer2D.new()
  self.layer_:setViewport(self.viewport_)
  self.layer_:setSortMode(MOAILayer2D.SORT_NONE)

  self.lightDeck_ = MOAIGfxQuad2D.new()
  self.lightDeck_:setTexture(settings.effects.lightmap.light_texture_path)
  self.lightDeck_:setRect(
    -settings.effects.lightmap.small_light_size,
    -settings.effects.lightmap.small_light_size,
     settings.effects.lightmap.small_light_size,
     settings.effects.lightmap.small_light_size)


  self.destLayer_ = layer
  if not settings.debug.disable_lightmap then
    self.framebuffer_ = MOAIFrameBufferTexture.new()
    self.framebuffer_:init(Game.kScreenPixelWidth, Game.kScreenPixelHeight)
    self.framebuffer_:setRenderTable({ self.layer_ })
    self.framebuffer_:setClearColor(0, 0, 0, 1.0)
    MOAIRenderMgr.setBufferTable({ self.framebuffer_ })

    self.destDeck_ = MOAIGfxQuad2D.new()
    self.destDeck_:setTexture(self.framebuffer_)
    self.destDeck_:setRect(-Game.kScreenWidth / 2, -Game.kScreenHeight / 2,
                           Game.kScreenWidth / 2, Game.kScreenHeight / 2)

    self.destProp_ = MOAIProp2D.new()
    self.destProp_:setDeck(self.destDeck_)
    self.destProp_:setBlendMode(MOAIProp.GL_ZERO, MOAIProp.GL_SRC_COLOR)
    self.destProp_:setPriority(settings.priorities.lightmap)
    self.destLayer_:insertProp(self.destProp_)
  end

  return self
end

function LightMap:addLight()
  local prop = MOAIProp2D.new()
  prop:setDeck(self.lightDeck_)
  prop:setBlendMode(MOAIProp.GL_SRC_ALPHA, MOAIProp.GL_ONE)
  self.layer_:insertProp(prop)

  return prop
end

function LightMap:removeLight(prop)
  self.layer_:removeProp(prop)
end
