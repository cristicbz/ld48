-------------------------------------------------------------------------------
-- File:        Entity.lua
-- Project:     RatOut
-- Author:      Cristian Cobzarenco
-- Description: Entity rig, manages a set of entities.
--
-- All rights reserved. Copyright (c) 2011-2012 Cristian Cobzarenco.
-- See http://www.nwydo.com
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
Entity = {}

-------------------------------------------------------------------------------
-- Public Methods
-------------------------------------------------------------------------------
function Entity.new( cell )
  local self = setmetatable( {}, { __index = Entity } )

  self.cell = cell

  self.updateSource_  = EventSource.new()
  self.destroySource_ = EventSource.new()
  self.effects_       = {}
  self.isDestroyed_   = false

  cell:addEntity( self )

  return self
end

function Entity:addEffect( effectType, effectInstance )
  self.effects_[ effectType ] = effectInstance
end

function Entity:getEffect( effectType )
  return self.effects_[ effectType ]
end

function Entity:removeEffect( effectType )
  self.effects_[ effectType ] = nil
end

function Entity:hasDestroyListener( listener )
  return self.destroySource_:hasListener( listener )
end

function Entity:hasUpdateListener( listener )
  return self.updateSource_:hasListener( listener )
end

function Entity:addDestroyListener( newListener )
  self.destroySource_:addListener( newListener )
end

function Entity:removeDestroyListener( listener )
  self.destroySource_:removeListener( listener )
end

function Entity:addUpdateListener( newListener )
  if self.updateSource_:getListenerCount() == 0 then
    self.updater_ = MOAICoroutine.new()

    self.updater_:run(
      function()
        while true do
          if self.isDestroyed_ then
            break
          end

          self.updateSource_:emit( self )
          coroutine.yield()
        end
      end
    )
  end

  self.updateSource_:addListener( newListener )
end

function Entity:removeUpdateListener( listener )
  if self.updateSource_:getListenerCount() == 1 then
    self.updater_:stop()
    self.updater_ = nil
  end

  self.updateSource_:removeListener( listener )
end

function Entity:destroy()
  self.destroySource_:emit( self )
  self.cell:removeEntity( self )

  self.destroySource_ = nil
  self.updateSource_  = nil

  self.isDestroyed_   = true
end
