package.path = "./?.lua;" .. package.path .. ";../?.lua;../src/?.lua;../Libs/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test/utils" )
test_utils.mock_wow_api()
test_utils.load_libstub()
require( "src/modules" )
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

  -- When
  local result = utils.get_item_name( link )

  -- Then
  lu.assertEquals( result, "Wall of Terror" )
end

function ItemUtilsSpec:should_return_given_string_if_not_an_item_link()
  -- Given
  local link = "Princess Kenny"

  -- When
  local result = utils.get_item_name( link )

  -- Then
  lu.assertEquals( result, "Princess Kenny" )
end

ParseAllLinksSpec = {}

function ParseAllLinksSpec:should_return_empty_table_for_nil()
  -- When
  local result = utils.parse_all_links()

  -- Expect
  lu.assertEquals( result, {} )
end

function ParseAllLinksSpec:should_return_empty_table_for_empty_string()
  -- When
  local result = utils.parse_all_links( "" )

  -- Expect
  lu.assertEquals( result, {} )
end

function ParseAllLinksSpec:should_return_empty_table_if_no_links_are_provided()
  -- When
  local result = utils.parse_all_links( "Princess Kenny" )

  -- Expect
  lu.assertEquals( result, {} )
end

function ParseAllLinksSpec:should_return_one_item_if_one_link_is_provided()
  -- When
  local result = utils.parse_all_links( test_utils.item_link( "Hearthstone", 123 ) )

  -- Expect
  lu.assertEquals( result, {
    test_utils.item_link( "Hearthstone", 123 )
  } )
end

function ParseAllLinksSpec:should_return_multiple_items_if_multiple_links_are_provided()
  -- Given
  local input = test_utils.item_link( "Hearthstone", 123 ) .. test_utils.item_link( "Poo", 111 )

  -- When
  local result = utils.parse_all_links( input )

  -- Expect
  lu.assertEquals( result, {
    test_utils.item_link( "Hearthstone", 123 ),
    test_utils.item_link( "Poo", 111 )
  } )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

os.exit( runner:runSuite( "-m", "should", "-T", "Spec", "-v" ) )
