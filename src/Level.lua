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
    if self.entities:getObjectCount() > 0 or
       self.dynamicSet:getObjectCount() > 0 then
      print(
        ('LevelCell: Dirty destroy(): (ent %d; dyn %d)'):format(
          self.entities:getObjectCount(),
          self.dynamicSet:getObjectCount()
        )
      )
    end
  end
end

Decker = {}

function Decker.new()
  local self = setmetatable({}, {__index = Decker})
  self.deckInfos_ = {}
  return self
end

function Decker:getInfo(filename)
  local deckInfo = self.deckInfos_[filename]
  if deckInfo then return deckInfo end

  deckInfo = {}
  deckInfo.deck = MOAIGfxQuadDeck2D.new()
  deckInfo.deck:setTexture(filename)
  deckInfo.deck:reserve(8)
  deckInfo.capacity = 8
  deckInfo.used = 0
  deckInfo.xy = {}
  deckInfo.uv = {}
  self.deckInfos_[filename] = deckInfo

  return deckInfo
end

function Decker:makePropForFile(filename, xy, uv, absolute)
  return self:makePropForInfo(self:getInfo(filename), xy, uv, absolute)
end

function Decker:makePropForInfo(info, xy, uv, absolute)
  local deck = info.deck
  local prop = MOAIProp2D.new()

  uv = uv or {0.0, 1.0, 1.0, 0.0}

  if info.used == info.capacity then
    info.capacity = info.capacity * 2
    deck:reserve(info.capacity)
    for i = 1, info.used do
      deck:setQuad(i, unpack(info.xy[i]))
      deck:setUVRect(i, unpack(info.uv[i]))
    end
  end

  local index = info.used + 1
  local cx, cy = 0, 0
  if not absolute then 
    cx = (xy[1] + xy[3] + xy[5] + xy[7]) * .25
    cy = (xy[2] + xy[4] + xy[6] + xy[8]) * .25
    for i = 1,4 do
      xy[i * 2 - 1] = xy[i * 2 - 1] - cx
      xy[i * 2] = xy[i * 2] - cy
    end
    prop:setLoc(cx, cy)
  end

  info.uv[index] = uv
  info.xy[index] = xy
  deck:setQuad(index, unpack(xy))
  deck:setUVRect(index, unpack(uv))

  prop:setDeck(deck)
  prop:setIndex(index)
  
  info.used = index

  return prop, cx, cy, xy
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
  self.decker = Decker.new()

  if not settings.debug.no_sound then
    self.music = assets.music
    self.music:setLooping(true)
    self.music:play()
  end

  self.bgDeck_ = MOAIGfxQuad2D.new()
  self.outDeck_ = MOAIGfxQuad2D.new()
  self.bgDeck_:setRect(-Game.kScreenWidth / 2, -Game.kScreenHeight / 2,
                       Game.kScreenWidth / 2, Game.kScreenHeight / 2)
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

  self:initFactories_()

  local t = MOAITimer.new()
  t:setSpan(2.0)
  t:setMode(MOAITimer.LOOP)
  t:setListener(MOAITimer.EVENT_TIMER_LOOP,
                function()
                  print('Draw count:', MOAIRenderMgr.getPerformanceDrawCount())
                end)
  t:start()

  return self
end

function Level:initFactories_()
  local decoration_helper = function(level, object)
    local uv = settings.entities.decorations.subclass_to_uv[object.subclass]
    local tex = settings.entities.decorations.texture_path
    local prop = level.decker:makePropForFile(tex, object.poly, uv, true)
    prop:setPriority(settings.priorities.doodads)
    level.fgLayer:insertProp(prop)
  end

  local killer_helper = function(opts)
    return function(level, object)
      return Killer.new(
          level.globalCell, opts, level.decker, object.poly,
          function() level.player:explode() end)
    end
  end

  local glower_helper = function(opts)
    return function(level, object)
      return Glower.new(
          level.globalCell, opts, level.decker, object.poly)
    end
  end

  local lit_glower_helper = function(opts)
    return function(level, object)
      local glower = Glower.new(
          level.globalCell, opts, level.decker, object.poly)
      glower:setGlowing(true)
      return glower
    end
  end

  self.factories_ = {
    ["decoration1"] = decoration_helper,
    ["decoration2"] = decoration_helper,
    ["decoration3"] = decoration_helper,
    ["shards"] = killer_helper(settings.entities.rock_killer),
    ["coral"] = killer_helper(settings.entities.coral_killer),
    ["green_glower_off"] = glower_helper(settings.entities.green_algae_glower),
    ["green_glower_on"] = lit_glower_helper(settings.entities.green_algae_glower),
    ["red_glower_off"] = glower_helper(settings.entities.red_algae_glower),
  }
