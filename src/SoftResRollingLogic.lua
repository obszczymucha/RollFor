local modules = LibStub( "RollFor-Modules" )
if modules.SoftResRollingLogic then return end

local M = {}
local map = modules.map
local count_elements = modules.count_elements
local pretty_print = modules.pretty_print
local take = modules.take
local rlu = modules.RollingLogicUtils

local State = { AfterRoll = 1, TimerStopped = 2, ManualStop = 3 }

local function is_the_winner_the_only_player_with_extra_rolls( rollers, rolls )
  local extra_rolls = rlu.players_with_available_rolls( rollers )
  if #extra_rolls > 1 then return false end

  local sorted_rolls = rlu.sort_rolls( rolls )
  return #sorted_rolls[ 1 ].players == 1 and sorted_rolls[ 1 ].players[ 1 ] == extra_rolls[ 1 ].name
end

local function winner_found( rollers, rolls )
  return rlu.has_everyone_rolled( rollers, rolls ) and is_the_winner_the_only_player_with_extra_rolls( rollers, rolls )
end

function M.new( rollers, item, count, on_rolling_finished, on_softres_rolls_available )
  local rolls = {}
  local rolling = true

  local function have_all_rolls_been_exhausted()
    for _, v in pairs( rollers ) do
      if v.rolls > 0 then return winner_found( rollers, rolls ) end
    end

    return true
  end

  local function find_winner( state )
    local rolls_exhausted = have_all_rolls_been_exhausted()
    if state == State.AfterRoll and not rolls_exhausted then return end

    if state == State.ManualStop or rolls_exhausted then
      rolling = false
    end

    local roll_count = count_elements( rolls )

    if roll_count == 0 then
      on_rolling_finished( item, count, {} )
      return
    end

    local sorted_rolls = rlu.sort_rolls( rolls )
    local winners = take( sorted_rolls, count )

    on_rolling_finished( item, count, winners )

    if state ~= State.ManualStop and not rolls_exhausted then
      on_softres_rolls_available( rlu.players_with_available_rolls( rollers ) )
    end
  end

  local function on_roll( player_name, roll, min, max )
    if not rolling or min ~= 1 or (max ~= 99 and max ~= 100) then return end
    local offspec = max == 99

    if not rlu.can_roll( rollers, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r did not SR %s. This roll (|cffff9f69%s|r) is ignored.", player_name, item.link, roll ) )
      return
    end

    if offspec then
      pretty_print( string.format( "|cffff9f69%s|r did SR %s, but rolled OS. This roll (|cffff9f69%s|r) is ignored.", player_name, item.link, roll ) )
      return
    end

    if not rlu.has_rolls_left( rollers, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player_name, roll ) )
      return
    end

    rlu.subtract_roll( rollers, player_name )
    rlu.record_roll( rolls, player_name, roll )

    find_winner( State.AfterRoll )
  end

  local function get_roll_announcement()
    local name_with_rolls = function( player )
      if #rollers == count then return player.name end
      local roll_count = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
      return string.format( "%s%s", player.name, roll_count )
    end

    local count_str = count > 1 and string.format( "%sx", count ) or ""
    local x_rolls_win = count > 1 and string.format( ". %d top rolls win.", count ) or ""
    local ressed_by = modules.prettify_table( map( rollers, name_with_rolls ) )

    if count == #rollers then
      rolling = false
      return string.format( "%s is soft-ressed by %s.", item.link, ressed_by )
    else
      return string.format( "Roll for %s%s: (SR by %s)%s", count_str, item.link, ressed_by, x_rolls_win )
    end
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

    show( "SR", rlu.sort_rolls( rolls ) )
  end

  local function print_rolling_complete( cancelled )
    pretty_print( string.format( "Rolling for %s has %s.", item.link, cancelled and "been cancelled" or "finished" ) )
  end

  local function stop_rolling( force )
    find_winner( force and State.ManualStop or State.TimerStopped )
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

modules.SoftResRollingLogic = M
return M
