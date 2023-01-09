---@diagnostic disable-next-line: undefined-global
local lib_stub = LibStub
local major = 1
local minor = 19
local version = string.format( "%s.%s", major, minor )
local M = lib_stub:NewLibrary( string.format( "RollFor-%s", major ), minor )
if not M then return end

local ace_timer = lib_stub( "AceTimer-3.0" )
local ace_comm = lib_stub( "AceComm-3.0" )
local ace_gui = lib_stub( "AceGUI-3.0" )

M.db = lib_stub( "AceDB-3.0" ):New( "RollForDb" )

local modules = lib_stub( "RollFor-Modules" )
local pretty_print = modules.pretty_print

local m_timer = nil
local m_seconds_left = nil
local m_rolled_item = nil
local m_rolled_item_count = 0
local m_rolled_item_reserved = false
local m_rolling = false
local m_rerolling = false
local m_rolls = {}
local m_offspec_rolls = {}
local m_rollers = {}
local m_offspec_rollers = {}
local m_winner_count = 0
local m_announced_source_ids = {}
local m_announcing = false
local m_cancelled = false
local m_item_to_be_awarded = nil
local m_item_award_confirmed = false
local m_dropped_items = {}

local m_real_api = nil

-- Persisted values
local m_softres_data = nil

-- Non-persisted softres values
local m_softres_frame = nil
local m_softres_data_dirty = false

local comm_prefix = "RollFor"
local was_in_group = false

M.item_utils = modules.ItemUtils
M.dropped_loot_announce = modules.DroppedLootAnnounce

M.trade_tracker = modules.TradeTracker.new(
  function( recipient, items_given, items_received )
    local function get_dropped_item_name( item_id )
      for _, item in pairs( m_dropped_items ) do
        if item.id == item_id then return item.name end
      end

      return nil
    end

    for i = 1, #items_given do
      local item = items_given[ i ]
      local item_id = M.item_utils.get_item_id( item.link )
      local item_name = get_dropped_item_name( item_id )

      if item_name then
        M.award_item( recipient, item_id, item_name, item.link )
      end
    end

    for i = 1, #items_received do
      local item = items_received[ i ]
      local item_id = M.item_utils.get_item_id( item.link )

      if M.awarded_loot.has_item_been_awarded( recipient, item_id ) then
        M.unaward_item( recipient, item_id, item.link )
      end
    end
  end
)

M.softres = nil

function M.import_softres_data( softres_data )
  M.awarded_loot = modules.AwardedLoot.new() -- This must be here otherwise it doesnt read from the db.
  M.group_roster = modules.GroupRoster.new( modules.api )
  M.name_matcher = modules.NameMatcher.new( M.group_roster )
  local sr = modules.SoftRes.new( softres_data )
  M.name_matcher.auto_match( sr.get_all_softres_player_names() )
  local asr = modules.SoftResAwardedLootDecorator.new( M.name_matcher, M.awarded_loot, sr )
  local msr = modules.SoftResMatchedNameDecorator.new( M.name_matcher, asr )
  M.softres = modules.SoftResAbsentPlayersDecorator.new( modules.GroupRoster.new( modules.api ), msr )
end

local function reset()
  m_timer = nil
  m_seconds_left = nil
  m_rolled_item = nil
  m_rolled_item_count = 0
  m_rolled_item_reserved = false
  m_rolling = false
  m_rerolling = false
  m_rolls = {}
  m_offspec_rolls = {}
  m_rollers = {}
  m_offspec_rollers = {}
  m_winner_count = 0
  m_announced_source_ids = {}
  m_announcing = false
  m_cancelled = false
  m_item_to_be_awarded = nil
  m_item_award_confirmed = false
  m_dropped_items = {}
  m_softres_data_dirty = false
end

local function update_group_status()
  was_in_group = modules.api.IsInGroup() or modules.api.IsInRaid()
end

local highlight = function( word )
  return string.format( "|cffff9f69%s|r", word )
end

--local red = function( word )
--return string.format( "|cffff2f2f%s|r", word )
--end

local function report( text )
  local _silent = true

  if modules.api.IsInRaid() and not _silent then
    modules.api.SendChatMessage( text, "RAID" )
  elseif modules.api.IsInGroup() and not _silent then
    modules.api.SendChatMessage( text, "PARTY" )
  else
    pretty_print( text )
  end
end

local function map( t, f )
  if type( f ) ~= "function" then return t end

  local result = {}

  for k, v in pairs( t ) do
    result[ k ] = f( v )
  end

  return result
