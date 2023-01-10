local modules = LibStub( "RollFor-Modules" )
if modules.SoftResAbsentPlayersDecorator then return end

local M = {}

function M.new( group_roster, softres )
  local function filter_absent_players( players )
    local present = {}

    for _, player in pairs( players ) do
      if group_roster.is_player_in_my_group( player.name ) then
        table.insert( present, player )
      end
    end

    return present
  end

  local function get( item_id )
    local softressers = softres.get( item_id )
    return filter_absent_players( softressers )
  end

  local decorator = modules.clone( softres )
  decorator.get = get

  return decorator
end

modules.SoftResAbsentPlayersDecorator = M
return M
