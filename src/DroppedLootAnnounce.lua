---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local M = libStub:NewLibrary( "RollFor-DroppedLootAnnounce", 1 )
if not M then return end

local facade = libStub( "ModUiFacade-1.0" )
local item_utils = libStub( "ItemUtils" )
local api = facade.api

M.item = function( ... )
  local id, name, link, quality = ...

  return { id = id, name = name, link = link, quality = quality }
end

local function process_dropped_item( item_index )
  local link = api.GetLootSlotLink( item_index )
  if not link then return nil end

  local quality = select( 5, api.GetLootSlotInfo( item_index ) ) or 0
  if quality ~= 4 then return nil end

  local item_id = item_utils.get_item_id( link )
  local item_name = item_utils.get_item_name( link )
  --M:Print( string.format( "%s %s %s", link, quality, item_id ) )

  return M.item( item_id, item_name, link, quality )
end

local function format_item_announcement( item, softres_items, hardres_items, IncludeReservedRolls, GetSoftResInfo )
  if hardres_items[ item.id ] then
    return string.format( "%s (HR)", item.link )
  elseif softres_items[ item.id ] then
    local _, reserving_players, reserving_players_count = IncludeReservedRolls( item.id )
    if reserving_players_count == 0 then
      return item.link
    else
      local name_with_rolls = function( player )
        local rolls = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
        return string.format( "%s%s", player.name, rolls )
      end

      return string.format( "%s %s", item.link, GetSoftResInfo( reserving_players, name_with_rolls ) )
    end
  else
    return item.link
  end
end

local function decorate_items_with_ressed_messages( items, softres_items, hardres_items, IncludeReservedRolls, GetSoftResInfo )
  local result = {}

  for i = 1, #items do
    local item = items[ i ]
    local message = format_item_announcement( item, softres_items, hardres_items, IncludeReservedRolls, GetSoftResInfo )
    table.insert( result, { item = item, message = message } )
  end

  return result
end

function M.process_dropped_items( softres_items, hardres_items, IncludeReservedRolls, GetSoftResInfo )
  local source_guid = nil
  local result = {}
  local item_count = api.GetNumLootItems()

  for i = 1, item_count do
    source_guid = source_guid or api.GetLootSourceInfo( i )
    local item = process_dropped_item( i )

    if item then table.insert( result, item ) end
  end

  return source_guid or "unknown", decorate_items_with_ressed_messages( result, softres_items, hardres_items, IncludeReservedRolls, GetSoftResInfo )
end

local function distinct( items )
  local result = {}

  local function exists( item )
    for i = 1, #result do
      if result[ i ].id == item.id then return true end
    end

    return false
  end

  for i = 1, #items do
    local item = items[ i ]

    if not exists( item ) then
      table.insert( result, item )
    end
  end

  return result
end

-- The result is a list of unique items with the counts how many dropped and how many players reserve them.
function M.create_item_summary( items, softres_items, hardres_items )
  local result = {}
  local distinct_items = distinct( items )

  local function count_items( item_id )
    ---@diagnostic disable-next-line: redefined-local
    local result = 0

    for i = 1, #items do
      if items[ i ].id == item_id then result = result + 1 end
    end

    return result
  end

  -- TODO: This is a very simplistic version of counting.
  -- This needs to be extracted to separate SoftRes/HardRes modules.
  -- These modules should deal with player name overrides, absent players, received loot, etc.
  local function count_soft_ressers( item_id )
    return softres_items and softres_items[ item_id ] and #softres_items[ item_id ] or 0
  end

  -- NOTE: As of now fucking softres.it doesn't allow to both HR and SR, which is stupid,
  -- because there are items that drop multiple times, like tokens for example.
  -- One token could be HRed and the other could go to SR.
  -- A workaround would be not to HR items in softres.it and allow adding HR items via
  -- the addon. This should only be done for items that drop multiple times though
  -- to avoid the drama if someone SR the item that is HRed.
  local function is_hardressed( item_id )
    for _, v in pairs( hardres_items ) do
      if v.id == item_id then return true end
    end

    return false
  end

  for i = 1, #distinct_items do
    local item = distinct_items[ i ]
    local item_count = count_items( item.id )
    local softres_count = count_soft_ressers( item.id )
    local hardressed = is_hardressed( item.id )

    table.insert( result, { item = item, how_many_dropped = item_count, softres_count = softres_count, is_hardressed = hardressed } )
  end

  return result
end

return M
