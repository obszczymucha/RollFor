package.path = "./?.lua;" .. package.path .. ";../?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local c = utils.console_message
local p = utils.party_message
local r = utils.raid_message
local rw = utils.raid_warning
local leader = utils.raid_leader
local init = utils.init
local mock = utils.mock
local mock_table_fn = utils.mock_table_function
local roll_for = utils.roll_for
local roll_for_raw = utils.roll_for_raw
local roll = utils.roll
local roll_os = utils.roll_os
local get_messages = utils.get_messages
local cancel_rolling = utils.cancel_rolling
local finish_rolling = utils.finish_rolling
local tick_fn
local mock_library = utils.NewLibrary

-- Helper functions.
local function is_in_party( ... )
  local players = { ... }
  mock( "IsInGroup", true )
  mock( "IsInRaid", false )
  mock_table_fn( "GetRaidRosterInfo", players )
end

local function add_normal_raider_ranks( players )
  local result = {}

  for i = 1, #players do
    local value = players[ i ]

    if type( value ) == "string" then
      table.insert( result, utils.raid_member( value ) )
    else
      table.insert( result, value )
    end
  end

  return result
end

local function is_in_raid( ... )
  local players = add_normal_raider_ranks( { ... } )
  mock( "IsInGroup", true )
  mock( "IsInRaid", true )
  mock_table_fn( "GetRaidRosterInfo", players )
end

local function player( name )
  init()
  mock_table_fn( "UnitName", { [ "player" ] = name } )
  mock( "IsInGroup", false )
end

local function rolling_not_in_progress()
  return c( "RollFor: Rolling not in progress." )
end

-- Return console message first then its equivalent raid message.
-- This returns a function, we check for that later to do the magic.
local function cr( message )
  return function() return c( string.format( "RollFor: %s", message ) ), r( message ) end
end

local function assert_messages( ... )
  local args = { ... }
  local expected = {}
  utils.flatten( expected, args )
  lu.assertEquals( get_messages(), expected )
end

local function tick( times )
  if not tick_fn then
    utils.debug( "Tick function not set." )
    return
  end

  local count = times or 1

  for _ = 1, count do
    tick_fn()
  end
end

local function mock_libraries()
  utils.mock_wow_api()
  mock_library( "AceConsole-3.0" )
  mock_library( "AceEvent-3.0", { RegisterMessage = function() end } )
  mock_library( "AceTimer-3.0", {
    ScheduleRepeatingTimer = function( _, f )
      tick_fn = f
      return 1
    end,
    CancelTimer = function() tick_fn = nil end,
    ScheduleTimer = function( _, f ) f() end
  } )
  mock_library( "AceComm-3.0", { RegisterComm = function() end, SendCommMessage = function() end } )
  mock_library( "AceGUI-3.0" )
  mock_library( "AceDB-3.0", { New = function( _, name ) _G[ name ] = {} end } )
end

local function load_real_stuff()
  require( "LibStub" )
  require( "ModUi/facade" )
  utils.mock_facade()
  utils.mock_slashcmdlist()
  require( "ModUi" )
  require( "ModUi/utils" )
  require( "RollFor" )
end

---@diagnostic disable-next-line: lowercase-global
function should_load_roll_for()
  -- Given
  local ModUi = LibStub( "ModUi-1.0" )

  -- When
  local result = ModUi:GetModule( "RollFor" )

  -- Then
  lu.assertNotNil( result )
end

