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
  self.globalCell = LevelCell.new(self)

  return self
end

function Level:reload()
  local bgDeck = MOAIGfxQuad2D.new()
  bgDeck:setTexture(settings.levels[1].background)
  bgDeck:setRect(-Game.kScreenWidth / 2, -Game.kScreenHeight / 2,
                  Game.kScreenWidth / 2, Game.kScreenHeight / 2)
  self.background_ = MOAIProp2D.new();
  self.background_:setDeck(bgDeck)

  self.bgLayer:insertProp(self.background_)

  local loader, err = loadfile(settings.levels[1].definition_path)
  local levelDefinition

  if loader == nil then
    print('Cannot open level ' .. err)
  else
    levelDefinition = loader()
  end

  local scale = Game.kScreenWidth / levelDefinition.width
  local offsetX = -Game.kScreenWidth / 2
  local offsetY = -Game.kScreenHeight / 2

  self.player.body:setTransform(
    levelDefinition.Player.x * scale + offsetX,
    levelDefinition.Player.y * scale + offsetY)

  for k, v in pairs(levelDefinition.Dangers)  do
    local light = self.lightmap:addLight()
    light:setLoc(v.x * scale + offsetX, v.y * scale + offsetY)
    light:setScl(2.0)
    light:setColor(0.0, 1.0, 0.0, 1.0)
  end
  

  ObstaclePath.new(
      self.globalCell, levelDefinition.Collisions, scale, offsetX, offsetY)
  
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


