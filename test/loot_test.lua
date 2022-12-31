package.path = "./?.lua;" .. package.path .. ";../?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
local player = utils.player
local leader = utils.raid_leader
local is_in_raid = utils.is_in_raid
local r = utils.raid_message
local loot = utils.loot
local master_looter = utils.master_looter
local assert_messages = utils.assert_messages
local item = utils.item
local targetting_enemy = utils.targetting_enemy

---@diagnostic disable-next-line: lowercase-global
function should_not_show_loot_that_dropped_if_not_a_master_looter()
  -- Given
  player( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  loot()

  -- Then
  assert_messages(
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_show_one_item_that_dropped_if_a_master_looter_and_not_targetting_an_enemy()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  loot( { item( "Hearthstone", 123 ) } )

  -- Then
  assert_messages(
    r( "1 item dropped:" ),
    r( "1. [Hearthstone]" )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_show_more_items_that_dropped_if_a_master_looter_and_not_targetting_an_enemy()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  loot( { item( "Hearthstone", 123 ), item( "Some item", 400 ) } )

  -- Then
  assert_messages(
    r( "2 items dropped:" ),
    r( "1. [Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_only_show_loot_once()
  -- Given
  master_looter( "Psikutas" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  loot( { item( "Hearthstone", 123 ), item( "Some item", 400 ) } )
  loot( { item( "Hearthstone", 123 ), item( "Some item", 400 ) } )

  -- Then
  assert_messages(
    r( "2 items dropped:" ),
    r( "1. [Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

---@diagnostic disable-next-line: lowercase-global
function should_show_loot_that_dropped_if_a_master_looter_and_targetting_an_enemy()
  -- Given
  master_looter( "Psikutas" )
  targetting_enemy( "Instructor Razuvious" )
  is_in_raid( leader( "Psikutas" ), "Obszczymucha" )

  -- When
  loot( { item( "Hearthstone", 123 ), item( "Some item", 400 ) } )

  -- Then
  assert_messages(
    r( "2 items dropped by Instructor Razuvious:" ),
    r( "1. [Hearthstone]" ),
    r( "2. [Some item]" )
  )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

utils.mock_libraries()
utils.load_real_stuff()

os.exit( runner:runSuite( "-t", "should", "-v" ) )
