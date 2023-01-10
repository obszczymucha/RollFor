package.path = "./?.lua;" .. package.path .. ";../?.lua;../src/?.lua;../Libs/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )
utils.mock_wow_api()
utils.load_libstub()
local modules = require( "src/modules" )
require( "src/ItemUtils" )
require( "settings" )
require( "src/SoftRes" )
local mod = require( "src/DroppedLootAnnounce" )

local item = function( name, id, quality ) return mod.item( id, name, string.format( "[%s]", name ), quality or 4 ) end

local hr = function( ... )
  local result = {}

  for _, v in pairs( { ... } ) do
    table.insert( result, { id = v } )
  end

  return result
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

local function softres( softresses, hardresses )
  local result = modules.SoftRes.new()
  result.import( { softreserves = softresses, hardreserves = hardresses } )

  return result
end

local function sr( player_name, ... )
  local item_ids = { ... }
  local items = {}

  for _, v in pairs( item_ids ) do
    table.insert( items, { id = v } )
  end

  return { name = player_name, items = items }
end

ItemSummarySpec = {}

function ItemSummarySpec:should_create_the_summary()
  -- Given
  local hs = item( "Hearthstone", 123 )
  local items = { hs, hs, item( "Big mace", 111 ), item( "Small mace", 112 ) }
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }

  -- When
  local result = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- Then
  lu.assertEquals( #items, 4 )
  lu.assertEquals( #result, 3 )
  lu.assertEquals( result[ 1 ], {
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = 4 },
    how_many_dropped = 2,
    softressers = {
      { name = "Obszczymucha", rolls = 1 },
      { name = "Psikutas", rolls = 1 }
    },
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
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }

  -- When
  local result = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- Then
  lu.assertEquals( #items, 4 )
  lu.assertEquals( #result, 2 )
  lu.assertEquals( result[ 1 ], {
    item = { id = 123, link = "[Hearthstone]", name = "Hearthstone", quality = 4 },
    how_many_dropped = 2,
    softressers = {
      { name = "Obszczymucha", rolls = 1 },
      { name = "Psikutas", rolls = 1 }
    },
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
  local softresses = { sr( "Psikutas", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

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
  local softresses = { sr( "Psikutas", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

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
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

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
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

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
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

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
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

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
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

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
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Ponpon", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

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
  local softresses = { sr( "Psikutas", 123 ), sr( "Obszczymucha", 123 ), sr( "Ponpon", 123 ) }
  local summary = mod.create_item_summary( items, softres( softresses, hr( 111 ) ) )

  -- When
  local result = mod.create_item_announcements( summary )

  -- Then
  lu.assertEquals( result, {
    "1. 2x[Hearthstone] (SR by Obszczymucha, Ponpon and Psikutas)",
    "2. [Big mace] (HR)",
    "3. 2x[Small mace]"
  } )
end

ProcessDroppedItemsIntegrationSpec = {}

local function map( t, f )
  local result = {}

  for i = 1, #t do
    local value = f( t[ i ] ) -- If this isn't a variable, then table.insert breaks. Hmm...
    table.insert( result, value )
  end

  return result
end

local function make_link( _item )
  return utils.item_link( _item.name, _item.id )
end

local function make_quality( _item )
  return function() return _, _, _, _, _item.quality end
end

local function process_dropped_items( loot_quality_threshold )
  utils.loot_quality_threshold( loot_quality_threshold or 4 )
  return mod.process_dropped_items( modules.SoftRes.new() )
end

function ProcessDroppedItemsIntegrationSpec:should_return_source_guid()
  -- Given
  local items = { item( "Legendary item", 123, 5 ), item( "Epic item", 124, 4 ) }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "GetLootSourceInfo", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )

  -- When
  local result, _, _ = process_dropped_items()

  -- Then
  lu.assertEquals( result, "PrincessKenny_123" )
end

function ProcessDroppedItemsIntegrationSpec:should_return_dropped_items()
  -- Given
  local items = { item( "Legendary item", 123, 5 ), item( "Epic item", 124, 4 ) }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "GetLootSourceInfo", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )

  -- When
  local _, result, _ = process_dropped_items()

  -- Then
  lu.assertEquals( result, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = 5 },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r", name = "Epic item", quality = 4 }
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_filter_items_below_epic_quality_threshold()
  -- Given
  local items = {
    item( "Legendary item", 123, 5 ),
    item( "Epic item", 124, 4 ),
    item( "Rare item", 125, 3 ),
    item( "Uncommon item", 126, 2 ),
    item( "Common item", 127, 1 ),
    item( "Poor item", 128, 0 )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "GetLootSourceInfo", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )

  -- When
  local _, items_dropped, announcements = process_dropped_items()
  local result = map( announcements, utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = 5 },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r", name = "Epic item", quality = 4 }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]"
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_filter_items_below_rare_quality_threshold()
  -- Given
  local items = {
    item( "Legendary item", 123, 5 ),
    item( "Epic item", 124, 4 ),
    item( "Rare item", 125, 3 ),
    item( "Uncommon item", 126, 2 ),
    item( "Common item", 127, 1 ),
    item( "Poor item", 128, 0 )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "GetLootSourceInfo", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )

  -- When
  local _, items_dropped, announcements = process_dropped_items( 3 )
  local result = map( announcements, utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = 5 },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r", name = "Epic item", quality = 4 },
    { id = 125, link = "|cff9d9d9d|Hitem:125::::::::20:257::::::|h[Rare item]|h|r", name = "Rare item", quality = 3 }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]",
    "3. [Rare item]"
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_filter_items_below_uncommon_quality_threshold()
  -- Given
  local items = {
    item( "Legendary item", 123, 5 ),
    item( "Epic item", 124, 4 ),
    item( "Rare item", 125, 3 ),
    item( "Uncommon item", 126, 2 ),
    item( "Common item", 127, 1 ),
    item( "Poor item", 128, 0 )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "GetLootSourceInfo", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )

  -- When
  local _, items_dropped, announcements = process_dropped_items( 2 )
  local result = map( announcements, utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = 5 },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r", name = "Epic item", quality = 4 },
    { id = 125, link = "|cff9d9d9d|Hitem:125::::::::20:257::::::|h[Rare item]|h|r", name = "Rare item", quality = 3 },
    { id = 126, link = "|cff9d9d9d|Hitem:126::::::::20:257::::::|h[Uncommon item]|h|r", name = "Uncommon item", quality = 2 }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]",
    "3. [Rare item]",
    "4. [Uncommon item]"
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_filter_items_below_common_quality_threshold()
  -- Given
  local items = {
    item( "Legendary item", 123, 5 ),
    item( "Epic item", 124, 4 ),
    item( "Rare item", 125, 3 ),
    item( "Uncommon item", 126, 2 ),
    item( "Common item", 127, 1 ),
    item( "Poor item", 128, 0 )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "GetLootSourceInfo", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )

  -- When
  local _, items_dropped, announcements = process_dropped_items( 1 )
  local result = map( announcements, utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = 5 },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r", name = "Epic item", quality = 4 },
    { id = 125, link = "|cff9d9d9d|Hitem:125::::::::20:257::::::|h[Rare item]|h|r", name = "Rare item", quality = 3 },
    { id = 126, link = "|cff9d9d9d|Hitem:126::::::::20:257::::::|h[Uncommon item]|h|r", name = "Uncommon item", quality = 2 },
    { id = 127, link = "|cff9d9d9d|Hitem:127::::::::20:257::::::|h[Common item]|h|r", name = "Common item", quality = 1 }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]",
    "3. [Rare item]",
    "4. [Uncommon item]",
    "5. [Common item]"
  } )
end

function ProcessDroppedItemsIntegrationSpec:should_filter_items_below_poor_quality_threshold()
  -- Given
  local items = {
    item( "Legendary item", 123, 5 ),
    item( "Epic item", 124, 4 ),
    item( "Rare item", 125, 3 ),
    item( "Uncommon item", 126, 2 ),
    item( "Common item", 127, 1 ),
    item( "Poor item", 128, 0 )
  }
  utils.mock( "GetNumLootItems", #items )
  utils.mock( "GetLootSourceInfo", "PrincessKenny_123" )
  utils.mock_table_function( "GetLootSlotLink", map( items, make_link ) )
  utils.mock_table_function( "GetLootSlotInfo", map( items, make_quality ) )

  -- When
  local _, items_dropped, announcements = process_dropped_items( 0 )
  local result = map( announcements, utils.parse_item_link )

  -- Then
  lu.assertEquals( items_dropped, {
    { id = 123, link = "|cff9d9d9d|Hitem:123::::::::20:257::::::|h[Legendary item]|h|r", name = "Legendary item", quality = 5 },
    { id = 124, link = "|cff9d9d9d|Hitem:124::::::::20:257::::::|h[Epic item]|h|r", name = "Epic item", quality = 4 },
    { id = 125, link = "|cff9d9d9d|Hitem:125::::::::20:257::::::|h[Rare item]|h|r", name = "Rare item", quality = 3 },
    { id = 126, link = "|cff9d9d9d|Hitem:126::::::::20:257::::::|h[Uncommon item]|h|r", name = "Uncommon item", quality = 2 },
    { id = 127, link = "|cff9d9d9d|Hitem:127::::::::20:257::::::|h[Common item]|h|r", name = "Common item", quality = 1 },
    { id = 128, link = "|cff9d9d9d|Hitem:128::::::::20:257::::::|h[Poor item]|h|r", name = "Poor item", quality = 0 }
  } )

  lu.assertEquals( result, {
    "1. [Legendary item]",
    "2. [Epic item]",
    "3. [Rare item]",
    "4. [Uncommon item]",
    "5. [Common item]",
    "6. [Poor item]"
  } )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

os.exit( runner:runSuite( "-T", "Spec", "-m", "should", "-v" ) )
