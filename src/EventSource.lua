-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
EventSource = {}
RemoveListenerReturnValue = {}

-------------------------------------------------------------------------------
-- Public Methods
-------------------------------------------------------------------------------

function EventSource.new()
  local self = setmetatable( {}, { __index = EventSource } )

  self.listeners_  = {}
  self.nListeners_ = 0

  return self
end

function EventSource:getListenerCount()
  return self.nListeners_
end

function EventSource:hasListener( listener )
  return self.listeners_[ listener ] == true
end

function EventSource:addListener( listener )
  if not self.listeners_[ listener ] then
    self.listeners_[ listener ] = true
    self.nListeners_ = self.nListeners_ + 1
  end
end

function EventSource:removeListener( listener )
  if self.listeners_[ listener ] then
    self.listeners_[ listener ] = nil
    self.nListeners_ = self.nListeners_ - 1
  end
end

function EventSource:emit( ... )
  local rmlist = {}

  if arg.n > 0 then
    for listener, _ in pairs( self.listeners_ ) do
      local r = listener( unpack( arg ) )
      
      if r == RemoveListenerReturnValue then
        rmlist[ listener ] = true
      end
    end
  else
    for listener, _ in pairs( self.listeners_ ) do
      local r = listener()
      
      if r == RemoveListenerReturnValue then
        rmlist[ listener ] = true
      end
    end
  end

  for listener, _ in pairs( rmlist ) do
    self:removeListener( listener )
  end
end

