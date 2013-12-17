--------------------------------------------------------------------------------
-- LevelCell Rig
--------------------------------------------------------------------------------
LevelCell = {}

function LevelCell.new( level )
  local self = setmetatable( {}, { __index = LevelCell } )

  self.globalDragCoeff_ = settings.world.global_drag

  -- Initialise size to zero and use reset() to generate the cell
  self.entities   = ActiveSet.new()
  self.dynamicSet = ActiveSet.new()

  -- Save level properties
  self.level       = level
  self.world       = level.world
  self.bgLayer     = level.bgLayer
  self.fgLayer     = level.fgLayer
  self.assets      = level.assets
  self.lightmap    = level.lightmap

  self:initDynamicController()

  return self
end

function LevelCell:initDynamicController()
  self.dynamicBodyController_ = function(body, entity)
    if not body or not body:isAwake() then
      return
    end
    
    local dragCoeff  = entity.dragCoefficient
    local posX, posY = body:getWorldCenter()
    local velX, velY = body:getLinearVelocity()
      
    dragCoeff = dragCoeff * self.globalDragCoeff_

    local speed     = math.sqrt( velX * velX + velY * velY )
    local dragForce = dragCoeff * speed
    local dragX, dragY

    dragX, dragY = - dragForce * velX, - dragForce * velY

    body:applyForce( dragX, dragY, posX, posY )
  end

  self.dynamicSet:addController(
      self.dynamicBodyController_, ActiveSet.PASS_OBJECT_AND_DATA)
end


function LevelCell:lookupBody( body )
  return self.level:lookupBody( body )
end

function LevelCell:addEntity( entity )
  self.entities:add( entity )
end

function LevelCell:removeEntity( entity )
  self.entities:remove( entity )
end

function LevelCell:registerDynamicBody( body, entity )
  self.dynamicSet:add( body, entity )
  self.level:registerBody( body, entity )
end

function LevelCell:registerStaticBody( body, entity )
  self.level:registerBody( body, entity )
end

function LevelCell:deregisterDynamicBody( body )
  self.level:deregisterBody( body )
  self.dynamicSet:remove( body )
end

function LevelCell:deregisterStaticBody( body )
  self.level:deregisterBody( body )
end

function LevelCell:destroy()
  if self.entities:getObjectCount() > 0 then
    self.entities:callMethod( 'destroy' )
    --self.dynamicSet:clearObjects()
    if self.entities:getObjectCount()>0 or self.dynamicSet:getObjectCount()>0 then
      print(
        ('LevelCell: Dirty destroy(): (ent %d; dyn %d)'):format(
          self.entities:getObjectCount(),
          self.dynamicSet:getObjectCount()
        )
      )
    end
  end
end

-------------------------------------------------------------------------------
-- Level rig
-------------------------------------------------------------------------------
Level = {}

function Level.new(world, bgLayer, fgLayer, overlayLayer, assets)
  local self = setmetatable({}, { __index = Level })
  
  self.world = world
  self.bgLayer = bgLayer
  self.fgLayer = fgLayer
  self.overlayLayer = overlayLayer
  self.assets = assets
  self.lightmap = LightMap.new(overlayLayer)

  self.bodyLookup = ActiveSet.new()

  if not settings.debug.no_sound then
    self.music = assets.music
    self.music:setLooping(true)
    self.music:play()
  end

  return self
end

function Level:nextLevel()
  self:reload(self.levelIndex_ + 1,
              settings.world.new_level_fade_color,
              settings.world.new_level_fade_time)
end

function Level:lose()
  self:showGameOver()
  function callback(key, down)
    if down == false then return end
    local coro = MOAICoroutine.new()
    coro:run(function()
      MOAIInputMgr.device.mouseLeft:setCallback(nil)
      self:reload()
    end)
  end
  MOAIInputMgr.device.mouseLeft:setCallback(callback)
end