end

local function get_all_players()
  return map( M.group_roster.get_all_players_in_my_group(), function( player )
    return { name = player, rolls = 1 }
  end )
end

local function include_reserved_rolls( item_id )
  local reservedByPlayers = M.softres.get( item_id )
  local reserving_player_count = modules.count_elements( reservedByPlayers )
  local rollers = reservedByPlayers and reserving_player_count > 0 and reservedByPlayers or get_all_players()
  table.sort( reservedByPlayers, function( l, r ) return l.name < r.name end )
  return rollers, reservedByPlayers, reserving_player_count
end

local function show_softres()
  local needsRefetch = false
  local softressed_item_ids = M.softres.get_item_ids()
  local items = {}

  for _, item_id in pairs( softressed_item_ids ) do
    local players = M.softres.get( item_id )
    local itemLink = modules.fetch_item_link( item_id )

    if not itemLink then
      needsRefetch = true
    else
      items[ itemLink ] = players
    end
  end

  if needsRefetch then
    pretty_print( "Not all items were fetched. Retrying..." )
    ace_timer:ScheduleTimer( show_softres, 1 )
    return
  end

  if modules.count_elements( items ) == 0 then
    report( "No soft-res items found." )
    return
  end

  report( "Soft-ressed items (red players are not in your group):" )
  local colorize = function( player )
    local rolls = player.rolls > 1 and string.format( " (%s)", player.rolls ) or ""
    return string.format( "|cff%s%s|r%s",
      M.group_roster.is_player_in_my_group( player.name ) and "ffffff" or "ff2f2f",
      player.name, rolls )
  end

  for itemLink, players in pairs( items ) do
    if modules.count_elements( players ) > 0 then
      report( string.format( "%s: %s", itemLink, modules.prettify_table( players, colorize ) ) )
    end
  end
end

local function update_softres_data()
  if not m_softres_data_dirty then return end

  RollForDb.rollfor.softres_data = m_softres_data
  local softres_data = modules.SoftRes.decode( m_softres_data )

  M.import_softres_data( softres_data )

  if softres_data then
    pretty_print( string.format( "Data loaded successfully. Use %s command to list.", highlight( "/srs" ) ) )
  else
    pretty_print( "Could not load soft-res data." )
  end

  m_softres_data_dirty = false
end

local function there_was_a_tie( topRoll, topRollers )
  table.sort( topRollers )
  local topRollersStr = modules.prettify_table( topRollers )
  local topRollersStrColored = modules.prettify_table( topRollers, highlight )

  pretty_print( string.format( "The %shighest %sroll was %d by %s.", not m_rerolling and m_winner_count > 0 and "next " or "",
    m_rerolling and "re-" or "", topRoll, topRollersStrColored ), modules.get_group_chat_type() )
  modules.api.SendChatMessage( string.format( "The %shighest %sroll was %d by %s.",
    not m_rerolling and m_winner_count > 0 and "next " or "",
    m_rerolling and "re-" or "", topRoll, topRollersStr ), modules.get_group_chat_type() )
  m_rolls = {}
  m_rollers = map( topRollers, function( player_name ) return { name = player_name, rolls = 1 } end )
  m_offspec_rollers = {}
  m_rerolling = true
  m_rolling = true
  ace_timer:ScheduleTimer( function() modules.api.SendChatMessage( string.format( "%s /roll for %s now.", topRollersStr, m_rolled_item.link ),
      modules.get_group_chat_type() )
  end, 2.5 )
end

local function cancel_rolling_timer()
  ace_timer:CancelTimer( m_timer )
  m_timer = nil
end

local function print_rolling_complete()
  pretty_print( string.format( "Rolling for %s has %s.", m_rolled_item.link, m_cancelled and "been cancelled" or "finished" ) )
end

local function stop_rolling()
  if not m_rolling then return end

  m_rolling = false
end

local function sort_rolls( rolls )
  local function roll_map( _rolls )
    local result = {}

    for _, roll in pairs( _rolls ) do
      if not result[ roll ] then result[ roll ] = true end
    end

    return result
  end

  local function to_map( _rolls )
    local result = {}

    for k, v in pairs( _rolls ) do
      if result[ v ] then
        table.insert( result[ v ][ "players" ], k )
      else
        result[ v ] = { roll = v, players = { k } }
      end
    end

    return result
  end

  local function f( l, r )
    if l > r then
      return true
    else
      return false
    end
  end

  local function to_sorted_rolls_array( rollMap )
    local result = {}

    for k in pairs( rollMap ) do
      table.insert( result, k )
    end

    table.sort( result, f )
    return result
  end

  local function merge( sortedRolls, t )
    local result = {}

    for _, v in ipairs( sortedRolls ) do
      table.insert( result, t[ v ] )
    end

    return result
  end

  local sortedRolls = to_sorted_rolls_array( roll_map( rolls ) )
  local t = to_map( rolls )

  return merge( sortedRolls, t )
