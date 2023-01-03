package.path = "./?.lua;" .. package.path .. ";../?.lua;../src/?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test/utils" )
test_utils.mock_wow_api()
test_utils.load_libstub()
local utils = require( "src/ItemUtils" )

ItemUtilsSpec = {}

function ItemUtilsSpec:should_get_item_id_from_item_link()
  -- Given
  local link = "|cffa335ee|Hitem:40400::::::::80:::::|h[Wall of Terror]|h|r"

  -- When
  local result = utils.get_item_id( link )

  -- Then
  lu.assertEquals( result, 40400 )
end

function ItemUtilsSpec:should_return_nil_if_not_an_item_link()
  -- Given
  local link = "Princess Kenny"

  -- When
  local result = utils.get_item_id( link )

  -- Then
  lu.assertIsNil( result )
end

function ItemUtilsSpec:should_get_item_name_from_item_link()
  -- Given
  local link = "|cffa335ee|Hitem:40400::::::::80:::::|h[Wall of Terror]|h|r"

  local result = utils.get_item_name( link )

  -- Then
  lu.assertEquals( result, "Wall of Terror" )
end

function ItemUtilsSpec:should_return_given_string_if_not_an_item_link()
  -- Given
  local link = "Princess Kenny"

  local result = utils.get_item_name( link )

  -- Then
  lu.assertEquals( result, "Princess Kenny" )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

os.exit( runner:runSuite( "-m", "should", "-T", "Spec", "-v" ) )
