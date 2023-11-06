local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.DroppedLootAnnounce then return end

local M = {}
local item_utils = modules.ItemUtils
local make_item = item_utils.make_item

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

local function process_dropped_item( slot )
  local link = modules.api.GetLootSlotLink( slot )
  if not link then return nil end

  local quality = select( 4, modules.api.GetLootSlotInfo( slot ) ) or 0
  if quality < modules.api.GetLootThreshold() then return nil end

  local item_id = item_utils.get_item_id( link )
  local item_name = item_utils.get_item_name( link )

  return make_item( item_id, item_name, link, quality )
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

local function stringify( announcements )
  local result = {}

  local function print_player( show_rolls )
    return function( player )
      local rolls = show_rolls and player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
      return string.format( "%s%s", player.name, rolls )
    end
  end

  for i = 1, #announcements do
    local entry = announcements[ i ]

    if entry.is_hardressed then
      table.insert( result, string.format( "%s. %s (HR)", i, entry.item_link ) )
    elseif entry.softres_count > 0 then
      local count = entry.how_many_dropped
      local prefix = count == 1 and "" or string.format( "%sx", count )
      local f = print_player( entry.softres_count > 1 )
      table.insert( result, string.format( "%s. %s%s (SR by %s)", i, prefix, entry.item_link, commify( entry.softressers, f ) ) )
    else
      local count = entry.how_many_dropped
      local prefix = count == 1 and "" or string.format( "%sx", count )
      table.insert( result, string.format( "%s. %s%s", i, prefix, entry.item_link ) )
    end
  end

  return result
end

local function sort( announcements )
  local hr = {}
  local sr = {}
  local free_roll = {}

  for _, v in pairs( announcements ) do
    if v.is_hardressed then
      table.insert( hr, v )
    elseif v.softres_count > 0 then
      table.insert( sr, v )
    else
      table.insert( free_roll, v )
    end
  end

  table.sort( sr, function( left, right )
    if left.softres_count == 1 and left.softres_count == right.softres_count then
      return left.softressers[ 1 ].name < right.softressers[ 1 ].name
    else
      return left.softres_count < right.softres_count
    end
  end )

  return modules.merge( {}, hr, sr, free_roll )
end

function M.create_item_announcements( summary )
  local result = {}

  for i = 1, #summary do
    local entry = summary[ i ]
    local softres_count = #entry.softressers

    if entry.is_hardressed then
      table.insert( result, {
        item_link = entry.item.link,
        is_hardressed = true,
        softres_count = 0
      } )
    elseif softres_count == 0 then
      table.insert( result, {
        item_link = entry.item.link,
        softres_count = 0,
        how_many_dropped = entry.how_many_dropped
      } )
    elseif entry.how_many_dropped == softres_count then
      for j = 1, softres_count do
        table.insert( result, {
          item_link = entry.item.link,
          softres_count = 1,
          how_many_dropped = 1,
          softressers = { entry.softressers[ j ] }
        } )
      end
    else
      table.insert( result, {
        item_link = entry.item.link,
        softres_count = #entry.softressers,
        how_many_dropped = entry.how_many_dropped,
        softressers = entry.softressers
      } )
    end
  end

  return stringify( sort( result ) )
end

function M.process_dropped_items( master_loot_tracker, softres )
  local source_guid = modules.api.UnitGUID( "target" )
  local items = {}
  local item_count = modules.api.GetNumLootItems()

  for slot = 1, item_count do
    local item = process_dropped_item( slot )

    if item and item.id ~= 29434 then
      table.insert( items, item )
      master_loot_tracker.add( slot, item )
    end
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

function M.new( announce, dropped_loot, master_loot_tracker, softres, ace_timer, softres_check )
  local announcing = false
  local announced_source_ids = {}

  local function on_loot_opened()
    if not modules.is_player_master_looter() or announcing then
      if modules.real_api then
        modules.api = modules.real_api
        modules.real_api = nil
      end

      return
    end

    master_loot_tracker.clear()
    local source_guid, items, announcements = M.process_dropped_items( master_loot_tracker, softres )
    local was_announced = announced_source_ids[ source_guid ]
    if was_announced then return end

    announcing = true
    local item_count = #items

    local target = modules.api.UnitName( "target" )
    local target_msg = target and not modules.api.UnitIsFriend( "player", "target" ) and string.format( "%s dropped ", target ) or ""

    if item_count > 0 then
      announce(
        string.format( "%s%s item%s%s", target_msg, item_count, item_count > 1 and "s" or "", target_msg == "" and " dropped:" or ":" ) )

      for i = 1, item_count do
        local item = items[ i ]
        dropped_loot.add( item.id, item.name )
      end

      for i = 1, #announcements do
        announce( announcements[ i ] )
      end

      dropped_loot.persist()
      announced_source_ids[ source_guid ] = true

      ace_timer:ScheduleTimer( softres_check.warn_if_no_data, 0.5 )
    end

    announcing = false
  end

  local function reset()
    local former_size = modules.count_elements( announced_source_ids )
    announced_source_ids = {}

    if former_size > 0 then
      modules.pretty_print( "Loot announcement has been reset." )
    end
  end

  return {
    on_loot_opened = on_loot_opened,
    reset = reset
  }
end

modules.DroppedLootAnnounce = M
return M