end

local function show_sorted_rolls( limit )
  local sortedRolls = sort_rolls( m_rolls )
  local i = 1

  pretty_print( "Rolls:" )

  for _, v in ipairs( sortedRolls ) do
    if limit and limit > 0 and i > limit then return end

    pretty_print( string.format( "[|cffff9f69%d|r]: %s", v[ "roll" ], modules.prettify_table( v[ "players" ] ) ) )
    i = i + 1
  end
end

local function print_winner( roll, players, is_offspec )
  local f = highlight
  local offspec = is_offspec and " (OS)" or ""

  pretty_print( string.format( "%s %srolled the %shighest (%s) for %s%s.", modules.prettify_table( players, f ),
    m_rerolling and "re-" or "", not m_rerolling and m_winner_count > 0 and "next " or "", f( roll ), m_rolled_item.link, offspec ) )
  modules.api.SendChatMessage( string.format( "%s %srolled the %shighest (%d) for %s%s.", modules.prettify_table( players ),
    m_rerolling and "re-" or "", not m_rerolling and m_winner_count > 0 and "next " or "", roll, m_rolled_item.link, offspec ),
    modules.get_group_chat_type() )
end

local function have_all_players_rolled_offspec()
  if #m_offspec_rollers == 0 then return false end

  for _, v in pairs( m_offspec_rollers ) do
    if v.rolls > 0 then return false end
  end

  return true
end

local function have_all_rolls_been_exhausted()
  local mainspec_roll_count = modules.count_elements( m_rolls )
  local offspec_roll_count = modules.count_elements( m_offspec_rolls )
  local total_roll_count = mainspec_roll_count + offspec_roll_count

  if m_rolled_item_count == #m_offspec_rollers and have_all_players_rolled_offspec() or
      #m_rollers == m_rolled_item_count and total_roll_count == #m_rollers then
    return true
  end

  for _, v in pairs( m_rollers ) do
    if v.rolls > 0 then return false end
  end

  return true
end

local function reindex( t )
  local result = {}

  for _, v in pairs( t ) do
    table.insert( result, v )
  end

  return result
end

local function announce_extra_rolls_left()
  local remaining_rollers = reindex( modules.filter( m_rollers, function( _, roller ) return roller.rolls > 0 end ) )

  local transform = function( player )
    local rolls = player.rolls == 1 and "1 roll" or string.format( "%s rolls", player.rolls )
    return string.format( "%s (%s)", player.name, rolls )
  end

  local message = modules.prettify_table( remaining_rollers, transform )
  modules.api.SendChatMessage( string.format( "SR rolls remaining: %s", message ), modules.get_group_chat_type() )
end

local function was_there_a_tie( sorted_rolls )
  if #sorted_rolls == 0 then return false end

  return #sorted_rolls[ 1 ].players > 1
end

local function process_sorted_rolls( sorted_rolls, forced, rolls_exhausted, is_offspec, fallback_fn )
  for _, v in ipairs( sorted_rolls ) do
    local roll = v[ "roll" ]
    local players = v[ "players" ]
    local candidate_count = m_winner_count + #players

    if m_rolled_item_count == candidate_count then
      if m_rolled_item_reserved and not forced and not rolls_exhausted then
        print_winner( roll, players, is_offspec )
        announce_extra_rolls_left()
      else
        stop_rolling()
        print_winner( roll, players, is_offspec )
        m_winner_count = m_winner_count + 1
      end

      return
    elseif was_there_a_tie( sorted_rolls ) and (rolls_exhausted or is_offspec or m_seconds_left <= 0) then
      there_was_a_tie( roll, players )
      return
    else
      print_winner( roll, players, is_offspec )

      if forced then
        stop_rolling()
        m_winner_count = m_winner_count + 1
        return
      elseif m_rolled_item_reserved and not rolls_exhausted then
        announce_extra_rolls_left()
        return
      end

      m_winner_count = m_winner_count + 1
    end
  end

  if fallback_fn and m_winner_count < m_rolled_item_count then
    fallback_fn()
  else
    stop_rolling()
  end
end

