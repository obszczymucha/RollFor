local modules = LibStub( "RollFor-Modules" )
if modules.SoftResAbsentPlayersDecorator then return end

local M = {}

function M.new( group_roster, softres )
  local get = softres.get

  local function filter_absent_players( players )
    local present = {}

    for _, player in pairs( players ) do
      if group_roster.is_player_in_my_group( player.name ) then
        table.insert( present, player )
      end
    end

    return present
  end

  softres.get = function( item_id )
    local softressers = get( item_id )
    return filter_absent_players( softressers )
  end

  return softres
end

modules.SoftResAbsentPlayersDecorator = M
return M
