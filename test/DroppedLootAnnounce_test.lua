package.path = "./?.lua;" .. package.path .. ";../?.lua;../src/?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test/utils" )
test_utils.mock_wow_api()
require( "LibStub" )
require( "ModUi/facade" )
require( "src/ItemUtils" )
local mod = require( "src/DroppedLootAnnounce" )

DroppedLootAnnounceSpec = {}

function DroppedLootAnnounceSpec:should_create_item_details()
  -- When
  local result = mod.item( 123, "Hearthstone", "fake link", 4 )

  -- Expect
  lu.assertEquals( result.id, 123 )
  lu.assertEquals( result.name, "Hearthstone" )
  lu.assertEquals( result.link, "fake link" )
  lu.assertEquals( result.quality, 4 )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

os.exit( runner:runSuite( "-T", "Spec", "-m", "should", "-v" ) )
