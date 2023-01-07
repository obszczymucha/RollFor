local M = {}

function M.new( api, softres )
  local get = softres.get

  local function get_all_players_in_my_group()
    local result = {}

    if not (api.IsInGroup() or api.IsInRaid()) then
      local myName = M.MyName()
      table.insert( result, myName )
      return result
    end

    for i = 1, 40 do
      local name = api.GetRaidRosterInfo( i )
      if name then table.insert( result, name ) end
    end

    return result
  end

  local function is_player_in_my_group( playerName )
    local players = get_all_players_in_my_group()

    for _, player in pairs( players ) do
      if string.lower( player ) == string.lower( playerName ) then return true end
    end

    return false
  end

  local function filter_absent_players( players )
    local present = {}

    for _, player in pairs( players ) do
      if is_player_in_my_group( player.matched_name ) then
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

SoftResAbsentPlayersDecorator = M
return M
