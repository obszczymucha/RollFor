local modules = LibStub( "RollFor-Modules" )
if modules.NonSoftResRollingLogic then return end

local M = {}
local map = modules.map
local count_elements = modules.count_elements
local pretty_print = modules.pretty_print
local merge = modules.merge
local take = modules.take

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

local function subtract_roll( rollers, player_name )
  for _, v in pairs( rollers ) do
    if v.name == player_name then
      v.rolls = v.rolls - 1
      return
    end
  end
end

local function record_roll( rolls, player_name, roll )
  if not rolls[ player_name ] or rolls[ player_name ] < roll then
    rolls[ player_name ] = roll
  end
end

local function one_roll( player_name )
  return { name = player_name, rolls = 1 }
end

local function all_present_players( group_roster )
  return map( group_roster.get_all_players_in_my_group(), one_roll )
end

local function have_all_players_rolled( rollers )
  if #rollers == 0 then return false end

  for _, v in pairs( rollers ) do
    if v.rolls > 0 then return false end
  end

  return true
end

local function sort_rolls( rolls )
  local function roll_map()
    local result = {}

    for _, roll in pairs( rolls ) do
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

  local function to_sorted_rolls_array( rollmap )
    local result = {}

    for k in pairs( rollmap ) do
      table.insert( result, k )
    end

    table.sort( result, f )
    return result
  end

  local sorted_rolls = to_sorted_rolls_array( roll_map() )
  local rollmap = to_map( rolls )

  return map( sorted_rolls, function( v ) return rollmap[ v ] end )
end

local function has_rolls_left( rollers, player_name )
  for _, v in pairs( rollers ) do
    if v.name == player_name then
      return v.rolls > 0
    end
  end

  return false
end

function M.new( group_roster, item, count, info, on_rolling_finished )
  local mainspec_rollers, mainspec_rolls = all_present_players( group_roster ), {}
  local offspec_rollers, offspec_rolls = copy_rollers( mainspec_rollers ), {}
  local rolling = true

  local function have_all_rolls_been_exhausted()
    local mainspec_roll_count = count_elements( mainspec_rolls )
    local offspec_roll_count = count_elements( offspec_rolls )
    local total_roll_count = mainspec_roll_count + offspec_roll_count

    if count == #offspec_rollers and have_all_players_rolled( offspec_rollers ) or
        #mainspec_rollers == count and total_roll_count == #mainspec_rollers then
      return true
    end

    for _, v in pairs( mainspec_rollers ) do
      if v.rolls > 0 then return false end
    end

    return true
  end

  local function find_winner()
    rolling = false
    local mainspec_roll_count = count_elements( mainspec_rolls )
    local offspec_roll_count = count_elements( offspec_rolls )

    if mainspec_roll_count == 0 and offspec_roll_count == 0 then
      on_rolling_finished( item, count, {} )
      return
    end

    local sorted_mainspec_rolls = sort_rolls( mainspec_rolls )
    local sorted_offspec_rolls = map( sort_rolls( offspec_rolls ), function( v ) v.offspec = true; return v end )
    local winners = take( merge( {}, sorted_mainspec_rolls, sorted_offspec_rolls ), count )

    on_rolling_finished( item, count, winners )
  end

  local function on_roll( player_name, roll, min, max )
    if not rolling or min ~= 1 or (max ~= 99 and max ~= 100) then return end
    local mainspec_roll = max == 100

    if not has_rolls_left( mainspec_roll and mainspec_rollers or offspec_rollers, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player_name, roll ) )
      return
    end

    subtract_roll( mainspec_roll and mainspec_rollers or offspec_rollers, player_name )
    record_roll( mainspec_roll and mainspec_rolls or offspec_rolls, player_name, roll )

    if have_all_rolls_been_exhausted() then find_winner() end
  end

  local function get_roll_announcement()
    local count_str = count > 1 and string.format( "%sx", count ) or ""
    local info_str = info and info ~= "" and string.format( " %s", info ) or " /roll (MS) or /roll 99 (OS)"
    local x_rolls_win = count > 1 and string.format( ". %d top rolls win.", count ) or ""

    return string.format( "Roll for %s%s:%s%s", count_str, item.link, info_str, x_rolls_win )
  end

  local function show_sorted_rolls( limit )
    local function show( prefix, sorted_rolls )
      if #sorted_rolls == 0 then return end

      pretty_print( string.format( "%s rolls:", prefix ) )
      local i = 0

      for _, v in ipairs( sorted_rolls ) do
        if limit and limit > 0 and i > limit then return end

        pretty_print( string.format( "[|cffff9f69%d|r]: %s", v[ "roll" ], modules.prettify_table( v[ "players" ] ) ) )
        i = i + 1
      end
    end

    local total_mainspec_rolls = count_elements( mainspec_rolls )
    local total_offspec_rolls = count_elements( offspec_rolls )

    if total_mainspec_rolls + total_offspec_rolls == 0 then
      pretty_print( "No rolls found." )
      return
    end

    show( "Mainspec", sort_rolls( mainspec_rolls ) )
    show( "Offspec", sort_rolls( offspec_rolls ) )
  end

  local function print_rolling_complete( cancelled )
    pretty_print( string.format( "Rolling for %s has %s.", item.link, cancelled and "been cancelled" or "finished" ) )
  end

  local function stop_rolling()
    find_winner()
  end

  local function cancel_rolling()
    rolling = false
    print_rolling_complete( true )
  end

  local function is_rolling()
    return rolling
  end

  return {
    get_roll_announcement = get_roll_announcement,
    on_roll = on_roll,
    show_sorted_rolls = show_sorted_rolls,
    stop_rolling = stop_rolling,
    cancel_rolling = cancel_rolling,
    is_rolling = is_rolling
  }
end

modules.NonSoftResRollingLogic = M
return M
