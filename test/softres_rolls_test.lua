package.path = "./?.lua;" .. package.path .. ";../?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local player = utils.player
local master_looter = utils.master_looter
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local rw = utils.raid_warning
local crw = utils.console_and_raid_warning
local cr = utils.console_and_raid_message
local c = utils.console_message
local r = utils.raid_message
local rolling_not_in_progress = utils.rolling_not_in_progress
local rolling_finished = utils.rolling_finished
local roll_for = utils.roll_for
local finish_rolling = utils.finish_rolling
local roll = utils.roll
local roll_os = utils.roll_os
local assert_messages = utils.assert_messages
local soft_res = utils.soft_res
local sr = utils.soft_res_item
local tick = utils.tick
local loot = utils.loot
local item = utils.item
local award = utils.award

---@diagnostic disable-next-line: lowercase-global
function should_announce_sr_and_ignore_all_rolls_if_item_is_soft_ressed_by_one_player()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Rikus" )
  soft_res( sr( "Psikutas", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Rikus", 99 )
  roll_os( "Obszczymucha", 100 )
  roll( "Psikutas", 69 )
  finish_rolling()

  -- Then
  assert_messages(
    crw( "[Hearthstone] is soft-ressed by Psikutas." ),
    rolling_not_in_progress()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_only_process_rolls_from_players_who_soft_ressed_and_finish_automatically()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Rikus" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Rikus", 100 )
  roll( "Psikutas", 69 )
  roll_os( "Obszczymucha", 42 )
  roll( "Ponpon", 42 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: (SR by Psikutas and Ponpon)." ),
    c( "RollFor: Rikus did not SR [Hearthstone]. This roll (100) is ignored." ),
    c( "RollFor: Obszczymucha did not SR [Hearthstone]. This roll (42) is ignored." ),
    cr( "Psikutas rolled the highest (69) for [Hearthstone]." ),
    rolling_finished()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_ignore_offspec_rolls_by_players_who_soft_ressed_and_announce_they_still_have_to_roll()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll_os( "Psikutas", 69 )
  roll( "Ponpon", 42 )
  tick( 8 )
  roll( "Psikutas", 99 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: (SR by Psikutas and Ponpon)." ),
    c( "RollFor: Psikutas did SR [Hearthstone], but rolled OS. This roll (69) is ignored." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Ponpon rolled the highest (42) for [Hearthstone]." ),
    r( "SR rolls remaining: Psikutas (1 roll)" ),
    cr( "Psikutas rolled the highest (99) for [Hearthstone]." ),
    rolling_finished()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_announce_current_highest_roller_if_a_player_who_soft_ressed_did_not_roll_and_rolls_were_manually_finished()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll_os( "Psikutas", 69 )
  roll( "Ponpon", 42 )
  tick( 8 )
  finish_rolling()

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: (SR by Psikutas and Ponpon)." ),
    c( "RollFor: Psikutas did SR [Hearthstone], but rolled OS. This roll (69) is ignored." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Ponpon rolled the highest (42) for [Hearthstone]." ),
    r( "SR rolls remaining: Psikutas (1 roll)" ),
    cr( "Ponpon rolled the highest (42) for [Hearthstone]." ),
    rolling_finished()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_announce_all_missing_sr_rolls_if_players_didnt_roll_on_time()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha", "Ponpon", "Rikus" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Rikus", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Ponpon", 42 )
  tick( 8 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: (SR by Psikutas [2 rolls], Ponpon [2 rolls] and Rikus)." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Ponpon rolled the highest (42) for [Hearthstone]." ),
    r( "SR rolls remaining: Psikutas (2 rolls), Ponpon (1 roll) and Rikus (1 roll)" )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_allow_multiple_rolls_if_a_player_soft_ressed_multiple_times()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Ponpon" )
  soft_res( sr( "Psikutas", 123 ), sr( "Psikutas", 123 ), sr( "Ponpon", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Psikutas", 42 )
  roll( "Ponpon", 69 )
  roll( "Ponpon", 100 )
  roll( "Psikutas", 99 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: (SR by Psikutas [2 rolls] and Ponpon)." ),
    c( "RollFor: Ponpon exhausted their rolls. This roll (100) is ignored." ),
    cr( "Psikutas rolled the highest (99) for [Hearthstone]." ),
    rolling_finished()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_ask_for_a_reroll_if_there_is_a_tie_and_ignore_non_tied_rolls()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Ponpon", "Rikus", "Pimp" )
  soft_res( sr( "Psikutas", 123 ), sr( "Ponpon", 123 ), sr( "Rikus", 123 ), sr( "Pimp", 123 ) )

  -- When
  roll_for( "Hearthstone", 1, 123 )
  roll( "Psikutas", 69 )
  roll( "Rikus", 42 )
  roll( "Ponpon", 69 )
  roll( "Pimp", 69 )
  roll( "Rikus", 100 )
  roll( "Psikutas", 100 )
  roll( "Ponpon", 1 )
  roll( "Pimp", 1 )

  -- Then
  assert_messages(
    rw( "Roll for [Hearthstone]: (SR by Psikutas, Ponpon, Rikus and Pimp)." ),
    cr( "The highest roll was 69 by Pimp, Ponpon and Psikutas." ),
    r( "Pimp, Ponpon and Psikutas /roll for [Hearthstone] now." ),
    c( "RollFor: Rikus exhausted their rolls. This roll (100) is ignored." ),
    cr( "Psikutas re-rolled the highest (100) for [Hearthstone]." ),
    rolling_finished()
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_allow_others_to_roll_if_player_who_soft_ressed_already_received_the_item()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Ponpon" )
  soft_res( sr( "Psikutas", 123 ) )

  -- When
  loot( item( "Hearthstone", 123 ), item( "Hearthstone", 123 ) )
  roll_for( "Hearthstone", 1, 123 )
  award( "Psikutas", "Hearthstone", 123 )
  roll_for( "Hearthstone", 1, 123 )
  roll( "Ponpon", 1 )
  tick( 8 )

  -- Then
  assert_messages(
    r( "2 items dropped:", "1. [Hearthstone] (SR by Psikutas)", "2. [Hearthstone] (SR by Psikutas)" ),
    crw( "[Hearthstone] is soft-ressed by Psikutas." ),
    rw( "Roll for [Hearthstone]: /roll (MS) or /roll 99 (OS)." ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Ponpon rolled the highest (1) for [Hearthstone]." ),
    rolling_finished()
  )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

utils.mock_libraries()
utils.load_real_stuff()

os.exit( runner:runSuite( "-t", "should", "-v" ) )