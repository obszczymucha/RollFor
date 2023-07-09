local modules = LibStub( "RollFor-Modules" )
if modules.RollingLogicUtils then return end

local M = {}
local map = modules.map
local filter = modules.filter

function M.players_with_available_rolls( rollers )
  return filter( rollers, function( roller ) return roller.rolls > 0 end )
end

function M.can_roll( rollers, player_name )
  for _, v in ipairs( rollers ) do
    if v.name == player_name then return true end
  end

  return false
end

function M.copy_roller( roller )
  return { name = roller.name, rolls = roller.rolls }
end

function M.copy_rollers( t )
  local result = {}

  for k, v in pairs( t ) do
    result[ k ] = M.copy_roller( v )
  end

  return result
end

function M.subtract_roll( rollers, player_name )
  for _, v in pairs( rollers ) do
    if v.name == player_name then
      v.rolls = v.rolls - 1
      return
    end
  end
end

function M.record_roll( rolls, player_name, roll )
  if not rolls[ player_name ] or rolls[ player_name ] < roll then
    rolls[ player_name ] = roll
  end
end

function M.one_roll( player_name )
  return { name = player_name, rolls = 1 }
end

function M.all_present_players( group_roster )
  local player_names = map( group_roster.get_all_players_in_my_group(), function( p ) return p.name end )
  return map( player_names, M.one_roll )
end

function M.have_all_players_rolled( rollers )
  if #rollers == 0 then return false end

  for _, v in pairs( rollers ) do
    if v.rolls > 0 then return false end
  end

  return true
end

function M.sort_rolls( rolls )
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

function M.has_rolls_left( rollers, player_name )
  for _, v in pairs( rollers ) do
    if v.name == player_name then
      return v.rolls > 0
    end
  end

  return false
end

function M.has_everyone_rolled( rollers, rolls )
  local players = map( rollers, function( roller ) return roller.name end )

  for _, player_name in ipairs( players ) do
    if not rolls[ player_name ] then return false end
  end

  return true
end

modules.RollingLogicUtils = M
return M