---@diagnostic disable-next-line: lowercase-global
function should_not_roll_if_not_in_group()
  -- Given
  player( "Psikutas" )

  -- When
  roll_for()

  -- Then
  assert_messages(
    c( "RollFor: Not in a group." )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_print_usage_if_in_party_and_no_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for_raw( "" )

  -- Then
  assert_messages(
    c( "RollFor: Usage: /rf <item> [seconds]" )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_print_usage_if_in_raid_and_no_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for_raw( "" )

  -- Then
  assert_messages(
    c( "RollFor: Usage: /rf <item> [seconds]" )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_print_usage_if_in_party_and_invalid_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for_raw( "not an item" )

  -- Then
  assert_messages(
    c( "RollFor: Usage: /rf <item> [seconds]" )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_print_usage_if_in_raid_and_invalid_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for_raw( "not an item" )

  -- Then
  assert_messages(
    c( "RollFor: Usage: /rf <item> [seconds]" )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_roll_the_item_in_party_chat()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )

  -- Then
  assert_messages(
    p( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_not_roll_again_if_rolling_is_in_progress()
  -- Given
  player( "Psikutas" )
  is_in_party( "Psikutas", "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_for( "Hearthstone" )

  -- Then
  assert_messages(
    p( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    c( "RollFor: Rolling already in progress." )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_roll_the_item_in_raid_chat()
  -- Given
  player( "Psikutas" )
  is_in_raid( "Psikutas", "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )

  -- Then
  assert_messages(
    r( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_roll_the_item_in_raid_warning()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_not_cancel_rolling_if_rolling_is_not_in_progress()
  -- Given
  player( "Psikutas" )

  -- When
  cancel_rolling()

  -- Then
  assert_messages( rolling_not_in_progress() )
end

---@diagnostic disable-next-line: lowercase-global
function should_cancel_rolling()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  cancel_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    c( "RollFor: Rolling for [Hearthstone] has been cancelled." )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_not_finish_rolling_if_rolling_is_not_in_progress()
  -- Given
  player( "Psikutas" )

  -- When
  finish_rolling()

  -- Then
  assert_messages( rolling_not_in_progress() )
end

---@diagnostic disable-next-line: lowercase-global
function should_finish_rolling()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    cr( "Nobody rolled for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_finish_rolling_automatically_if_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Psikutas", 69 )
  roll( "Obszczymucha", 42 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_finish_rolling_after_the_timer()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Psikutas", 69 )
  tick( 8 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_ignore_offspec_rolls_if_mainspec_was_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 8 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_process_offspec_rolls_if_there_are_no_mainspec_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll_os( "Psikutas", 69 )
  tick( 8 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Obszczymucha rolled the highest (99) for [Hearthstone] (OS)." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_recognize_mainspec_tie_rolls_when_all_players_tie()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 69 )
  roll( "Psikutas", 69 )
  roll( "Psikutas", 100 )
  roll( "Obszczymucha", 99 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    cr( "The highest roll was 69 by Obszczymucha and Psikutas." ),
    r( "Obszczymucha and Psikutas /roll for [Hearthstone] now." ),
    cr( "Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_recognize_mainspec_tie_rolls_when_some_players_tie()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 69 )
  roll_os( "Ponpon", 100 )
  roll( "Psikutas", 69 )
  tick( 8 )
  roll( "Psikutas", 100 )
  roll( "Obszczymucha", 99 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "The highest roll was 69 by Obszczymucha and Psikutas." ),
    r( "Obszczymucha and Psikutas /roll for [Hearthstone] now." ),
    cr( "Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_override_offspec_roll_with_mainspec()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 6 )
  roll( "Obszczymucha", 42 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3", "2" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_detect_and_ignore_double_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 13 )
  tick( 6 )
  roll( "Obszczymucha", 100 )
  roll( "Psikutas", 69 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3", "2" ),
    c( "RollFor: Obszczymucha exhausted their rolls. This roll (100) is ignored." ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_recognize_multiple_mainspec_rollers_for_multiple_items()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Psikutas", 69 )
  roll( "Obszczymucha", 100 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone]." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_recognize_multiple_offspec_rollers_if_item_count_is_equal_to_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Psikutas", 69 )
  roll_os( "Obszczymucha", 100 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone] (OS)." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone] (OS)." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_recognize_multiple_offspec_rollers_if_item_count_is_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )
  roll_for( "Hearthstone", 2 )
  roll_os( "Psikutas", 69 )
  roll_os( "Obszczymucha", 100 )
  tick( 6 )
  roll_os( "Chuj", 42 )
  tick( 2 )

  -- When

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Obszczymucha rolled the highest (100) for [Hearthstone] (OS)." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone] (OS)." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_recognize_mainspec_roller_and_top_offspec_roller_if_item_count_is_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )
  roll_for( "Hearthstone", 2 )
  roll_os( "Chuj", 42 )
  roll( "Obszczymucha", 1 )
  tick( 6 )
  roll_os( "Psikutas", 69 )
  tick( 2 )

  -- When

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Obszczymucha rolled the highest (1) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone] (OS)." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." )
  )
end

---@diagnostic disable-next-line: lowercase-global
--function should_recognize_mainspec_rollers_if_item_count_is_less_than_group_size()
--  -- Given
--  player( "Psikutas" )
--  is_in_raid( rl( "Psikutas" ),  "Obszczymucha" ,  "Chuj"  )
--  roll_for( "Hearthstone", 2 )
--  roll_os( "Chuj", 42 )
--  roll( "Obszczymucha", 1 )
--  tick( 6 )
--  roll( "Psikutas", 69 )
--  tick( 2 )

--  -- When
--

--  -- Then
--  equals( result,
--    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
--    r( "Stopping rolls in 3", "2", "1" ),
--    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
--    c( "RollFor: Rolling for [Hearthstone] has finished." ),
--    cr( "Obszczymucha rolled the next highest (1) for [Hearthstone]." )
--  )
--end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

mock_libraries()
load_real_stuff()

os.exit( runner:runSuite( "-t", "should", "-v" ) )