local function finalize_rolling( forced )
  cancel_rolling_timer()
  local rolls_exhausted = have_all_rolls_been_exhausted()

  local mainspec_roll_count = modules.count_elements( m_rolls )
  local offspec_roll_count = modules.count_elements( m_offspec_rolls )

  if mainspec_roll_count + offspec_roll_count == 0 then
    stop_rolling()
    pretty_print( string.format( "Nobody rolled for %s.", m_rolled_item.link ) )
    modules.api.SendChatMessage( string.format( "Nobody rolled for %s.", m_rolled_item.link ), modules.get_group_chat_type() )
    print_rolling_complete()
    return
  end

  local offspec_rolling = function() process_sorted_rolls( sort_rolls( m_offspec_rolls ), forced, rolls_exhausted, true ) end

  if mainspec_roll_count > 0 then
    process_sorted_rolls( sort_rolls( m_rolls ), forced, rolls_exhausted, false, offspec_rolling )
  else
    offspec_rolling()
  end

  if not m_rolling then
    print_rolling_complete()
  end
end

local function on_timer()
  if not m_timer then return end

  m_seconds_left = m_seconds_left - 1

  if m_seconds_left <= 0 then
    finalize_rolling()
  elseif m_seconds_left == 3 then
    modules.api.SendChatMessage( "Stopping rolls in 3", modules.get_group_chat_type() )
  elseif m_seconds_left < 3 then
    modules.api.SendChatMessage( m_seconds_left, modules.get_group_chat_type() )
  end
end

local function get_roll_announcement_chat_type()
  local chatType = modules.get_group_chat_type()
  local rank = modules.my_raid_rank()

  if chatType == "RAID" and rank > 0 then
    return "RAID_WARNING"
  else
    return chatType
  end
end

local function get_softres_info( softRessers, f )
  return string.format( "(SR by %s)", modules.prettify_table( softRessers, f ) )
end

local function subtract( from, t )
  local result = {}

  for _, v in ipairs( from ) do
    if not modules.table_contains_value( t, v, function( entry ) return entry.name end ) then
      table.insert( result, v )
    end
  end

  return result
end

local function compose( f1, f2 )
  return function( value )
    return f2( f1( value ) )
  end
end

local function copy_roller( roller )
  return { name = roller.name, rolls = roller.rolls }
end

local function copy_rollers( t )
  local result = {}

  for k, v in pairs( t ) do
    result[ k ] = copy_roller( v )
  end

  return result
end

local function roll_for( whoCanRoll, count, item, seconds, info, reservedBy )
  m_rollers = whoCanRoll
  m_rolled_item = item
  m_rolled_item_count = count
  local softResCount = #reservedBy
  m_rolled_item_reserved = softResCount > 0

  local name_with_rolls = function( player )
    if softResCount == count then return player.name end
    local rolls = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
    return string.format( "%s%s", player.name, rolls )
  end

  if m_rolled_item_reserved and softResCount <= count then
    pretty_print( string.format( "%s is soft-ressed by %s.",
      softResCount < count and string.format( "%dx%s out of %d", softResCount, item.link, count ) or item.link,
      modules.prettify_table( reservedBy, compose( name_with_rolls, highlight ) ) ) )

    modules.api.SendChatMessage( string.format( "%s is soft-ressed by %s.",
      softResCount < count and string.format( "%dx%s out of %d", softResCount, item.link, count ) or item.link,
      modules.prettify_table( reservedBy, name_with_rolls ) ), get_roll_announcement_chat_type() )

    m_rolled_item_count = count - softResCount
    info = string.format( "(everyone except %s can roll). /roll (MS) or /roll 99 (OS)",
      modules.prettify_table( reservedBy, function( player ) return player.name end ) )
    m_rollers = subtract( M.group_roster.get_all_players_in_my_group(), reservedBy )
    m_offspec_rollers = {}
  elseif softResCount > 0 then
    info = get_softres_info( reservedBy, name_with_rolls )
  else
    if not info or info == "" then info = "/roll (MS) or /roll 99 (OS)" end
    m_offspec_rollers = copy_rollers( m_rollers )
  end

  if m_rolled_item_count == 0 or #m_rollers == 0 then
    stop_rolling()
    return
  end

  m_winner_count = 0
  m_seconds_left = seconds
  m_rolls = {}
  m_offspec_rolls = {}

  local countInfo = ""

  if m_rolled_item_count > 1 then countInfo = string.format( ". %d top rolls win.", m_rolled_item_count ) end

  modules.api.SendChatMessage( string.format( "Roll for %s%s:%s%s",
    m_rolled_item_count > 1 and string.format( "%dx", m_rolled_item_count ) or "", item.link,
    (not info or info == "") and "." or string.format( " %s", info ), countInfo ), get_roll_announcement_chat_type() )
  m_rerolling = false
  m_rolling = true
  m_timer = ace_timer:ScheduleRepeatingTimer( on_timer, 1.7 )
