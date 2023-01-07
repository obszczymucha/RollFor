package.path = "./?.lua;" .. package.path .. ";../?.lua;../src/?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test/utils" )
test_utils.mock_wow_api()
test_utils.load_libstub()
local mod = require( "src/SoftRes" )

SoftResSpec = {}

function SoftResSpec.new_instances_should_have_empty_item_lists()
  -- Given
  local sr = mod.new()
  local sr2 = mod.new()

  -- Expect
  lu.assertEquals( sr.get( 123 ), nil )
  lu.assertEquals( sr2.get( 123 ), nil )
end

function SoftResSpec:should_create_a_proper_object_and_add_an_item()
  -- Given
  local sr = mod.new()
  local sr2 = mod.new()
  sr.add( 123, "Psikutas" )

  -- When
  local result = sr.get( 123 )
  local result2 = sr2.get( 123 )

  -- Then
  lu.assertEquals( result, {
    { softres_name = "Psikutas", matched_name = "Psikutas", rolls = 1 }
  } )
  lu.assertEquals( result2, {} )
end

function SoftResSpec:should_return_nil_for_untracked_item()
  -- Given
  local sr = mod.new()
  sr.add( 123, "Psikutas" )

  -- When
  local result = sr.get( "111" )

  -- Then
  lu.assertEquals( result, {} )
end

function SoftResSpec:should_add_multiple_players()
  -- Given
  local sr = mod.new()
  sr.add( 123, "Psikutas" )
  sr.add( 123, "Obszczymucha" )

  -- When
  local result = sr.get( 123 )

  -- Then
  lu.assertEquals( result, {
    { softres_name = "Psikutas", matched_name = "Psikutas", rolls = 1 },
    { softres_name = "Obszczymucha", matched_name = "Obszczymucha", rolls = 1 }
  } )
end

function SoftResSpec:should_accumulate_rolls()
  -- Given
  local sr = mod.new()
  sr.add( 123, "Psikutas" )
  sr.add( 123, "Psikutas" )

  -- When
  local result = sr.get( 123 )

  -- Then
  lu.assertEquals( result, {
    { softres_name = "Psikutas", matched_name = "Psikutas", rolls = 2 }
  } )
end

function SoftResSpec:should_auto_match_player_name()
  -- Given
  local matcher = { match = function() return "Psikutas" end }
  local sr = mod.new( matcher )
  sr.add( 123, "Psiktuas" )

  -- When
  local result = sr.get( 123 )

  -- Then
  lu.assertEquals( result, {
    { softres_name = "Psiktuas", matched_name = "Psikutas", rolls = 1 }
  } )
end

function SoftResSpec:should_check_if_player_is_soft_ressing()
  -- Given
  local matcher = { match = function( name ) return name == "Psiktuas" and "Psikutas" or name end }
  local sr = mod.new( matcher )

  -- When
  sr.add( 123, "Psiktuas" )
  sr.add( 111, "Obszczymucha" )

  -- Then
  lu.assertEquals( sr.is_player_softressing( "Psiktuas", 123 ), false )
  lu.assertEquals( sr.is_player_softressing( "Psikutas", 123 ), true )
  lu.assertEquals( sr.is_player_softressing( "Psikutas", 333 ), false )
  lu.assertEquals( sr.is_player_softressing( "Psikutas", 111 ), false )
  lu.assertEquals( sr.is_player_softressing( "Obszczymucha", 111 ), true )
  lu.assertEquals( sr.is_player_softressing( "Obszczymucha", 123 ), false )
  lu.assertEquals( sr.is_player_softressing( "Obszczymucha", 124 ), false )
  lu.assertEquals( sr.is_player_softressing( "Ponpon", 123 ), false )
  lu.assertEquals( sr.is_player_softressing( "Ponpon", 111 ), false )
  lu.assertEquals( sr.is_player_softressing( "Ponpon", 333 ), false )
end

function SoftResSpec:should_clear_the_data()
  -- Given
  local sr = mod.new()
  sr.add( 123, "Psikutas" )

  -- When
  sr.clear()

  -- Then
  lu.assertEquals( sr.get( 123 ), {} )
  lu.assertEquals( sr.is_player_softressing( "Psikutas", 123 ), false )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

os.exit( runner:runSuite( "-m", "should", "-T", "Spec", "-v" ) )
