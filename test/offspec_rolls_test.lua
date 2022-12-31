package.path = "./?.lua;" .. package.path .. ";../?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local player = utils.player
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local c = utils.console_message
local r = utils.raid_message
local cr = utils.console_and_raid_message
local rw = utils.raid_warning
local rolling_not_in_progress = utils.rolling_not_in_progress
local roll_for = utils.roll_for
local finish_rolling = utils.finish_rolling
local roll_os = utils.roll_os
local assert_messages = utils.assert_messages
local tick = utils.tick

---@diagnostic disable-next-line: lowercase-global
function should_not_finish_rolling_automatically_if_all_players_rolled()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Psikutas", 69 )
  roll_os( "Obszczymucha", 42 )
  tick(8)

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone] (OS)." ),
    c( "RollFor: Rolling for [Hearthstone] has finished." )
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

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

utils.mock_libraries()
utils.load_real_stuff()

os.exit( runner:runSuite( "-t", "should", "-v" ) )