end

local function announce_hr( item )
  modules.api.SendChatMessage( string.format( "%s is hard-ressed.", item ), get_roll_announcement_chat_type() )
end

local function process_roll_for_slash_command( args, slashCommand, whoRolls )
  if not modules.api.IsInGroup() then
    pretty_print( "Not in a group." )
    return
  end

  for itemCount, item_link, seconds, info in (args):gmatch "(%d*)[xX]?(|%w+|Hitem.+|r)%s*(%d*)%s*(.*)" do
    if m_rolling then
      pretty_print( "Rolling already in progress." )
      return
    end

    local count = (not itemCount or itemCount == "") and 1 or tonumber( itemCount )
    local item_id = M.item_utils.get_item_id( item_link )
    local rollers, reservedByPlayers = whoRolls( item_id )
    local item = { link = item_link, id = item_id }

    if M.softres.is_item_hardressed( item_id ) then
      announce_hr( item_link )
      return
    elseif seconds and seconds ~= "" and seconds ~= " " then
      local secs = tonumber( seconds )
      roll_for( rollers, count, item, secs <= 3 and 4 or secs, info, reservedByPlayers )
    else
      roll_for( rollers, count, item, 8, info, reservedByPlayers )
    end

    return
  end

  pretty_print( string.format( "Usage: %s <%s> [%s]", slashCommand, highlight( "item" ), highlight( "seconds" ) ) )
end

local function process_show_sorted_rolls_slash_command( args )
  if m_rolling then
    pretty_print( "Rolling is in progress." )
    return
  end

  if not m_rolls or modules.count_elements( m_rolls ) == 0 then
    pretty_print( "No rolls found." )
    return
  end

  for limit in (args):gmatch "(%d+)" do
    show_sorted_rolls( tonumber( limit ) )
    return
  end

  show_sorted_rolls( 5 )
end

local function decorate_with_rolling_check( f )
  return function( ... )
    if not m_rolling then
      pretty_print( "Rolling not in progress." )
      return
    end

    f( ... )
  end
end

local function process_cancell_roll_slash_command()
  cancel_rolling_timer()
  m_cancelled = true
  stop_rolling()
  print_rolling_complete()
end

local function process_finish_roll_slash_command()
  finalize_rolling( true )
end

local function clear_storage()
  RollForDb.rollfor = {}
  RollForDb.rollfor.softres_items = {}
  RollForDb.rollfor.hardres_items = {}
  RollForDb.rollfor.softres_player_name_overrides = {}
  RollForDb.rollfor.softres_passing = {}
  RollForDb.rollfor.softres_data = ""
  RollForDb.rollfor.awarded_items = {}
  RollForDb.rollfor.dropped_items = {}

  m_softres_data = RollForDb.rollfor.softres_data
  m_dropped_items = RollForDb.rollfor.dropped_items
end

local function setup_storage()
  RollForDb.rollfor = RollForDb.rollfor or {}

  -- Future-proof the data if we need to do the migration.
  if not RollForDb.rollfor.version then
    RollForDb.rollfor.version = version
  end


  RollForDb.rollfor.softres_player_name_overrides = RollForDb.rollfor.softres_player_name_overrides or {}
  RollForDb.rollfor.softres_passing = RollForDb.rollfor.softres_passing or {}

  RollForDb.rollfor.softres_data = RollForDb.rollfor.softres_data or nil
  m_softres_data = RollForDb.rollfor.softres_data

  RollForDb.rollfor.awarded_items = RollForDb.rollfor.awarded_items or {}

  RollForDb.rollfor.dropped_items = RollForDb.rollfor.dropped_items or {}
  m_dropped_items = RollForDb.rollfor.dropped_items
  m_softres_data_dirty = true
end

local function check_softres()
  pretty_print( "TODO: Implement me!" )
end

