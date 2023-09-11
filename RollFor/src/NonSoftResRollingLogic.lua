local modules = LibStub( "RollFor-Modules" )
if modules.NonSoftResRollingLogic then return end

local M = {}
local map = modules.map
local count_elements = modules.count_elements
local pretty_print = modules.pretty_print
local merge = modules.merge
local take = modules.take
local rlu = modules.RollingLogicUtils

function M.new( announce, ace_timer, group_roster, item, count, info, seconds, on_rolling_finished )
  local mainspec_rollers, mainspec_rolls = rlu.all_present_players( group_roster ), {}
  local offspec_rollers, offspec_rolls = rlu.copy_rollers( mainspec_rollers ), {}
  local rolling = false
  local seconds_left = seconds
  local timer

  local function have_all_rolls_been_exhausted()
    local mainspec_roll_count = count_elements( mainspec_rolls )
    local offspec_roll_count = count_elements( offspec_rolls )
    local total_roll_count = mainspec_roll_count + offspec_roll_count

    if count == #offspec_rollers and rlu.have_all_players_rolled( offspec_rollers ) or
        #mainspec_rollers == count and total_roll_count == #mainspec_rollers then
      return true
    end

    return rlu.have_all_players_rolled( mainspec_rollers )
  end

  local function stop_listening()
    rolling = false

    if timer then
      ace_timer:CancelTimer( timer )
      timer = nil
    end
  end

  local function find_winner()
    stop_listening()

    local mainspec_roll_count = count_elements( mainspec_rolls )
    local offspec_roll_count = count_elements( offspec_rolls )

    if mainspec_roll_count == 0 and offspec_roll_count == 0 then
      on_rolling_finished( item, count, {} )
      return
    end

    local sorted_mainspec_rolls = rlu.sort_rolls( mainspec_rolls )
    local sorted_offspec_rolls = map( rlu.sort_rolls( offspec_rolls ), function( v )
      v.offspec = true; return v
    end )
    local winners = take( merge( {}, sorted_mainspec_rolls, sorted_offspec_rolls ), count )

    on_rolling_finished( item, count, winners )
  end

  local function on_roll( player_name, roll, min, max )
    if not rolling or min ~= 1 or (max ~= 99 and max ~= 100) then return end
    local mainspec_roll = max == 100

    if not rlu.has_rolls_left( mainspec_roll and mainspec_rollers or offspec_rollers, player_name ) then
      pretty_print( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player_name, roll ) )
      return
    end

    rlu.subtract_roll( mainspec_roll and mainspec_rollers or offspec_rollers, player_name )
    rlu.record_roll( mainspec_roll and mainspec_rolls or offspec_rolls, player_name, roll )

    if have_all_rolls_been_exhausted() then find_winner() end
  end

  local function stop_accepting_rolls()
    find_winner()
  end

  local function on_timer()
    seconds_left = seconds_left - 1

    if seconds_left <= 0 then
      stop_accepting_rolls()
    elseif seconds_left == 3 then
      announce( "Stopping rolls in 3" )
    elseif seconds_left < 3 then
      announce( seconds_left )
    end
  end

  local function accept_rolls()
    rolling = true
    timer = ace_timer:ScheduleRepeatingTimer( on_timer, 1.7 )
  end

  local function announce_rolling()
    local count_str = count > 1 and string.format( "%sx", count ) or ""
    local info_str = info and info ~= "" and string.format( " %s", info ) or " /roll (MS) or /roll 99 (OS)"
    local x_rolls_win = count > 1 and string.format( ". %d top rolls win.", count ) or ""

    announce( string.format( "Roll for %s%s:%s%s", count_str, item.link, info_str, x_rolls_win ), true )
    accept_rolls()
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

    show( "Mainspec", rlu.sort_rolls( mainspec_rolls ) )
    show( "Offspec", rlu.sort_rolls( offspec_rolls ) )
  end

  local function print_rolling_complete( cancelled )
    pretty_print( string.format( "Rolling for %s has %s.", item.link, cancelled and "been cancelled" or "finished" ) )
  end

  local function cancel_rolling()
    stop_listening()
    print_rolling_complete( true )
  end

  local function is_rolling()
    return rolling
  end

  return {
    announce_rolling = announce_rolling,
    on_roll = on_roll,
    show_sorted_rolls = show_sorted_rolls,
    stop_accepting_rolls = stop_accepting_rolls,
    cancel_rolling = cancel_rolling,
    is_rolling = is_rolling
  }
end

modules.NonSoftResRollingLogic = M
return M
