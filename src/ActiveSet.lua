-------------------------------------------------------------------------------
-- File:        ActiveSet.lua
-- Project:     RatOut
-- Author:      Cristian Cobzarenco
-- Description: ActiveSet rig, manages a set of objects allowing mapping
--              functions, registering update callbacks,
--
-- All rights reserved. Copyright (c) 2011-2012 Cristian Cobzarenco.
-- See http://www.nwydo.com
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
ActiveSet = {
  PASS_NOTHING         = 0,
  PASS_OBJECT          = 1,
  PASS_DATA            = 2,
  PASS_OBJECT_AND_DATA = 3,
}

-------------------------------------------------------------------------------
-- Public Methods
-------------------------------------------------------------------------------
function ActiveSet.new()
  local self = setmetatable( {}, { __index = ActiveSet } )
  
  self.objects_    = {}
  self.controllers_ = {}
  self.coroutine_   = MOAICoroutine.new()

  self.nControllers_ = 0
  self.nObjects_    = 0

  self.coroutineRunning_ = false

  return self
end

function ActiveSet:add( newObject, data )
  if self.objects_[ newObject ] == nil then
    -- Cannot use 'data or true' since that would disallow data == false.
    if data == nil then
      self.objects_[ newObject ] = true
    else
      self.objects_[ newObject ] = data
    end

    self.nObjects_ = self.nObjects_ + 1
    self:updateCoroutine_()
  else
    error(
      'ActiveSet:add(): ' .. 
      'Trying to add duplicate object.'
    )
  end
end

function ActiveSet:remove( object )
  if self.objects_[ object ] ~= nil then
    self.objects_[ object ] = nil
    self.nObjects_ = self.nObjects_ - 1
    self:updateCoroutine_()
  else
    error(
      'ActiveSet:remove(): ' .. 
      'Trying to remove non-member object.'
    )
  end
end

function ActiveSet:removeIfExists( object )
  if self.objects_[ object ] ~= nil then
    self.objects_[ object ] = nil
    self.nObjects_ = self.nObjects_ - 1
    self:updateCoroutine_()
  end
end

function ActiveSet:clearObjects()
  self.objects_  = {}
  self.nObjects_ = 0

  self:updateCoroutine_()
end

function ActiveSet:getObjectCount()
  return self.nObjects_
end

function ActiveSet:isMember( object )
  return self.objects_[ object ] ~= nil
end

function ActiveSet:lookup( object )
  return self.objects_[ object ]
end

function ActiveSet:callMethod( method, ... )
  for object, _ in pairs( self.objects_ ) do
    object[ method ]( object, unpack( arg ) )
  end
end

function ActiveSet:callMethodWithData( method, ... )
  for object, data in pairs( self.objects_ ) do
    object[ method ]( object, data, unpack( arg ) )
  end
end

function ActiveSet:applyFunction( fun, ... )
  for object, _ in pairs( self.objects_ ) do
    fun( object, unpack( arg ) )
  end
end

function ActiveSet:applyFunctionWithData( fun, ... )
  for object, data in pairs( self.objects_ ) do
    fun( object, data, unpack( arg ) )
  end
end

function ActiveSet:addController( controllerFun, mode )
  local fun

  if mode == ActiveSet.PASS_NOTHING then
    fun = function() controllerFun() end
  elseif mode == ActiveSet.PASS_OBJECT then
    fun = function( object, data ) controllerFun( object ) end
  elseif mode == ActiveSet.PASS_DATA then
    fun = function( object, data ) controllerFun( data ) end
  else
    fun = controllerFun
  end

  self.controllers_[ controllerFun ] = fun
  self.nControllers_ = self.nControllers_ + 1
  self:updateCoroutine_()
end

function ActiveSet:removeController( controllerFun )
  self.controllers_[ controllerFun ] = nil
  self.nControllers_ = self.nControllers_ - 1
  self:updateCoroutine_()
end

-------------------------------------------------------------------------------
-- Private Methods
-------------------------------------------------------------------------------
function ActiveSet:updateCoroutine_()
  local shouldRun = self.nControllers_ > 0 and self.nObjects_ > 0
  if shouldRun ~= self.coroutineRunning_ then
    self.coroutineRunning_ = shouldRun

    if shouldRun then
      self:startCoroutine_()
    else
      self:stopCoroutine_()
    end
  end
end

function ActiveSet:startCoroutine_()
  self.coroutineRunning_ = true

  function coroutineFun()
    while true do
      for ctrl, fun in pairs( self.controllers_ ) do
        for object, data in pairs( self.objects_ ) do
          fun( object, data )
        end
      end

      coroutine.yield()
    end
  end

  self.coroutine_:run( coroutineFun )
end

function ActiveSet:stopCoroutine_()
  self.coroutineRunning_ = false
  self.coroutine_:stop()
end