local function show_gui()
  m_softres_frame = ace_gui:Create( "Frame" )
  m_softres_frame.frame:SetFrameStrata( "DIALOG" )
  m_softres_frame:SetTitle( "SoftResLoot" )
  m_softres_frame:SetLayout( "Fill" )
  m_softres_frame:SetWidth( 565 )
  m_softres_frame:SetHeight( 300 )
  m_softres_frame:SetCallback( "OnClose",
    function( widget )
      if not m_softres_data_dirty then
        if not m_softres_data then
          pretty_print( "Invalid or no soft-res data found." )
        else
          check_softres()
        end
      else
        update_softres_data()
        check_softres()
      end

      ace_gui:Release( widget )
    end
  )

  m_softres_frame:SetStatusText( "" )

  local importEditBox = ace_gui:Create( "MultiLineEditBox" )
  importEditBox:SetFullWidth( true )
  importEditBox:SetFullHeight( true )
  importEditBox:DisableButton( true )
  importEditBox:SetLabel( "SoftRes.it data" )

  if m_softres_data then
    importEditBox:SetText( m_softres_data )
  end

  importEditBox:SetCallback( "OnTextChanged", function()
    m_softres_data_dirty = true
    m_softres_data = importEditBox:GetText()
  end )

  m_softres_frame:AddChild( importEditBox )
end

local function process_softres_slash_command( args )
  if args == "init" then
    clear_storage()
    M.awarded_loot = modules.AwardedLoot.new()
    pretty_print( "Soft-res data cleared." )

    return
  end

  show_gui()
end

local function has_rolls_left( player_name, offspec_roll )
  local rollers = offspec_roll and m_offspec_rollers or m_rollers

  for _, v in pairs( rollers ) do
    if v.name == player_name then
      return v.rolls > 0
    end
  end

  return false
end

local function subtract_roll( player_name, offspec )
  local rollers = offspec and m_offspec_rollers or m_rollers

  for _, v in pairs( rollers ) do
    if v.name == player_name then
      v.rolls = v.rolls - 1
      return
    end
  end
end

local function record_roll( player_name, roll, offspec )
  local rolls = offspec and m_offspec_rolls or m_rolls

  if not rolls[ player_name ] or rolls[ player_name ] < roll then
    rolls[ player_name ] = roll
  end
end

local function on_roll( player, roll, min, max )
  if not m_rolling or min ~= 1 or (max ~= 99 and max ~= 100) then return end

  local offspec_roll = max == 99
  local soft_ressed = #M.softres.get( m_rolled_item.id ) > 0
  local soft_ressed_by_player = M.softres.is_player_softressing( player, m_rolled_item.id )

  if soft_ressed and not soft_ressed_by_player then
    pretty_print( string.format( "|cffff9f69%s|r did not SR %s. This roll (|cffff9f69%s|r) is ignored.", player, m_rolled_item.link, roll ) )
    return
  elseif soft_ressed and soft_ressed_by_player and offspec_roll then
    pretty_print( string.format( "|cffff9f69%s|r did SR %s, but rolled OS. This roll (|cffff9f69%s|r) is ignored.", player, m_rolled_item.link, roll ) )
    return
  elseif not has_rolls_left( player, offspec_roll ) then
    pretty_print( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player, roll ) )
    return
  end

  subtract_roll( player, offspec_roll )
  record_roll( player, roll, offspec_roll )

  if have_all_rolls_been_exhausted() then finalize_rolling() end
end

function M.on_chat_msg_system( message )
  for player, roll, min, max in (message):gmatch( "([^%s]+) rolls (%d+) %((%d+)%-(%d+)%)" ) do
    on_roll( player, tonumber( roll ), tonumber( min ), tonumber( max ) )
  end
end

local function version_recently_reminded()
  if not RollForDb.rollfor.last_new_version_reminder_timestamp then return false end

  local time = modules.lua.time()

  -- Only remind once a day
  if time - RollForDb.rollfor.last_new_version_reminder_timestamp > 3600 * 24 then
    return false
  else
    return true
  end
end

local function strip_dots( v )
  local result, _ = v:gsub( "%.", "" )
  return result
end

local function is_new_version( v )
  local myVersion = tonumber( strip_dots( version ) )
  local theirVersion = tonumber( strip_dots( v ) )

  return theirVersion > myVersion
end

-- OnComm(prefix, message, distribution, sender)
local function on_comm( prefix, message, _, _ )
  if prefix ~= comm_prefix then return end

  local cmd, value = modules.lua.strmatch( message, "^(.*)::(.*)$" )

  if cmd == "VERSION" and is_new_version( value ) and not version_recently_reminded() then
    RollForDb.rollfor.last_new_version_reminder_timestamp = modules.lua.time()
    pretty_print( string.format( "New version (%s) is available!", highlight( string.format( "v%s", value ) ) ) )
  end
