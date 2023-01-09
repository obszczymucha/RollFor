local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.DroppedLootAnnounce then return end

local M = {}
local item_utils = modules.ItemUtils

M.item = function( id, name, link, quality )
  return { id = id, name = name, link = link, quality = quality }
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

local function process_dropped_item( item_index )
  local link = modules.api.GetLootSlotLink( item_index )
  if not link then return nil end

  local quality = select( 5, modules.api.GetLootSlotInfo( item_index ) ) or 0
  if quality < RollFor.settings.lootQualityThreshold then return nil end

  local item_id = item_utils.get_item_id( link )
  local item_name = item_utils.get_item_name( link )

  return M.item( item_id, item_name, link, quality )
end

function M.process_dropped_items( softres )
  local source_guid = nil
  local items = {}
  local item_count = modules.api.GetNumLootItems()

  for i = 1, item_count do
    source_guid = source_guid or modules.api.GetLootSourceInfo( i )
    local item = process_dropped_item( i )

    if item then table.insert( items, item ) end
  end

  local summary = M.create_item_summary( items, softres )
  return source_guid or "unknown", items, M.create_item_announcements( summary )
end

-- The result is a list of unique items with the counts how many dropped and how many players reserve them.
function M.create_item_summary( items, softres )
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

  for i = 1, #distinct_items do
    local item = distinct_items[ i ]
    local item_count = count_items( item.id )
    local softressers = softres.get( item.id )
    local softres_count = #softressers
    table.sort( softressers, function( l, r ) return l.name < r.name end )
    local hardressed = softres.is_item_hardressed( item.id )

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

function M.new( dropped_loot, softres )
  local announcing = false
  local announced_source_ids = {}

  local function on_loot_ready()
    if not modules.is_player_master_looter() or announcing then return end

    local source_guid, items, announcements = M.process_dropped_items( softres )
    local was_announced = announced_source_ids[ source_guid ]
    if was_announced then return end

    announcing = true
    local item_count = #items

    local target = modules.api.UnitName( "target" )
    local target_msg = target and not modules.api.UnitIsFriend( "player", "target" ) and string.format( " by %s", target ) or ""

    if item_count > 0 then
      modules.api.SendChatMessage( string.format( "%s item%s dropped%s:", item_count, item_count > 1 and "s" or "", target_msg ), modules.get_group_chat_type() )

      for i = 1, item_count do
        local item = items[ i ]
        dropped_loot.add( item.id, item.name )
      end

      for i = 1, #announcements do
        modules.api.SendChatMessage( announcements[ i ], modules.get_group_chat_type() )
      end

      dropped_loot.persist()
      announced_source_ids[ source_guid ] = true
    end

    announcing = false
  end

  return {
    on_loot_ready = on_loot_ready
  }
end

modules.DroppedLootAnnounce = M
return M
