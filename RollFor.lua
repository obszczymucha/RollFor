---@diagnostic disable-next-line: undefined-global
local lib_stub = LibStub
local major = 1
local minor = 38
local M = lib_stub:NewLibrary( string.format( "RollFor-%s", major ), minor )
if not M then return end

M.ace_timer = lib_stub( "AceTimer-3.0" )

local version = string.format( "%s.%s", major, minor )
local modules = lib_stub( "RollFor-Modules" )
local pretty_print = modules.pretty_print
local hl = modules.colors.highlight

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
local m_cancelled = false
local m_all_rolling = false

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
  m_cancelled = false
end

local function create_components()
  local m = modules

  M.api = function() return m.api end
  M.present_softres = function( softres ) return m.SoftResPresentPlayersDecorator.new( M.group_roster, softres ) end
  M.absent_softres = function( softres ) return m.SoftResAbsentPlayersDecorator.new( M.group_roster, softres ) end

  M.item_utils = m.ItemUtils
  M.version_broadcast = m.VersionBroadcast.new( M.db, version )
  M.awarded_loot = m.AwardedLoot.new( M.db )
  M.group_roster = m.GroupRoster.new( M.api )
  M.unfiltered_softres = m.SoftRes.new( M.db )
  M.name_matcher = m.NameManualMatcher.new( M.db, M.api, M.absent_softres( M.unfiltered_softres ), m.NameAutoMatcher.new( M.group_roster, M.unfiltered_softres ) )
  M.matched_name_softres = m.SoftResMatchedNameDecorator.new( M.name_matcher, M.unfiltered_softres )
  M.awarded_loot_softres = m.SoftResAwardedLootDecorator.new( M.awarded_loot, M.matched_name_softres )
  M.softres = M.present_softres( M.awarded_loot_softres )
  M.dropped_loot = m.DroppedLoot.new( M.db )
  M.dropped_loot_announce = m.DroppedLootAnnounce.new( M.dropped_loot, M.softres )
  M.softres_check = m.SoftResCheck.new( M.matched_name_softres, M.group_roster, M.name_matcher, M.ace_timer, M.absent_softres )
  M.master_loot = m.MasterLoot.new( M.dropped_loot, M.award_item )
  M.softres_gui = m.SoftResGui.new( M.update_softres_data, M.softres_check )

  M.trade_tracker = m.TradeTracker.new(
    function( recipient, items_given, items_received )
      for i = 1, #items_given do
        local item = items_given[ i ]
        local item_id = M.item_utils.get_item_id( item.link )
        local item_name = M.dropped_loot.get_dropped_item_name( item_id )

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
end

function M.import_softres_data( softres_data )
  M.unfiltered_softres.import( softres_data )
  M.name_matcher.auto_match()
end

local function get_all_players()
  return modules.map( M.group_roster.get_all_players_in_my_group(), function( player )
    return { name = player, rolls = 1 }
  end ), {}
end

local function include_reserved_rolls( item_id )
  local softressing_players = M.softres.get( item_id )
  local softressing_player_count = #softressing_players
  local rollers = softressing_players and softressing_player_count > 0 and softressing_players or get_all_players()
  table.sort( softressing_players, function( l, r ) return l.name < r.name end )
  return rollers, softressing_players, softressing_player_count
end

function M.update_softres_data( data, data_loaded_callback )
  local softres_data = modules.SoftRes.decode( data )

  if not softres_data and data and #data > 0 then
    pretty_print( "Could not load soft-res data!", modules.colors.red )
    M.import_softres_data( { softreserves = {}, hardreserves = {} } )
    return
  elseif not softres_data then
    return
  end

  M.import_softres_data( softres_data )

  pretty_print( "Soft-res data loaded successfully!" )
  if data_loaded_callback then data_loaded_callback() end
end

local function there_was_a_tie( top_roll, top_rollers )
  table.sort( top_rollers )
  local top_rollers_str = modules.prettify_table( top_rollers )
  local top_rollers_str_colored = modules.prettify_table( top_rollers, hl )

  local message = function( rollers )
    return string.format( "The %shighest %sroll was %d by %s.", not m_rerolling and m_winner_count > 0 and "next " or "",
      m_rerolling and "re-" or "", top_roll, rollers )
  end

  pretty_print( message( top_rollers_str_colored ) )
  M.api().SendChatMessage( message( top_rollers_str ), modules.get_group_chat_type() )

  m_rolls = {}
  m_rollers = modules.map( top_rollers, function( player_name ) return { name = player_name, rolls = 1 } end )
  m_offspec_rollers = {}
  m_rerolling = true
  m_rolling = true
  M.ace_timer:ScheduleTimer( function() M.api().SendChatMessage( string.format( "%s /roll for %s now.", top_rollers_str, m_rolled_item.link ),
      modules.get_group_chat_type() )
  end, 2.5 )
end

local function cancel_rolling_timer()
  M.ace_timer:CancelTimer( m_timer )
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
  local f = hl
  local offspec = is_offspec and " (OS)" or ""

  pretty_print( string.format( "%s %srolled the %shighest (%s) for %s%s.", modules.prettify_table( players, f ),
    m_rerolling and "re-" or "", not m_rerolling and m_winner_count > 0 and "next " or "", f( roll ), m_rolled_item.link, offspec ) )
  M.api().SendChatMessage( string.format( "%s %srolled the %shighest (%d) for %s%s.", modules.prettify_table( players ),
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
  local remaining_rollers = reindex( modules.filter( m_rollers, function( roller ) return roller.rolls > 0 end ) )

  local transform = function( player )
    local rolls = player.rolls == 1 and "1 roll" or string.format( "%s rolls", player.rolls )
    return string.format( "%s (%s)", player.name, rolls )
  end

  local message = modules.prettify_table( remaining_rollers, transform )
  M.api().SendChatMessage( string.format( "SR rolls remaining: %s", message ), modules.get_group_chat_type() )
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
    M.api().SendChatMessage( string.format( "Nobody rolled for %s.", m_rolled_item.link ), modules.get_group_chat_type() )
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
    M.api().SendChatMessage( "Stopping rolls in 3", modules.get_group_chat_type() )
  elseif m_seconds_left < 3 then
    M.api().SendChatMessage( m_seconds_left, modules.get_group_chat_type() )
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

local function roll_for( who_can_roll, count, item, seconds, info, reserved_by )
  m_rollers = who_can_roll
  m_rolled_item = item
  m_rolled_item_count = count
  local softres_count = #reserved_by
  m_rolled_item_reserved = softres_count > 0

  local name_with_rolls = function( player )
    if softres_count == count then return player.name end
    local rolls = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
    return string.format( "%s%s", player.name, rolls )
  end

  if m_rolled_item_reserved and softres_count <= count then
    pretty_print( string.format( "%s is soft-ressed by %s.",
      softres_count < count and string.format( "%dx%s out of %d", softres_count, item.link, count ) or item.link,
      modules.prettify_table( reserved_by, compose( name_with_rolls, hl ) ) ) )

    M.api().SendChatMessage( string.format( "%s is soft-ressed by %s.",
      softres_count < count and string.format( "%dx%s out of %d", softres_count, item.link, count ) or item.link,
      modules.prettify_table( reserved_by, name_with_rolls ) ), get_roll_announcement_chat_type() )

    m_rolled_item_count = count - softres_count
    info = string.format( "(everyone except %s can roll). /roll (MS) or /roll 99 (OS)",
      modules.prettify_table( reserved_by, function( player ) return player.name end ) )
    m_rollers = modules.map( subtract( M.group_roster.get_all_players_in_my_group(), reserved_by ),
      function( player_name ) return { name = player_name, rolls = 1 } end )
    m_offspec_rollers = {}
    m_all_rolling = true
  elseif softres_count > 0 then
    info = get_softres_info( reserved_by, name_with_rolls )
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

  M.api().SendChatMessage( string.format( "Roll for %s%s:%s%s",
    m_rolled_item_count > 1 and string.format( "%dx", m_rolled_item_count ) or "", item.link,
    (not info or info == "") and "." or string.format( " %s", info ), countInfo ), get_roll_announcement_chat_type() )
  m_rerolling = false
  m_rolling = true
  m_timer = M.ace_timer:ScheduleRepeatingTimer( on_timer, 1.7 )
end

local function announce_hr( item )
  M.api().SendChatMessage( string.format( "%s is hard-ressed.", item ), get_roll_announcement_chat_type() )
end

local function process_roll_for_slash_command( args, slashCommand, who_rolls, all_rolling )
  if not M.api().IsInGroup() then
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
    local rollers, reservedByPlayers = who_rolls( item_id )
    local item = { link = item_link, id = item_id }
    m_all_rolling = all_rolling

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

  pretty_print( string.format( "Usage: %s <%s> [%s]", slashCommand, hl( "item" ), hl( "seconds" ) ) )
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

local function setup_storage()
  M.db = lib_stub( "AceDB-3.0" ):New( "RollForDb" )

  if not M.db.global.version then
    M.db.global.version = version
  end
end

local function process_softres_slash_command( args )
  if args == "init" then
    M.dropped_loot.clear( true )
    M.awarded_loot.clear( true )
    M.softres_gui.clear()
    M.name_matcher.clear( true )
    M.softres.clear( true )
  end

  M.softres_gui.show()
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

  if not m_all_rolling and soft_ressed and not soft_ressed_by_player then
    pretty_print( string.format( "|cffff9f69%s|r did not SR %s. This roll (|cffff9f69%s|r) is ignored.", player, m_rolled_item.link, roll ) )
    return
  elseif not m_all_rolling and soft_ressed and soft_ressed_by_player and offspec_roll then
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

local function mock_table_function( name, values )
  M.api()[ name ] = function( key )
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

function M.on_loot_ready()
end

local function simulate_loot_dropped( args )
  local item_links = M.item_utils.parse_all_links( args )

  if modules.real_api then
    pretty_print( "Mocking in progress." )
    return
  end

  modules.real_api = modules.api
  modules.api = modules.clone( modules.api )
  M.api()[ "GetNumLootItems" ] = function() return #item_links end
  M.api()[ "GetLootSourceInfo" ] = function() return tostring( modules.lua.time() ) end
  mock_table_function( "GetLootSlotLink", item_links )
  mock_table_function( "GetLootSlotInfo", make_loot_slot_info( #item_links, 4 ) )

  M.dropped_loot_announce.on_loot_ready()
end

local function setup_slash_commands()
  -- Roll For commands
  SLASH_RF1 = "/rf"
  M.api().SlashCmdList[ "RF" ] = function( args ) process_roll_for_slash_command( args, "/rf", include_reserved_rolls, false ) end
  SLASH_ARF1 = "/arf"
  M.api().SlashCmdList[ "ARF" ] = function( args ) process_roll_for_slash_command( args, "/arf", get_all_players, true ) end
  SLASH_CR1 = "/cr"
  M.api().SlashCmdList[ "CR" ] = decorate_with_rolling_check( process_cancell_roll_slash_command )
  SLASH_FR1 = "/fr"
  M.api().SlashCmdList[ "FR" ] = decorate_with_rolling_check( process_finish_roll_slash_command )

  -- Soft Res commands
  SLASH_SR1 = "/sr"
  M.api().SlashCmdList[ "SR" ] = process_softres_slash_command
  SLASH_SSR1 = "/ssr"
  M.api().SlashCmdList[ "SSR" ] = process_show_sorted_rolls_slash_command
  SLASH_SRS1 = "/srs"
  M.api().SlashCmdList[ "SRS" ] = function() M.softres_check.show_softres() end
  SLASH_SRC1 = "/src"
  M.api().SlashCmdList[ "SRC" ] = function() M.softres_check.check_softres() end
  SLASH_SRO1 = "/sro"
  M.api().SlashCmdList[ "SRO" ] = function( ... ) M.name_matcher.manual_match( ... ) end

  SLASH_DROPPED1 = "/DROPPED"
  M.api().SlashCmdList[ "DROPPED" ] = simulate_loot_dropped
end

function M.on_first_enter_world()
  reset()
  setup_storage()
  create_components()
  setup_slash_commands()

  pretty_print( string.format( "Loaded (%s).", hl( string.format( "v%s", version ) ) ) )
  M.version_broadcast.broadcast()

  M.dropped_loot.import( M.db.char.dropped_items )
  M.update_softres_data( M.db.char.softres_data )
  M.softres_gui.load( M.db.char.softres_data )
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

function M.award_item( player, item_id, item_name, item_link_or_colored_item_name )
  M.awarded_loot.award( player, item_id, item_name )
  pretty_print( string.format( "%s received %s.", hl( player ), item_link_or_colored_item_name ) )
end

---@diagnostic disable-next-line: unused-local
function M.unaward_item( player, item_id, item_link_or_colored_item_name )
  --TODO: Think if we want to do this.
  --m_awarded_items = remove_from_awarded_items( player, item_id )
  --M.db.awarded_items = m_awarded_items
  pretty_print( string.format( "%s returned %s.", hl( player ), item_link_or_colored_item_name ) )
end

function M.on_group_roster_update()
  M.name_matcher.auto_match()
end

modules.EventHandler.handle_events( M )
return M