end

function Level:nextLevel()
  local nextIndex = self.defIndex_ + 1
  if nextIndex == #settings.levels + 1 then
    self:fadeScreenIn(settings.world.new_level_fade_color,
                      settings.world.new_level_fade_time)
    self:endOfGameHack()
  else
    self:fadeScreenIn(settings.world.new_level_fade_color,
                      settings.world.new_level_fade_time)
    self:loadByIndex(nextIndex)
    self:fadeScreenOut(settings.world.new_level_fade_time)
  end
end

function Level:lose()
  self:showGameOver()
  function callback(key, down)
    if down == false then return end
    local coro = MOAICoroutine.new()
    coro:run(function()
      MOAIInputMgr.device.mouseLeft:setCallback(nil)
      self:restart()
    end)
  end
  MOAIInputMgr.device.mouseLeft:setCallback(callback)
end

function Level:fadeScreenIn(color, time)
  local fader = MOAIProp2D.new()
  fader:setDeck(self.assets.fader)
  fader:setPriority(settings.priorities.lightmap + 20)

  if self.globalCell then 
    fader:setColor(0, 0, 0, 0)
    self.overlayLayer:insertProp(fader)
    MOAICoroutine.blockOnAction(fader:seekColor(
        color[1], color[2], color[3], 1.0, time, MOAIEaseType.EASE_OUT))
  else
    fader:setColor(color[1], color[2], color[3])
  end

  self.fader_ = fader
end

function Level:fadeScreenOut(time)
  local fader = self.fader_
  MOAICoroutine.blockOnAction(fader:seekColor(0, 0, 0, 0, time,
                                              MOAIEaseType.EASE_OUT))
  self.overlayLayer:removeProp(fader)
  self.fader_ = nil
end

function Level:loadDefinition(index)
  if not index then index = self.defIndex_
  else self.defIndex_ = index end

  local loader, err = loadfile(settings.levels[self.defIndex_].definition_path)
  if loader == nil then print('Cannot open level ' .. err)
  else def = loader() end

  return def
end

function Level:clearTransients_()
  if self.transientCell_ then self.transientCell_:destroy() end
  self.transientCell_ = LevelCell.new(self, assets)
end

function Level:restart()
  local def = self:loadDefinition()
  local fadeColor = settings.world.death_fade_color
  local fadeTime = settings.world.death_fade_time
  self:fadeScreenIn(fadeColor, fadeTime)
  self:removeGameOver()
  self:clearTransients_()
  self:createTransients_(def)
  self:fadeScreenOut(fadeTime)

end

function Level:createTransients_(def)
  self.player = Swimmer.new(self.transientCell_, self.assets)
  self.player.body:setTransform(def.player[1].circle[1], def.player[1].circle[2])
end

function Level:clearCells_()
  self.fgLayer:clear()
  self:removeText()
  self:clearTransients_()
  if self.globalCell then self.globalCell:destroy() end
  self.globalCell = LevelCell.new(self, assets)
end

function Level:endOfGameHack()
    MOAICoroutine.blockOnAction(
        self.fader_:seekColor(0, 0, 0, 1, 4.0, MOAIEaseType.SMOOTH))
    self:showEndText()
end

function Level:loadByIndex(newIndex)
  local def = self:loadDefinition(newIndex)

  self:clearCells_()
  self.bgDeck_:setTexture(settings.levels[newIndex].background)
  self.outDeck_:setTexture(settings.levels[newIndex].outline)

  self:createTransients_(def)
  self.goal = Goal.new(
      self.globalCell, settings.entities.goal, unpack(def.goal[1].circle))

  for _, path in pairs(def.collisions) do
    ObstaclePath.new(self.globalCell, path.poly)
  end

  for _, doodad in pairs(def.doodads) do
    local subclass = doodad.subclass or 'doodad'
    local factory = self.factories_[subclass]
    if not factory then
      print('Skipping unknown doodad subclass "' .. subclass .. '".')
    else
      factory(self, doodad)
    end
  end
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
  prop:setLoc(-9, 10)
  prop:seekLoc(-10, 10, 4.0, MOAIEaseType.EASE_IN)
  prop:setPriority(1000)
  prop:setColor(0, 0, 0, 0)
  self.overlayLayer:insertProp(prop)
  MOAICoroutine.blockOnAction(prop:seekColor(0.8, 0.8, 0.8, 1.0, 3.0, MOAIEaseType.SMOOTH))

  prop = MOAIProp2D.new()
  prop:setDeck(self.assets.vote_text)
  prop:setLoc(9, -10)
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


