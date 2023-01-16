package.path = "./?.lua;" .. package.path .. ";../?.lua;../Libs/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
utils.load_libstub()
local mod = require( "src/modules" )

MapSpec = {}

function MapSpec:should_map_simple_array()
  -- Given
  local map = mod.map
  local f = string.upper

  -- Expect
  lu.assertEquals( map( { "abc", "def" }, f ), { "ABC", "DEF" } )
  lu.assertEquals( map( {}, f ), {} )
end

function MapSpec:should_map_an_array_of_objects()
  -- Given
  local map = mod.map
  local f = string.upper

  -- Expect
  lu.assertEquals( map( {
    { name = "abc", roll = 69 },
    { name = "def", roll = 100 }
  }, f, "name" ), {
    { name = "ABC", roll = 69 },
    { name = "DEF", roll = 100 }
  } )
end

FilterSpec = {}

function FilterSpec:should_filter_simple_array()
  -- Given
  local filter = mod.filter
  local f = function( x ) return x > 3 end

  -- Expect
  lu.assertEquals( filter( { 1, 2, 3, 4, 5, 6 }, f ), { 4, 5, 6 } )
  lu.assertEquals( filter( {}, f ), {} )
end

function FilterSpec:should_filter_an_array_of_objects()
  -- Given
  local filter = mod.filter
  local f = function( x ) return x > 70 end

  -- Expect
  lu.assertEquals( filter( {
    { name = "abc", roll = 69 },
    { name = "def", roll = 100 },
    { name = "ghi", roll = 88 }
  }, f, "roll" ), {
    { name = "def", roll = 100 },
    { name = "ghi", roll = 88 }
  } )
end

os.exit( lu.LuaUnit.run() )