end

local function broadcast_version( target )
  ace_comm:SendCommMessage( comm_prefix, "VERSION::" .. version, target )
end

local function broadcast_version_to_the_guild()
  if not modules.api.IsInGuild() then return end
  broadcast_version( "GUILD" )
end

local function broadcast_version_to_the_group()
  if not modules.api.IsInGroup() and not modules.api.IsInRaid() then return end
  broadcast_version( modules.api.IsInRaid() and "RAID" or "PARTY" )
end

local function mock_table_function( _api, name, values )
  _api[ name ] = function( key )
    local value = values[ key ]

    if type( value ) == "function" then
      return value()
    else
      return value
    end
  end
end

local function make_loot_slot_info( count, quality )
  local result = {}

  for i = 1, count do
    table.insert( result, function()
      if i == count then
        modules.api = modules.real_api
        modules.real_api = nil
      end

      return nil, nil, nil, nil, quality or 4
    end )
  end

  return result
end

function M.on_joined_group()
  if not was_in_group then
    broadcast_version_to_the_group()
  end

  update_group_status()
end

function M.on_left_group()
  update_group_status()
end

function M.on_loot_ready()
  if not modules.is_player_master_looter() or m_announcing then return end

  local source_guid, items, announcements = M.dropped_loot_announce.process_dropped_items( M.softres )
  local was_announced = m_announced_source_ids[ source_guid ]
  if was_announced then return end

  m_announcing = true
  local item_count = #items

  local target = modules.api.UnitName( "target" )
  local target_msg = target and not modules.api.UnitIsFriend( "player", "target" ) and string.format( " by %s", target ) or ""

  if item_count > 0 then
    modules.api.SendChatMessage( string.format( "%s item%s dropped%s:", item_count, item_count > 1 and "s" or "", target_msg ), modules.get_group_chat_type() )

    for i = 1, item_count do
      local item = items[ i ]
      table.insert( m_dropped_items, { id = item.id, name = item.name } )
    end

    for i = 1, #announcements do
      modules.api.SendChatMessage( announcements[ i ], modules.get_group_chat_type() )
    end

    RollForDb.rollfor.dropped_items = m_dropped_items
    m_announced_source_ids[ source_guid ] = true
  end

  m_announcing = false
end

