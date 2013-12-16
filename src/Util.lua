-------------------------------------------------------------------------------
-- File:        util.lua
-- Project:     RatOut
-- Author:      Cristian Cobzarenco
-- Description: Utility rigs and functions.
--
-- All rights reserved. Copyright (c) 2011-2012 Cristian Cobzarenco.
-- See http://www.nwydo.com
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- Free functions
-------------------------------------------------------------------------------

RADIANS_TO_DEGREES = 180.0 / math.pi
DEGREES_TO_RADIANS = 1.0 / RADIANS_TO_DEGREES

function debugf( fmt, ... )
  fmt = (debug.getinfo(2).source or '<unknown>') .. ': ' .. (debug.getinfo(2).name or '<unknown>') .. '(): ' .. fmt
  print( fmt:format( ... ) )
end

function dumpMembersOf( obj, prefix )
  if type( obj ) ~= 'table' then
    print( prefix .. 'Atom of type \'' .. type(obj) .. '\'' )
  else
    for k, v in pairs( obj ) do
      print( prefix .. ('%-32s %-32s (%8s)'):format( k, tostring(v), type(v) ) ) 
    end

    local mt = getmetatable( obj )

    if mt and type( mt.__index ) == 'table' then
      dumpMembersOf( mt.__index, prefix .. '  ' )
    end
  end
end

function randomf( lower, upper )
  return math.random() * (upper - lower) + lower
end

function difficultyFun( y, multiplier )
  local difficulty = math.sqrt( math.max( y, 0 ) ) * multiplier + 1.0
  return difficulty
end

function cosd( angleInDegrees )
  return math.cos( angleInDegrees * DEGREES_TO_RADIANS )
end

function sind( angleInDegrees )
  return math.sin( angleInDegrees * DEGREES_TO_RADIANS )
end

function vecFromAngled( angleInDegrees )
  local x = angleInDegrees * DEGREES_TO_RADIANS
  return math.cos( x ), math.sin( x )
end

function clamp( value, left, right )
  if value < left then
    return left
  elseif value > right then
    return right
  else
    return value
  end
end

function pureRandomInt( x )
  local m = 2^31
  local n = 2^15
  local p = 2^16

  function iterate()
    local k = math.floor( x / p )
    x = (1103515245 * x + 12345) % m
    return k
  end

  iterate()

  return iterate()
end

function pureRandomFloat( x )
  local m = 2^31
  local n = 2^15
  local p = 2^16

  function iterate()
    local k = x / p
    x = (1103515245 * x + 12345) % m
    return k
  end

  iterate()
  iterate()
  iterate()

  return iterate() / n
end

function pureRandomIntInRange( x, a, b )
  return pureRandom( x ) * ( b - a + 1 ) + a
end

function smoothedPureRandom( x )
  return (pureRandomFloat( x ) * .5 + pureRandomFloat( x - 1 ) * .25 + pureRandomFloat( x + 1 ) * .25)*2.0-1.0
end

function interpolateCosine( a, b, frac )
  local ft = frac * math.pi
  local f = ( 1.0 - math.cos( ft ) ) * .5

  return a * ( 1.0 - f ) + b * f
end

function intepolateCubic( v0, v1, v2, v3, x )
  local P = (v3 - v2) - (v0 - v1)
  local Q = (v0 - v1) - P
  local R = v2 - v0
  local S = v1

  local x2 = x * x
  local x3 = x3 * x

  return P*x3 + Q*x2 + R*x + S
end

function interpolatedNoise1D( x )
  intX  = math.floor( x )
  fracX = x - intX

  v1 = smoothedPureRandom( intX )
  v2 = smoothedPureRandom( intX + 1 )

  return interpolateCosine( v1, v2, fracX )
end

function perlinNoise1D( x, persistence, octaves )
  local total     = 0
  local n         = octaves - 1
  local freq      = 1.0
  local amplitude = 1.0

  while octaves >= 0 do
    total     = total + interpolatedNoise1D( x * freq ) * amplitude
    freq      = freq * 2.0
    amplitude = amplitude * persistence
    octaves   = octaves - 1 
  end

  return total
end

function createPropFromVerts(deck, idx, verts)
  deck:setQuad(idx,
               verts[1].x, verts[1].y, verts[2].x, verts[2].y,
               verts[3].x, verts[3].y, verts[4].x, verts[4].y)

  local prop = MOAIProp2D.new()
  prop:setDeck(deck)
  prop:setIndex(idx)

  return prop
end

function createAlignedRectFromVerts(body, verts, xscale, yscale)
  local dx, dy = verts[2].x - verts[1].x, verts[2].y - verts[1].y
  local angle = math.atan2(dy, dx)
  local sprite_width = math.sqrt(dx * dx + dy * dy)
  dx, dy = verts[1].x - verts[3].x, verts[1].y - verts[3].y
  local sprite_height = math.sqrt(dx * dx + dy * dy)
  local fixw, fixh = (1 - xscale) * sprite_width / 2, yscale * sprite_height

  local fixture = body:addRect(fixw, 0, sprite_width - fixw, fixh, 0)
  body:setTransform(verts[4].x, verts[4].y, angle*180/math.pi)

  return fixture
end


-------------------------------------------------------------------------------
-- Rig:     LinearRNG
-- Extends: Nothing
-------------------------------------------------------------------------------
LinearRNG = {}

function LinearRNG.new( seed )
  local self = setmetatable( {
    current = seed,
    m       = 2 ^ 31,
    n       = 2 ^ 15,
    p       = 2 ^ 16
  }, { __index = LinearRNG } )
  
  self:next()
  self:next()
  
  return self
end

function LinearRNG:reseed( seed )
  self.current = seed
  self:next()
  self:next()
end

function LinearRNG:next()
  local k = math.floor( self.current / self.p ) 
  self.current = (1103515245 * self.current + 12345) % self.m
  return k
end


function LinearRNG:nextInt( a, b )
  return self:next() % (b - a + 1) + a
end

function LinearRNG:nextFloat( a, b )
  if a == nil then
    return self:next() / self.n
  else
    return self:nextFloat() * (b - a) + a
  end
end

function LinearRNG:clone()
  return setmetatable( {
    current = self.current,
    m       = self.m,
    n       = self.n,
    p       = self.p
  }, { __index = LinearRNG }
  )
end
-------------------------------------------------------------------------------
-- TargetFollower rig
-------------------------------------------------------------------------------
TargetFollower = {}

function TargetFollower.new( initial )
  local self = {}
  
  TargetFollower.reset( self, initial )
  
  return setmetatable( self, { __index = TargetFollower } )
end

function TargetFollower:follow( target, dt )  
  local error      = target - (self.current+self.speed*dt*3)
  local derivative = (error - self.previousError) / dt
  local control    = error * 32 + derivative * 4
  
  self.speed   = self.speed + control * dt
  
  self.current = self.current + self.speed * dt
  
  self.previousError  = error
  -- self.previousTarget = target
  
  return self.current
end

function TargetFollower:getCurrent()
  return self.current
end

function TargetFollower:reset( value )
  self.current        = value
  self.speed          = 0
  self.previousError  = 0
  self.previousTarget = value
end

function testflag(set, flag)
  return set % (2*flag) >= flag
end

function setflag(set, flag)
  if set % (2*flag) >= flag then
    return set
  end

  return set + flag
end

function clrflag(set, flag) -- clear flag
  if set % (2*flag) >= flag then
    return set - flag
  end
  
  return set
end
