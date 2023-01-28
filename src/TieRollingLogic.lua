local modules = LibStub( "RollFor-Modules" )
if modules.TieRollingLogic then return end

local M = {}
local map = modules.map
local count_elements = modules.count_elements
local pretty_print = modules.pretty_print
local take = modules.take

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

function M.new( players, item, count, on_rolling_finished )
  local rollers, rolls = map( players, one_roll ), {}
  local rolling = true

  local function have_all_rolls_been_exhausted()
    local roll_count = count_elements( rolls )

    if #rollers == count and roll_count == #rollers then
      return true
    end

    for _, v in pairs( rollers ) do
      if v.rolls > 0 then return false end
    end

    return true
  end

  local function find_winner()
    rolling = false
    local roll_count = count_elements( rolls )

    if roll_count == 0 then
      on_rolling_finished( item, count, {}, true )
    end

    local sorted_rolls = sort_rolls( rolls )
    local winners = take( sorted_rolls, count )

    on_rolling_finished( item, count, winners, true )
  end

  local function on_roll( player_name, roll, min, max )
    if not rolling or min ~= 1 or max ~= 100 then return end

    if not has_rolls_left( rollers, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player_name, roll ) )
      return
    end

    subtract_roll( rollers, player_name )
    record_roll( rolls, player_name, roll )

    if have_all_rolls_been_exhausted() then find_winner() end
  end

  local function show_sorted_rolls( limit )
    local function show( prefix, sorted_rolls )
      pretty_print( string.format( "%s rolls:", prefix ) )
      local i = 0

      for _, v in ipairs( sorted_rolls ) do
        if limit and limit > 0 and i > limit then return end

        pretty_print( string.format( "[|cffff9f69%d|r]: %s", v[ "roll" ], modules.prettify_table( v[ "players" ] ) ) )
        i = i + 1
      end
    end

    show( "Tie", sort_rolls( rolls ) )
  end

  local function print_rolling_complete( cancelled )
    pretty_print( string.format( "Rolling for %s has %s.", item.link, cancelled and "been cancelled" or "finished" ) )
  end

  local function stop_rolling()
    rolling = false
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
    on_roll = on_roll,
    show_sorted_rolls = show_sorted_rolls,
    stop_rolling = stop_rolling,
    cancel_rolling = cancel_rolling,
    is_rolling = is_rolling
  }
end

modules.TieRollingLogic = M
return M
