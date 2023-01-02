package.path = "./?.lua;" .. package.path .. ";../?.lua;../src/?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local test_utils = require( "test/utils" )
test_utils.mock_wow_api()
require( "LibStub" )
require( "ModUi/facade" )
require( "src/ItemUtils" )
local mod = require( "src/DroppedLootAnnounce" )

local item = function( name, id ) return mod.item( id, name, string.format( "[%s]", name ), 4 ) end

local hr = function( ... )
  local result = {}

  for _, v in pairs( { ... } ) do
    result[ v ] = 1
  end

  return result
end

local p = function( name )
  return { name = name, rolls = 1 }
end

DroppedLootAnnounceSpec = {}

function DroppedLootAnnounceSpec:should_create_item_details()
  -- When
  local result = mod.item( 123, "Hearthstone", "fake link", 4 )

  -- Expect
  lu.assertEquals( result.id, 123 )
  lu.assertEquals( result.name, "Hearthstone" )
  lu.assertEquals( result.link, "fake link" )
  lu.assertEquals( result.quality, 4 )
end

ItemSummarySpec = {}

function ItemSummarySpec:should_create_the_summary()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { [ 123 ] = { p( "Psikutas" ), p( "Obszczymucha" ) } }

  -- When
  local result = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- Then
  lu.assertEquals( #items, 4 )
  lu.assertEquals( #result, 3 )
  lu.assertEquals( result[ 1 ], {
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = 4 },
    how_many_dropped = 2,
    softressers = { { name = "Obszczymucha", rolls = 1 }, { name = "Psikutas", rolls = 1 } },
    is_hardressed = false
  } )

  lu.assertEquals( result[ 2 ], {
    item = { id = 111, link = "[Big mace]", name = "Big mace", quality = 4 },
    how_many_dropped = 1,
    softressers = {},
    is_hardressed = true
  } )

  lu.assertEquals( result[ 3 ], {
    item = { id = 112, link = "[Small mace]", name = "Small mace", quality = 4 },
    how_many_dropped = 1,
    softressers = {},
    is_hardressed = false
  } )
end

function ItemSummarySpec:should_split_softresses_from_non_softresses_for_each_item()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, hs, hs }
  local softresses = { [ 123 ] = { p( "Psikutas" ), p( "Obszczymucha" ) } }

  -- When
  local result = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- Then
  lu.assertEquals( #items, 4 )
  lu.assertEquals( #result, 2 )
  lu.assertEquals( result[ 1 ], {
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = 4 },
    how_many_dropped = 2,
    softressers = { { name = "Obszczymucha", rolls = 1 }, { name = "Psikutas", rolls = 1 } },
    is_hardressed = false
  } )

  lu.assertEquals( result[ 2 ], {
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = 4 },
    how_many_dropped = 2,
    softressers = {},
    is_hardressed = false
  } )
end

ItemAnnouncementSpec = {}

function ItemAnnouncementSpec:should_create_announcements_if_there_is_one_sr_hr_and_normal()
  -- Given
  local items = { item( "Hearthstone", 123 ), item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { [ 123 ] = { p( "Psikutas" ) } }
  local summary = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Psikutas)",
    "2. [Big mace] (HR)",
    "3. [Small mace]"
  } )
end

function ItemAnnouncementSpec:should_create_announcements_if_there_is_one_sr_and_more_items_dropped()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs }
  local softresses = { [ 123 ] = { p( "Psikutas" ) } }
  local summary = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Psikutas)",
    "2. [Hearthstone]"
  } )
end

function ItemAnnouncementSpec:should_create_announcements_if_the_number_if_items_is_equal_to_softressers()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { [ 123 ] = { p( "Psikutas" ), p( "Obszczymucha" ) } }
  local summary = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Obszczymucha)",
    "2. [Hearthstone] (SR by Psikutas)",
    "3. [Big mace] (HR)",
    "4. [Small mace]"
  } )
end

function ItemAnnouncementSpec:should_create_announcements_if_the_number_if_items_is_greater_than_softressers_by_one()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, hs, item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { [ 123 ] = { p( "Psikutas" ), p( "Obszczymucha" ) } }
  local summary = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Obszczymucha)",
    "2. [Hearthstone] (SR by Psikutas)",
    "3. [Hearthstone]",
    "4. [Big mace] (HR)",
    "5. [Small mace]"
  } )
end

function ItemAnnouncementSpec:should_create_announcements_if_the_number_if_items_is_greater_than_softressers_by_more()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, hs, hs, item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { [ 123 ] = { p( "Psikutas" ), p( "Obszczymucha" ) } }
  local summary = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Obszczymucha)",
    "2. [Hearthstone] (SR by Psikutas)",
    "3. 2x[Hearthstone]",
    "4. [Big mace] (HR)",
    "5. [Small mace]"
  } )
end

function ItemAnnouncementSpec:should_group_items_that_are_not_soft_ressed()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local sm = item( "Small mace", 112 )
  local items = { hs, hs, hs, hs, item( "Big mace", 111 ), sm, sm }
  local softresses = { [ 123 ] = { p( "Psikutas" ), p( "Obszczymucha" ) } }
  local summary = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Obszczymucha)",
    "2. [Hearthstone] (SR by Psikutas)",
    "3. 2x[Hearthstone]",
    "4. [Big mace] (HR)",
    "5. 2x[Small mace]"
  } )
end

function ItemAnnouncementSpec:should_group_soft_ressers_if_only_one_sr_item_dropped()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local sm = item( "Small mace", 112 )
  local items = { hs, item( "Big mace", 111 ), sm, sm }
  local softresses = { [ 123 ] = { p( "Psikutas" ), p( "Obszczymucha" ) } }
  local summary = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Obszczymucha and Psikutas)",
    "2. [Big mace] (HR)",
    "3. 2x[Small mace]"
  } )
end

function ItemAnnouncementSpec:should_group_soft_ressers_if_only_one_sr_item_dropped_and_there_is_more_than_two_softressers()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local sm = item( "Small mace", 112 )
  local items = { hs, item( "Big mace", 111 ), sm, sm }
  local softresses = { [ 123 ] = { p( "Psikutas" ), p( "Obszczymucha" ), p( "Ponpon" ) } }
  local summary = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. [Hearthstone] (SR by Obszczymucha, Ponpon and Psikutas)",
    "2. [Big mace] (HR)",
    "3. 2x[Small mace]"
  } )
end

function ItemAnnouncementSpec:should_group_soft_ressers_if_two_sr_items_dropped_and_there_is_more_than_two_softressers()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local sm = item( "Small mace", 112 )
  local items = { hs, hs, item( "Big mace", 111 ), sm, sm }
  local softresses = { [ 123 ] = { p( "Psikutas" ), p( "Obszczymucha" ), p( "Ponpon" ) } }
  local summary = mod.create_item_summary( items, softresses, hr( 111 ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. 2x[Hearthstone] (SR by Obszczymucha, Ponpon and Psikutas)",
    "2. [Big mace] (HR)",
    "3. 2x[Small mace]"
  } )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

os.exit( runner:runSuite( "-T", "Spec", "-m", "should", "-v" ) )
