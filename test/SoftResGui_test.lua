package.path = "./?.lua;" .. package.path .. ";../?.lua;../RollFor/?.lua;../RollFor/Libs/?.lua;../RollFor/Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )

local master_looter = utils.master_looter
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local rw = utils.raid_warning
local cr = utils.console_and_raid_message
local c = utils.console_message
local r = utils.raid_message
local rolling_finished = utils.rolling_finished
local roll_for = utils.roll_for
local roll = utils.roll
local assert_messages = utils.assert_messages
local repeating_tick = utils.repeating_tick
local loot = utils.loot
local item = utils.item
local award = utils.award
local loot_threshold = utils.loot_threshold
local LootQuality = utils.LootQuality
local mock_blizzard_loot_buttons = utils.mock_blizzard_loot_buttons
local run_command = utils.run_command
local mock_softres_gui = utils.mock_softres_gui
local import_softres_via_gui = utils.import_softres_via_gui
local targetting_player = utils.targetting_player

SoftResGuiSpec = {}

function SoftResGuiSpec:should_load_softres_data_via_gui()
  -- Given
  master_looter( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Ponpon" )
  mock_softres_gui()
  run_command( "SR", "init" )
  import_softres_via_gui( "fixtures/sr-ohhaimark.zlib.base64" )
  loot_threshold( LootQuality.Epic )
  mock_blizzard_loot_buttons()

  -- When
  loot( item( "King's Defender", 28749 ), item( "Battlescar Boots", 28747 ) )
  roll_for( "King's Defender", 1, 28749 )
  award( "Ohhaimark", "King's Defender", 28749 )
  roll_for( "Battlescar Boots", 1, 28747 )
  roll( "Ponpon", 1 )
  repeating_tick( 8 )

  -- Then
  assert_messages(
    c( "RollFor: Soft-res data loaded successfully!" ),
    c( "RollFor: Players who did not soft-res:" ),
    c( "RollFor: Ponpon" ),
    r( "2 items dropped:", "1. [King's Defender] (SR by Ohhaimark)", "2. [Battlescar Boots]" ),
    rw( "Ohhaimark soft-ressed [King's Defender]." ),
    c( "RollFor: Ohhaimark received [King's Defender]." ),
    rw( "Roll for [Battlescar Boots]: /roll (MS) or /roll 99 (OS)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Ponpon rolled the highest (1) for [Battlescar Boots]." ),
    rolling_finished()
  )
end

function SoftResGuiSpec:should_load_softres_data_via_gui_and_manually_match_a_player()
  -- Given
  master_looter( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Ponpon" )
  mock_softres_gui()
  run_command( "SR", "init" )
  import_softres_via_gui( "fixtures/sr-ohhaimark-obszczymucha.zlib.base64" )
  run_command( "SRO" )
  targetting_player( "Ponpon" )
  run_command( "SRO", "1" )
  loot_threshold( LootQuality.Epic )
  mock_blizzard_loot_buttons()

  -- When
  loot( item( "King's Defender", 28749 ), item( "Battlescar Boots", 28747 ) )
  roll_for( "King's Defender", 1, 28749 )
  award( "Ohhaimark", "King's Defender", 28749 )
  roll_for( "Battlescar Boots", 1, 28747 )
  award( "Ponpon", "Battlescar Boots", 28747 )

  -- Then
  assert_messages(
    c( "RollFor: Soft-res data loaded successfully!" ),
    c( "RollFor: Players who did not soft-res:" ),
    c( "RollFor: Ponpon" ),
    c( "RollFor: To match, target a player and type: /sro <number>" ),
    c( "RollFor: [1]: Obszczymucha" ),
    c( "RollFor: Ponpon is now soft-ressing as Obszczymucha." ),
    r( "2 items dropped:", "1. [King's Defender] (SR by Ohhaimark)", "2. [Battlescar Boots] (SR by Ponpon)" ),
    rw( "Ohhaimark soft-ressed [King's Defender]." ),
    c( "RollFor: Ohhaimark received [King's Defender]." ),
    rw( "Ponpon soft-ressed [Battlescar Boots]." ),
    c( "RollFor: Ponpon received [Battlescar Boots]." )
  )
end

-- There was a nasty bug with name matching that broke everything.
function SoftResGuiSpec:should_load_softres_data_via_gui_after_clearing_manual_matches()
  -- Given
  master_looter( "Ohhaimark" )
  is_in_raid( leader( "Ohhaimark" ), "Ponpon" )
  mock_softres_gui()
  run_command( "SR", "init" )
  import_softres_via_gui( "fixtures/sr-ohhaimark-obszczymucha.zlib.base64" )
  run_command( "SRO" )
  targetting_player( "Ponpon" )
  run_command( "SRO", "1" )
  run_command( "SR", "init" )
  import_softres_via_gui( "fixtures/sr-ohhaimark-obszczymucha.zlib.base64" )
  loot_threshold( LootQuality.Epic )
  mock_blizzard_loot_buttons()

  -- When
  loot( item( "King's Defender", 28749 ), item( "Battlescar Boots", 28747 ) )
  roll_for( "King's Defender", 1, 28749 )
  award( "Ohhaimark", "King's Defender", 28749 )
  roll_for( "Battlescar Boots", 1, 28747 )
  roll( "Ponpon", 1 )
  repeating_tick( 8 )

  -- Then
  assert_messages(
    c( "RollFor: Soft-res data loaded successfully!" ),
    c( "RollFor: Players who did not soft-res:" ),
    c( "RollFor: Ponpon" ),
    c( "RollFor: To match, target a player and type: /sro <number>" ),
    c( "RollFor: [1]: Obszczymucha" ),
    c( "RollFor: Ponpon is now soft-ressing as Obszczymucha." ),
    c( "RollFor: Cleared manual matches." ),
    c( "RollFor: Cleared soft-res data." ),
    c( "RollFor: Soft-res data loaded successfully!" ),
    c( "RollFor: Players who did not soft-res:" ),
    c( "RollFor: Ponpon" ),
    r( "2 items dropped:", "1. [King's Defender] (SR by Ohhaimark)", "2. [Battlescar Boots]" ),
    rw( "Ohhaimark soft-ressed [King's Defender]." ),
    c( "RollFor: Ohhaimark received [King's Defender]." ),
    rw( "Roll for [Battlescar Boots]: /roll (MS) or /roll 99 (OS)" ),
    r( "Stopping rolls in 3", "2", "1" ),
    cr( "Ponpon rolled the highest (1) for [Battlescar Boots]." ),
    rolling_finished()
  )
end

utils.mock_libraries()
utils.load_real_stuff()

os.exit( lu.LuaUnit.run() )
