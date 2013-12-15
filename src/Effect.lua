-------------------------------------------------------------------------------
-- File:        Effect.lua
-- Project:     RatOut
-- Author:      Cristian Cobzarenco
-- Description: Effect rig, manages a temporary effect on an entity at an
--              abstract level.
--
-- All rights reserved. Copyright (c) 2011-2012 Cristian Cobzarenco.
-- See http://www.nwydo.com
-------------------------------------------------------------------------------

Effect = {}

function Effect.attach( effectType, entity )
  effect = entity:getEffect( effectType )

  if not effect then
    local self = setmetatable( {}, {__index=effectType} )
  
    self.destroyListener_ = function() self:detach() end
    self.updateListener_  = function() self:onUpdate() end
    self.effectType_      = effectType
    entity:addEffect( effectType, self )
    entity:addDestroyListener( self.destroyListener_ )

    self.timer_     = nil
    self.timerSpan_ = 0
    self.updatable_ = false
    self.attached_  = true
    self.entity_    = entity

    self:onAttach()

    return self
  else
    effect:onRefresh()

    return effect
  end
end

function Effect:getEntity()
  return self.entity_
end

function Effect:getTimer()
  return self.timer_
end

function Effect:getTimeLeft()
  if not self.timer_ then
    return nil
  end

  return self.timerSpan_ - self.timer_:getTime()
end

function Effect:detach()
  if not self.attached_ then
    return
  end

  self:onDetach()
  self:setUpdatable( false )
  self:setTimeLimit( nil )

  self.entity_:removeDestroyListener( self.destroyListener_ )
  self.entity_:removeEffect( self.effectType_ )

  self.attached_ = false
  self.entity_   = nil
end


function Effect:setTimeLimit( timeLimit )
  if timeLimit then
    if self.timer_ == nil then
      self.timer_ = MOAITimer.new()
      self.timer_:setListener( MOAITimer.EVENT_TIMER_END_SPAN,
        function( _, _ )
          self:onTimeout()
        end
      )
    end

    self.timer_:setTime( 0 )
    self.timer_:setSpan( timeLimit )
    self.timer_:start()

    self.timerSpan_ = timeLimit
  else
    self.timer_:stop()
    self.timer_:setListener( MOAITimer.EVENT_TIMER_LOOP, nil )
    self.timer_ = nil
    self.timerSpan_ = nil
  end
end

function Effect:setUpdatable( updatable )
  if updatable ~= self.updatable_ then
    self.updatable_ = updatable

    if self.updatable_ then
      self.entity_:addUpdateListener( self.updateListener_ )
    else
      self.entity_:removeUpdateListener( self.updateListener_ )
    end
  end
end

function Effect:onAttach()

end

function Effect:onDetach()

end

function Effect:onUpdate()

end

function Effect:onRefresh()

end

function Effect:onTimeout()
  self:detach()
end