function Level:reload(newIndex, fadeColor, fadeTime)
  if not fadeColor then fadeColor = settings.world.death_fade_color end
  if not fadeTime then fadeTime = settings.world.death_fade_time end
  if not newIndex then newIndex = self.levelIndex_ end
  if not self.bgDeck_ then
    self.bgDeck_ = MOAIGfxQuad2D.new()
    self.bgDeck_:setTexture(settings.levels[newIndex].background)
    self.bgDeck_:setRect(-Game.kScreenWidth / 2, -Game.kScreenHeight / 2,
                         Game.kScreenWidth / 2, Game.kScreenHeight / 2)
    self.outDeck_ = MOAIGfxQuad2D.new()
    self.outDeck_:setTexture(settings.levels[newIndex].outline)
    self.outDeck_:setRect(-Game.kScreenWidth / 2, -Game.kScreenHeight / 2,
                           Game.kScreenWidth / 2, Game.kScreenHeight / 2)
    self.background_ = MOAIProp2D.new();
    self.background_:setDeck(self.bgDeck_)
    self.background_:setPriority(settings.priorities.background)
    self.bgLayer:insertProp(self.background_)

    self.outline_ = MOAIProp2D.new();
    self.outline_:setDeck(self.outDeck_)
    self.outline_:setPriority(settings.priorities.lightmap - 1)
    self.overlayLayer:insertProp(self.outline_)
  end

  local fader = MOAIProp2D.new()
  fader:setDeck(self.assets.fader)
  fader:setPriority(settings.priorities.lightmap + 20)
  if self.globalCell then 
    fader:setColor(0, 0, 0, 0)
    self.overlayLayer:insertProp(fader)
    MOAICoroutine.blockOnAction(fader:seekColor(
        fadeColor[1], fadeColor[2], fadeColor[3], 1.0,
        fadeTime, MOAIEaseType.EASE_OUT))
    self.globalCell:destroy()
    self:removeText()
    self:removeGameOver()
    self.fgLayer:clear()
  else
    fader:setColor(fadeColor[1], fadeColor[2], fadeColor[3])
  end

  if newIndex == #settings.levels + 1 then
    MOAICoroutine.blockOnAction(
        fader:seekColor(0,0,0,1, 4.0, MOAIEaseType.SMOOTH))
    self:showEndText()
    return
  end

  self.globalCell = LevelCell.new(self)

  if newIndex ~= self.levelIndex_ then
    self.bgDeck_:setTexture(settings.levels[newIndex].background)
    self.outDeck_:setTexture(settings.levels[newIndex].outline)
    self.levelIndex_ = newIndex
  end

  local loader, err = loadfile(settings.levels[newIndex].definition_path)
  local levelDefinition

  if loader == nil then
    print('Cannot open level ' .. err)
  else
    levelDefinition = loader()
  end

  local scale = Game.kScreenWidth / levelDefinition.width
  local offsetX = -Game.kScreenWidth / 2
  local offsetY = -Game.kScreenHeight / 2

  self.player = Swimmer.new(self.globalCell, self.assets)
  self.player.body:setTransform(
    levelDefinition.Player.x * scale + offsetX,
    levelDefinition.Player.y * scale + offsetY)
  
  self.goal = Goal.new(self.globalCell, settings.entities.goal,
                       levelDefinition.Goal.x * scale + offsetX,
                       levelDefinition.Goal.y * scale + offsetY)

  local image_to_entity = {}
  image_to_entity["spikycoral.png"] = "coral_killer"
  image_to_entity["rockshards.png"] = "rock_killer"

  local killer_decks = {}
  local numDangers = #levelDefinition.Dangers
  for k, v in pairs(image_to_entity) do
    local deck = MOAIGfxQuadDeck2D.new()
    deck:reserve(numDangers)
    deck:setTexture(self.assets[v])
    killer_decks[v] = deck
  end

  function killerCallback()
    self.player:explode()
  end

  for k, v in pairs(levelDefinition.Dangers) do
    local entity_name = image_to_entity[v.link]
    if entity_name then
      local deck = killer_decks[entity_name]
      local entity = settings.entities[entity_name]
      for i = 1,4 do
        v[i].x = scale * v[i].x + offsetX
        v[i].y = scale * v[i].y + offsetY
      end
      Killer.new(self.globalCell, entity, deck, k, v, killerCallback)
    end
  end

  local numAlgae = #levelDefinition.Algae + #levelDefinition.LitAlgae
  local algaeOnDeck = MOAIGfxQuadDeck2D.new()
  local algaeOffDeck = MOAIGfxQuadDeck2D.new()
  local redAlgaeOnDeck = MOAIGfxQuadDeck2D.new()
  local redAlgaeOffDeck = MOAIGfxQuadDeck2D.new()
  algaeOnDeck:setTexture(self.assets.algae_glower)
  algaeOffDeck:setTexture(self.assets.algae_glower)
  redAlgaeOnDeck:setTexture(self.assets.red_algae_glower)
  redAlgaeOffDeck:setTexture(self.assets.red_algae_glower)

  algaeOnDeck:reserve(numAlgae)
  algaeOffDeck:reserve(numAlgae)
  redAlgaeOnDeck:reserve(numAlgae)
  redAlgaeOffDeck:reserve(numAlgae)
  local n
  for k, v in pairs(levelDefinition.Algae) do
      for i = 1,4 do
        v[i].x = scale * v[i].x + offsetX
        v[i].y = scale * v[i].y + offsetY
      end
      if v.link == "glowalgae_red_on.png" then
        Glower.new(self.globalCell, settings.entities.red_algae_glower,
                   redAlgaeOnDeck, redAlgaeOffDeck, k, v)
      else
        Glower.new(self.globalCell, settings.entities.algae_glower,
                   algaeOnDeck, algaeOffDeck, k, v)
      end
      n = k
  end

  for k, v in pairs(levelDefinition.LitAlgae) do
      for i = 1,4 do
        v[i].x = scale * v[i].x + offsetX
        v[i].y = scale * v[i].y + offsetY
      end
      Glower.new(self.globalCell, settings.entities.algae_glower,
                 algaeOnDeck, algaeOffDeck, k + n, v):setGlowing(true)
  end

  local cosmeticsDeck = MOAIGfxQuadDeck2D.new()
  cosmeticsDeck:reserve(#levelDefinition.Cosmetics)
  cosmeticsDeck:setTexture(self.assets.cosmetics)
  for k, v in pairs(levelDefinition.Cosmetics) do
      for i = 1,4 do
        v[i].x = scale * v[i].x + offsetX
        v[i].y = scale * v[i].y + offsetY
      end

      local prop = createPropFromVerts(cosmeticsDeck, k, v)
      cosmeticsDeck:setUVRect(
          k, unpack(settings.entities.cosmetics.link_to_uv[v.link]))
      prop:setPriority(settings.priorities.doodads)
      self.fgLayer:insertProp(prop)
  end

  self:addText(levelDefinition)

  ObstaclePath.new(
      self.globalCell, levelDefinition.Collisions, scale, offsetX, offsetY)

  MOAICoroutine.blockOnAction(fader:seekColor(0, 0, 0, 0, fadeTime,
                                              MOAIEaseType.EASE_OUT))
  self.overlayLayer:removeProp(fader)
end

function Level:addText(def)
  if not def.Text then return end

  local scale = Game.kScreenWidth / def.width
  local offsetX = -Game.kScreenWidth / 2
  local offsetY = -Game.kScreenHeight / 2

  self.textProps_ = {}

  for k, v in pairs(def.Text) do
    for i = 1,4 do
      v[i].x = scale * v[i].x + offsetX
      v[i].y = scale * v[i].y + offsetY
    end

    local deck = MOAIGfxQuad2D.new()
    local prop = createPropFromVerts(deck, nil, v)

    deck:setTexture('assets/' .. v.link)
    prop:setPriority(settings.priorities.hud)
    prop:setColor(0, 0, 0, 0)
    self.overlayLayer:insertProp(prop)
    local m = 0.0
    if k == 4 then m = 6 end;
    defer(2.4 * (k - 1) + m,
          function()
            prop:seekColor(0.8, 0.8, 0.8, 0.8, 2.0, MOAIEaseType.EASE_OUT)
            defer(3.0, function()
              if k ~= 4 then
                prop:seekColor(0.6, 0.6, 0.6, 0.6, 1.0, MOAIEaseType.SMOOTH)
              else
                prop:seekColor(0.3, 0.3, 0.3, 0.3, 4.0, MOAIEaseType.SMOOTH)
              end
            end)
          end)

    self.textProps_[k] = prop
  end
end

function Level:showEndText()
  local prop = MOAIProp2D.new()
  prop:setDeck(self.assets.thankyou_text)
  prop:setLoc(0, 10)
  prop:seekLoc(-10, 10, 4.0, MOAIEaseType.EASE_IN)
  prop:setPriority(1000)
  prop:setColor(0, 0, 0, 0)
  self.overlayLayer:insertProp(prop)
  MOAICoroutine.blockOnAction(prop:seekColor(0.8, 0.8, 0.8, 1.0, 3.0, MOAIEaseType.SMOOTH))

  prop = MOAIProp2D.new()
  prop:setDeck(self.assets.vote_text)
  prop:setLoc(0, -10)
  prop:seekLoc(10, -10, 4.0, MOAIEaseType.EASE_IN)
  prop:setPriority(1000)
  prop:setColor(0, 0, 0, 0)
  self.overlayLayer:insertProp(prop)
  prop:seekColor(0.8, 0.8, 0.8, 1.0, 4.0, MOAIEaseType.SMOOTH)
end

function Level:removeText()
  if self.textProps_ then
    for k, v in pairs(self.textProps_) do
      self.overlayLayer:removeProp(v)
    end
  end
end

function Level:hideText()
  if self.textProps_ then
    for k, v in pairs(self.textProps_) do
      v:seekColor(0,0,0,0, 2.0, MOAIEaseType.EASE_IN)
    end
  end
end

function Level:showGameOver()
  local prop = MOAIProp2D.new()
  prop:setDeck(self.assets.game_over_text)
  prop:setPriority(settings.priorities.hud)
  prop:setColor(0, 0, 0, 0)
  defer(1.0, function()
    prop:seekColor(0.8, 0.8, 0.8, 1.0, 1.0, MOAIEaseType.EASE_IN)
    defer(0.5, function()
      prop:seekColor(0.5, 0.5, 0.5, 1.0, 1.0, MOAIEaseType.SMOOTH)
    end)
  end)
  self.overlayLayer:insertProp(prop)
  self.gameOverProp_ = prop
  self:hideText()
end

function Level:removeGameOver()
  if self.gameOverProp_ then
    self.overlayLayer:removeProp(self.gameOverProp_)
    self.gameOverProp_ = nil
  end
end

function Level:registerBody( body, entity )
  self.bodyLookup:add( body, entity )
end

function Level:deregisterBody( body )
  self.bodyLookup:remove( body )
end

function Level:lookupBody( body )
  return self.bodyLookup:lookup( body )
end

function Level:setCamera( camera )
  self.camera = camera
end

function Level:setPlayer( player )
  self.player = player
end

function Level:pause()

end

function Level:unpause()

end


