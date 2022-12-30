package.path = package.path .. ";../?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test_utils" )

-- Mock libraries
test_utils.mock_wow_api()
test_utils.NewLibrary( "AceConsole-3.0" )
test_utils.NewLibrary( "AceEvent-3.0" )
test_utils.NewLibrary( "AceTimer-3.0" )
test_utils.NewLibrary( "AceComm-3.0" )
test_utils.NewLibrary( "AceGUI-3.0" )

-- Load real stuff
require( "LibStub" )
require( "ModUi/facade" )
require( "ModUi" )
require( "ModUi/utils" )
require( "RollFor" )

---@diagnostic disable-next-line: lowercase-global
function test_should_load_test_utils()
  lu.assertEquals( test_utils.princess(), "kenny" )
end

local function RollFor()
  local ModUi = LibStub:GetLibrary( "ModUi-1.0", 3 )
  return ModUi:GetModule( "RollFor" )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_load_roll_for()
  lu.assertNotNil( RollFor() )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )
os.exit( runner:runSuite() )
