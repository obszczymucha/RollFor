package.path = "./?.lua;" .. package.path .. ";../?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local player = utils.player
local leader = utils.raid_leader
local is_in_party = utils.is_in_party
local is_in_raid = utils.is_in_raid
local c = utils.console_message
local p = utils.party_message
local r = utils.raid_message
local cr = utils.console_and_raid_message
local rw = utils.raid_warning
local rolling_not_in_progress = utils.rolling_not_in_progress
local roll_for = utils.roll_for
local roll_for_raw = utils.roll_for_raw
local cancel_rolling = utils.cancel_rolling
local finish_rolling = utils.finish_rolling
local assert_messages = utils.assert_messages

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

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

utils.mock_libraries()
utils.load_real_stuff()

os.exit( runner:runSuite( "-t", "should", "-v" ) )