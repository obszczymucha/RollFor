package.path = package.path .. ";../?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test_utils" )
local item_link = test_utils.item_link
local c = test_utils.console_message
local p = test_utils.party_message
local r = test_utils.raid_message
local rw = test_utils.raid_warning
local rl = test_utils.raid_leader
local rm = test_utils.raid_member
local init = test_utils.init
local mock = test_utils.mock
local mock_table_fn = test_utils.mock_table_function
local roll_for = test_utils.roll_for
local roll_for_raw = test_utils.roll_for_raw
local roll = test_utils.roll
local roll_os = test_utils.roll_os
local get_messages = test_utils.get_messages
local cancel_rolling = test_utils.cancel_rolling
local finish_rolling = test_utils.finish_rolling
local tick_fn
local mock_library = test_utils.NewLibrary

-- Helper functions.
local function is_not_in_group()
  mock( "IsInGroup", false )
end

local function is_in_party( players )
  mock( "IsInGroup", true )
  mock( "IsInRaid", false )
  mock_table_fn( "GetRaidRosterInfo", players )
end

local function is_in_raid( players )
  mock( "IsInGroup", true )
  mock( "IsInRaid", true )
  mock_table_fn( "GetRaidRosterInfo", players )
end

local function player( name )
  init()
  mock_table_fn( "UnitName", { [ "player" ] = name } )
end

local function rolling_not_in_progress()
  return c( "RollFor: Rolling not in progress." )
end

local function tick( times )
  if not tick_fn then
    test_utils.debug( "Tick function not set." )
    return
  end

  local count = times or 1

  for _ = 1, count do
    tick_fn()
  end
end

-- Mock libraries
test_utils.mock_wow_api()
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

-- Load real stuff
require( "LibStub" )
require( "ModUi/facade" )
test_utils.mock_facade()
test_utils.mock_slashcmdlist()
require( "ModUi" )
require( "ModUi/utils" )
require( "RollFor" )

---@diagnostic disable-next-line: lowercase-global
function test_should_load_test_utils()
  lu.assertEquals( test_utils.princess(), "kenny" )
end

