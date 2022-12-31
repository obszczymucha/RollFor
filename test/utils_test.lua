package.path = "./?.lua;" .. package.path .. ";../?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )

---@diagnostic disable-next-line: lowercase-global
function should_replace_colors()
  -- Given
  local input = "|cff209ff9RollFor|r: Loaded (|cffff9f69v1.12|r)."

  -- When
  local result = utils.replace_colors( input )

  -- Then
  lu.assertEquals( result, "RollFor: Loaded (v1.12)." )
end

---@diagnostic disable-next-line: lowercase-global
function should_parse_item_link()
  -- Given
  local input = utils.item_link( "Hearthstone" )

  -- When
  local result = utils.parse_item_link( input )

  -- Then
  lu.assertEquals( result, "[Hearthstone]" )
end

---@diagnostic disable-next-line: lowercase-global
function should_flatten_a_table_into_another_table()
  -- Given
  local function f( a, b ) return function() return a, b end end

  local input = { "a", { "b", "d" }, f( { "e" }, "f" ), "c" }
  local result = {}

  -- When
  utils.flatten( result, input )

  -- Then
  lu.assertEquals( result, { "a", { "b", "d" }, { "e" }, "f", "c" } )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

os.exit( runner:runSuite( "-t", "should", "-v" ) )