local function simulate_loot_dropped( args )
  local item_links = M.item_utils.parse_all_links( args )

  if m_real_api then
    pretty_print( "Mocking in progress." )
    return
  end

  modules.real_api = modules.api
  modules.api = modules.clone( modules.api )
  modules.api[ "GetNumLootItems" ] = function() return #item_links end
  modules.api[ "GetLootSourceInfo" ] = function() return tostring( modules.lua.time() ) end
  mock_table_function( modules.api, "GetLootSlotLink", item_links )
  mock_table_function( modules.api, "GetLootSlotInfo", make_loot_slot_info( #item_links, 4 ) )

  M.on_loot_ready()
end

function M.on_first_enter_world()
  reset()

  -- Roll For commands
  SLASH_RF1 = "/rf"
  modules.api.SlashCmdList[ "RF" ] = function( args ) process_roll_for_slash_command( args, "/rf", include_reserved_rolls ) end
  SLASH_ARF1 = "/arf"
  modules.api.SlashCmdList[ "ARF" ] = function( args ) process_roll_for_slash_command( args, "/arf", get_all_players ) end
  SLASH_CR1 = "/cr"
  modules.api.SlashCmdList[ "CR" ] = decorate_with_rolling_check( process_cancell_roll_slash_command )
  SLASH_FR1 = "/fr"
  modules.api.SlashCmdList[ "FR" ] = decorate_with_rolling_check( process_finish_roll_slash_command )

  -- Soft Res commands
  SLASH_SR1 = "/sr"
  modules.api.SlashCmdList[ "SR" ] = process_softres_slash_command
  SLASH_SSR1 = "/ssr"
  modules.api.SlashCmdList[ "SSR" ] = process_show_sorted_rolls_slash_command
  SLASH_SRS1 = "/srs"
  modules.api.SlashCmdList[ "SRS" ] = show_softres

  SLASH_DROPPED1 = "/DROPPED"
  modules.api.SlashCmdList[ "DROPPED" ] = simulate_loot_dropped

  setup_storage()
  update_softres_data()

  broadcast_version_to_the_guild()
  broadcast_version_to_the_group()

  ace_comm:RegisterComm( comm_prefix, on_comm )
  update_group_status()

  pretty_print( string.format( "Loaded (%s).", highlight( string.format( "v%s", version ) ) ) )
end

---@diagnostic disable-next-line: unused-local, unused-function
local function on_party_message( message, player )
  for name, roll in (message):gmatch( "(%a+) rolls (%d+)" ) do
    --M:Print( string.format( "Party: %s %s", name, message ) )
    on_roll( name, tonumber( roll ), 1, 100 )
  end
  for name, roll in (message):gmatch( "(%a+) rolls os (%d+)" ) do
    --M:Print( string.format( "Party: %s %s", name, message ) )
    on_roll( name, tonumber( roll ), 1, 99 )
  end
end

local function idempotent_hookscript( frame, event, callback )
  if not frame.RollForHookScript then
    frame.RollForHookScript = frame.HookScript

    frame.HookScript = function( self, _event, f )
      if _event:find( "RollForIdempotent", 1, true ) == 1 then
        if not frame[ _event ] then
          local real_event = _event:gsub( "RollForIdempotent", "" )
          frame.RollForHookScript( self, real_event, f )
          frame[ _event ] = true
        end
      else
        frame.RollForHookScript( self, _event, f )
      end
    end
  end

  frame:HookScript( "RollForIdempotent" .. event, callback )
end

local function find_loot_confirmation_details()
  local frames = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }

  for i = 1, #frames do
    local base_frame_name = frames[ i ]
    local frame = _G[ base_frame_name .. "Text" ]

    if frame and frame:IsVisible() and frame.text_arg1 and frame.text_arg2 then
      local yes_button = _G[ base_frame_name .. "Button1" ]
      local no_button = _G[ base_frame_name .. "Button2" ]

      return base_frame_name, yes_button, no_button
    end
  end

  return nil
end

local function hook_loot_confirmation_events( base_frame_name, yes_button, no_button )
  idempotent_hookscript( yes_button, "OnClick", function()
    local text_frame = _G[ base_frame_name .. "Text" ]
    local player = text_frame and text_frame.text_arg2
    local colored_item_name = text_frame and text_frame.text_arg1

    if player and colored_item_name then
      m_item_to_be_awarded = { player = player, colored_item_name = colored_item_name }
      m_item_award_confirmed = true
      pretty_print( string.format( "Attempting to award %s with %s.", m_item_to_be_awarded.player, m_item_to_be_awarded.colored_item_name ) )
    end
  end )

  idempotent_hookscript( no_button, "OnClick", function()
    m_item_award_confirmed = false
    m_item_to_be_awarded = nil
  end )
end

function M.on_open_master_loot_list()
  for k, frame in pairs( modules.api.MasterLooterFrame ) do
    if type( k ) == "string" and k:find( "player", 1, true ) == 1 then
      idempotent_hookscript( frame, "OnClick", function()
        local base_frame_name, yes_button, no_button = find_loot_confirmation_details()
        if base_frame_name and yes_button and no_button then
          hook_loot_confirmation_events( base_frame_name, yes_button, no_button )
        end
      end )
    end
  end
end

local function get_item_id( item_name )
  for _, item in pairs( m_dropped_items ) do
    if item.name == item_name then return item.id end
  end

  return nil
end

function M.on_loot_slot_cleared()
  if m_item_to_be_awarded and m_item_award_confirmed then
    local item_name = modules.decolorize( m_item_to_be_awarded.colored_item_name )
    local item_id = get_item_id( item_name )

    if item_id then
      M.award_item( m_item_to_be_awarded.player, item_id, item_name, m_item_to_be_awarded.colored_item_name )
    else
      pretty_print( string.format( "Cannot determine item id for %s.", m_item_to_be_awarded.colored_item_name ) )
    end

    m_item_to_be_awarded = nil
    m_item_award_confirmed = false
  end
end

function M.award_item( player, item_id, item_name, item_link_or_colored_item_name )
  M.awarded_loot.award( player, item_id, item_name )
  pretty_print( string.format( "%s received %s.", highlight( player ), item_link_or_colored_item_name ) )
end

---@diagnostic disable-next-line: unused-local
function M.unaward_item( player, item_id, item_link_or_colored_item_name )
  --TODO: Think if we want to do this.
  --m_awarded_items = remove_from_awarded_items( player, item_id )
  --RollForDb.rollfor.awarded_items = m_awarded_items
  pretty_print( string.format( "%s returned %s.", highlight( player ), item_link_or_colored_item_name ) )
end

modules.EventHandler.handle_events( M )
return M
