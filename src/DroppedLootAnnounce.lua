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
  if quality < RollFor.settings.lootQualityThreshold then return nil end

  local item_id = item_utils.get_item_id( link )
  local item_name = item_utils.get_item_name( link )

  return M.item( item_id, item_name, link, quality )
end

function M.process_dropped_items( softres_items, hardres_items )
  local source_guid = nil
  local items = {}
  local item_count = api.GetNumLootItems()

  for i = 1, item_count do
    source_guid = source_guid or api.GetLootSourceInfo( i )
    local item = process_dropped_item( i )

    if item then table.insert( items, item ) end
  end

  local summary = M.create_item_summary( items, softres_items, hardres_items )
  return source_guid or "unknown", items, M.create_item_announcements( summary )
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

  -- TODO: This is a very simplistic version.
  -- This needs to be extracted to separate SoftRes/HardRes modules.
  -- These modules should deal with player name overrides, absent players, received loot, etc.
  local function find_softressers( item_id )
    return softres_items and softres_items[ item_id ] or {}
  end

  -- NOTE: As of now fucking softres.it doesn't allow to both HR and SR, which is stupid,
  -- because there are items that drop multiple times, like tokens for example.
  -- One token could be HRed and the other could go to SR.
  -- A workaround would be not to HR items in softres.it and allow adding HR items via
  -- the addon. This should only be done for items that drop multiple times though
  -- to avoid the drama if someone SR the item that is HRed.
  local function is_hardressed( item_id )
    return hardres_items[ item_id ] == 1 or false
  end

  for i = 1, #distinct_items do
    local item = distinct_items[ i ]
    local item_count = count_items( item.id )
    local softressers = find_softressers( item.id )
    local softres_count = #softressers
    table.sort( softressers, function( l, r ) return l.name < r.name end )
    local hardressed = is_hardressed( item.id )

    if item_count > softres_count and softres_count > 0 then
      table.insert( result, { item = item, how_many_dropped = softres_count, softressers = softressers, is_hardressed = hardressed } )
      table.insert( result, { item = item, how_many_dropped = item_count - softres_count, softressers = {}, is_hardressed = hardressed } )
    else
      table.insert( result, { item = item, how_many_dropped = item_count, softressers = softressers, is_hardressed = hardressed } )
    end
  end

  return result
end

local function commify( t, f )
  local result = ""

  if #t == 0 then
    return result
  end

  if #t == 1 then
    return (f and f( t[ 1 ] ) or t[ 1 ])
  end

  for i = 1, #t - 1 do
    if result ~= "" then
      result = result .. ", "
    end

    result = result .. (f and f( t[ i ] ) or t[ i ])
  end

  result = result .. " and " .. (f and f( t[ #t ] ) or t[ #t ])
  return result
end

function M.create_item_announcements( summary )
  local result = {}
  local index = 1

  local function p( player )
    local rolls = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
    return string.format( "%s%s", player.name, rolls )
  end

  for i = 1, #summary do
    local entry = summary[ i ]
    local softres_count = #entry.softressers

    if entry.is_hardressed then
      table.insert( result, string.format( "%s. %s (HR)", index, entry.item.link ) )
      index = index + 1
    elseif softres_count == 0 then
      local count = entry.how_many_dropped
      local prefix = count == 1 and "" or string.format( "%sx", count )
      table.insert( result, string.format( "%s. %s%s", index, prefix, entry.item.link ) )
      index = index + 1
    elseif entry.how_many_dropped == softres_count then
      for j = 1, softres_count do
        table.insert( result, string.format( "%s. %s (SR by %s)", index, entry.item.link, p( entry.softressers[ j ] ) ) )
        index = index + 1
      end
    else
      local count = entry.how_many_dropped
      local prefix = count == 1 and "" or string.format( "%sx", count )
      table.insert( result, string.format( "%s. %s%s (SR by %s)", index, prefix, entry.item.link, commify( entry.softressers, p ) ) )
      index = index + 1
    end
  end

  return result
end

return M
