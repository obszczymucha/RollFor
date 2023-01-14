package.path = "./?.lua;" .. package.path .. ";../?.lua;../Libs/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local player = utils.player
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local r = utils.raid_message
local c = utils.console_message
local cr = utils.console_and_raid_message
local rw = utils.raid_warning
local rolling_finished = utils.rolling_finished
local roll_for = utils.roll_for
local roll = utils.roll
local roll_os = utils.roll_os
local assert_messages = utils.assert_messages
local tick = utils.tick

BothSpecRollsSpec = {}

function BothSpecRollsSpec:should_prioritize_mainspec_over_offspec_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 8 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_override_offspec_roll_with_mainspec_and_finish_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 6 )
  roll( "Obszczymucha", 42 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)" ),
    r( "Stopping rolls in 3", "2" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_override_offspec_roll_with_mainspec_and_not_finish_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone" )
  roll_os( "Obszczymucha", 99 )
  roll( "Psikutas", 69 )
  tick( 6 )
  roll( "Obszczymucha", 42 )
  tick( 2 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_mainspec_and_offspec_rollers_and_stop_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll_os( "Psikutas", 63 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2" ),
    cr( "Obszczymucha rolled the highest (3) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (63) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_mainspec_and_top_offspec_rollers_and_stop_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 3 )
  roll_os( "Chuj", 99 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll_os( "Psikutas", 63 )

  -- Then
  assert_messages(
    rw( "Roll for 3x[Hearthstone]: /roll (MS) or /roll 99 (OS). 3 top rolls win." ),
    r( "Stopping rolls in 3", "2" ),
    cr( "Obszczymucha rolled the highest (3) for [Hearthstone]." ),
    cr( "Chuj rolled the next highest (99) for [Hearthstone] (OS)." ),
    cr( "Psikutas rolled the next highest (63) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_top_mainspec_and_offspec_rollers_and_stop_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 3 )
  roll( "Chuj", 99 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll_os( "Psikutas", 63 )

  -- Then
  assert_messages(
    rw( "Roll for 3x[Hearthstone]: /roll (MS) or /roll 99 (OS). 3 top rolls win." ),
    r( "Stopping rolls in 3", "2" ),
    cr( "Chuj rolled the highest (99) for [Hearthstone]." ),
    cr( "Obszczymucha rolled the next highest (3) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (63) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_mainspec_rollers_and_not_stop_automatically_with_items_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Chuj", 99 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll( "Psikutas", 63 )
  tick( 2 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (63) for [Hearthstone]." ),
    cr( "Obszczymucha rolled the next highest (3) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_both_mainspec_rollers_and_not_stop_automatically_with_items_equal_to_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 3 )
  roll( "Obszczymucha", 3 )
  tick( 6 )
  roll( "Psikutas", 63 )
  tick( 2 )

  -- Then
  assert_messages(
    rw( "Roll for 3x[Hearthstone]: /roll (MS) or /roll 99 (OS). 3 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (63) for [Hearthstone]." ),
    cr( "Obszczymucha rolled the next highest (3) for [Hearthstone]." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_mainspec_and_offspec_rollers_and_not_stop_automatically_with_items_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Chuj", 99 )
  roll_os( "Obszczymucha", 98 )
  tick( 6 )
  roll( "Psikutas", 63 )
  tick( 2 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (63) for [Hearthstone]." ),
    cr( "Chuj rolled the next highest (99) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_mainspec_roller_and_top_offspec_roller_if_item_count_is_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Chuj", 42 )
  roll( "Obszczymucha", 1 )
  tick( 6 )
  roll_os( "Psikutas", 69 )
  tick( 2 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Obszczymucha rolled the highest (1) for [Hearthstone]." ),
    cr( "Psikutas rolled the next highest (69) for [Hearthstone] (OS)." ),
    rolling_finished()
  )
end

function BothSpecRollsSpec:should_recognize_mainspec_rollers_if_item_count_is_less_than_group_size()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Chuj" )

  -- When
  roll_for( "Hearthstone", 2 )
  roll_os( "Chuj", 42 )
  roll( "Obszczymucha", 1 )
  tick( 6 )
  roll( "Psikutas", 69 )
  tick( 2 )

  -- Then
  assert_messages(
    rw( "Roll for 2x[Hearthstone]: /roll (MS) or /roll 99 (OS). 2 top rolls win." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    cr( "Obszczymucha rolled the next highest (1) for [Hearthstone]." ),
    rolling_finished()
  )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

utils.mock_libraries()
utils.load_real_stuff()

os.exit( runner:runSuite( "-T", "Spec", "-m", "should", "-v" ) )