local function RollFor()
  local ModUi = LibStub( "ModUi-1.0" )
  return ModUi:GetModule( "RollFor" )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_load_roll_for()
  lu.assertNotNil( RollFor() )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_replace_colors()
  -- Given
  local input = "|cff209ff9RollFor|r: Loaded (|cffff9f69v1.12|r)."

  -- When
  local result = test_utils.replace_colors( input )

  -- Then
  lu.assertEquals( result, "RollFor: Loaded (v1.12)." )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_parse_item_link()
  -- Given
  local input = item_link( "Hearthstone" )

  -- When
  local result = test_utils.parse_item_link( input )

  -- Then
  lu.assertEquals( result, "[Hearthstone]" )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_not_roll_if_not_in_group()
  -- Given
  player( "Psikutas" )
  is_not_in_group()
  roll_for()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { c( "RollFor: Not in a group." ) } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_print_usage_if_in_party_and_no_item_provided()
  -- Given
  player( "Psikutas" )
  is_in_party( { "Psikutas", "Obszczymucha" } )
  roll_for_raw( "" )

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { c( "RollFor: Usage: /rf <item> [seconds]" ) } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_print_usage_if_in_raid_and_no_item_provided()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for_raw( "" )

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { c( "RollFor: Usage: /rf <item> [seconds]" ) } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_print_usage_if_in_party_and_invalid_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_party( { "Psikutas", "Obszczymucha" } )
  roll_for_raw( "not an item" )

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { c( "RollFor: Usage: /rf <item> [seconds]" ) } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_print_usage_if_in_raid_and_invalid_item_is_provided()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for_raw( "not an item" )

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { c( "RollFor: Usage: /rf <item> [seconds]" ) } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_roll_the_item_in_party_chat()
  -- Given
  player( "Psikutas" )
  is_in_party( { "Psikutas", "Obszczymucha" } )
  roll_for( "Hearthstone" )

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { p( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ) } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_not_roll_again_if_rolling_is_in_progress()
  -- Given
  player( "Psikutas" )
  is_in_party( { "Psikutas", "Obszczymucha" } )
  roll_for( "Hearthstone" )
  roll_for( "Hearthstone" )

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    p( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    c( "RollFor: Rolling already in progress." )
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_roll_the_item_in_raid_chat()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rm( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { r( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ) } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_roll_the_item_in_raid_warning()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ) } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_not_cancel_rolling_if_rolling_is_not_in_progress()
  -- Given
  player( "Psikutas" )
  cancel_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { rolling_not_in_progress() } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_cancel_rolling()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )
  cancel_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    c( "RollFor: Rolling for [Hearthstone] has finished (1 item left)." ),
    r( "Rolling for [Hearthstone] cancelled." ),
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_not_finish_rolling_if_rolling_is_not_in_progress()
  -- Given
  player( "Psikutas" )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, { rolling_not_in_progress() } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_finish_rolling()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    c( "RollFor: Rolling for [Hearthstone] has finished (1 item left)." ),
    c( "RollFor: Nobody rolled for [Hearthstone]." ),
    r( "Nobody rolled for [Hearthstone]." ),
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_finish_rolling_automatically_if_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )
  roll( "Psikutas", 69 )
  roll( "Obszczymucha", 42 )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    c( "RollFor: Psikutas rolled the highest (69) for [Hearthstone]." ),
    r( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_not_in_progress(),
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_finish_rolling_after_the_timer()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )
  roll( "Psikutas", 69 )
  tick( 8 )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3" ),
    r( "2" ),
    r( "1" ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    c( "RollFor: Psikutas rolled the highest (69) for [Hearthstone]." ),
    r( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_not_in_progress(),
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_ignore_offspec_rolls_if_mainspec_was_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 8 )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3" ),
    r( "2" ),
    r( "1" ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    c( "RollFor: Psikutas rolled the highest (69) for [Hearthstone]." ),
    r( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_not_in_progress(),
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_process_offspec_rolls_if_there_are_no_mainspec_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll_os( "Psikutas", 69 )
  tick( 8 )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3" ),
    r( "2" ),
    r( "1" ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    c( "RollFor: Obszczymucha rolled the highest (99) for [Hearthstone] (OS)." ),
    r( "Obszczymucha rolled the highest (99) for [Hearthstone] (OS)." ),
    rolling_not_in_progress(),
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_recognize_mainspec_tie_rolls_when_all_players_tie()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 69 )
  roll( "Psikutas", 69 )
  roll( "Psikutas", 100 )
  roll( "Obszczymucha", 99 )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    c( "RollFor: The highest roll was 69 by Obszczymucha and Psikutas." ),
    r( "The highest roll was 69 by Obszczymucha and Psikutas." ),
    r( "Obszczymucha and Psikutas /roll for [Hearthstone] now." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    c( "RollFor: Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    r( "Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    rolling_not_in_progress(),
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_recognize_mainspec_tie_rolls_when_some_players_tie()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ), rm( "Ponpon" ) } )
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 69 )
  roll_os( "Ponpon", 100 )
  roll( "Psikutas", 69 )
  tick( 8 )
  roll( "Psikutas", 100 )
  roll( "Obszczymucha", 99 )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3" ),
    r( "2" ),
    r( "1" ),
    c( "RollFor: The highest roll was 69 by Obszczymucha and Psikutas." ),
    r( "The highest roll was 69 by Obszczymucha and Psikutas." ),
    r( "Obszczymucha and Psikutas /roll for [Hearthstone] now." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    c( "RollFor: Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    r( "Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    rolling_not_in_progress(),
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_override_offspec_roll_with_mainspec()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 6 )
  roll( "Obszczymucha", 42 )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3" ),
    r( "2" ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    c( "RollFor: Psikutas rolled the highest (69) for [Hearthstone]." ),
    r( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_not_in_progress(),
  } )
end

---@diagnostic disable-next-line: lowercase-global
function test_should_detect_and_ignore_double_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( { rl( "Psikutas" ), rm( "Obszczymucha" ) } )
  roll_for( "Hearthstone" )
  roll( "Obszczymucha", 13 )
  tick(6)
  roll( "Obszczymucha", 100 )
  roll( "Psikutas", 69 )
  finish_rolling()

  -- When
  local result = get_messages()

  -- Then
  lu.assertEquals( result, {
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3" ),
    r( "2" ),
    c( "RollFor: Obszczymucha exhausted their rolls. This roll (100) is ignored." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." ),
    c( "RollFor: Psikutas rolled the highest (69) for [Hearthstone]." ),
    r( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_not_in_progress(),
  } )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )
os.exit( runner:runSuite() )
