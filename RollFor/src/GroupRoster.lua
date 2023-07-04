local modules = LibStub( "RollFor-Modules" )
if modules.GroupRoster then return end

local M = {}

function M.new( api )
  local function my_name()
    return api().UnitName( "player" )
  end

  local function get_all_players_in_my_group()
    local result = {}

    if not api().IsInGroup() then
      local name = my_name() -- This breaks in game if we dont assign it to the variable.
      table.insert( result, name )
      return result
    end

    if api().IsInRaid() then
      for i = 1, 40 do
        local player_name = api().GetRaidRosterInfo( i )
        if player_name then table.insert( result, player_name ) end
      end
    else
      local name = my_name()
      table.insert( result, name )

      for i = 1, 4 do
        local player_name = api().UnitName( "party" .. i )
        if player_name then table.insert( result, player_name ) end
      end
    end

    return result
  end

  local function is_player_in_my_group( player_name )
    local player_names = get_all_players_in_my_group()

    for _, player in pairs( player_names ) do
      if string.lower( player ) == string.lower( player_name ) then return true end
    end

    return false
  end

  local function am_i_in_group()
    return api().IsInGroup()
  end

  local function am_i_in_party()
    return api().IsInGroup() and not api().IsInRaid()
  end

  local function am_i_in_raid()
    return api().IsInGroup() and api().IsInRaid()
  end

  return {
    my_name = my_name,
    get_all_players_in_my_group = get_all_players_in_my_group,
    is_player_in_my_group = is_player_in_my_group,
    am_i_in_group = am_i_in_group,
    am_i_in_party = am_i_in_party,
    am_i_in_raid = am_i_in_raid
  }
end

modules.GroupRoster = M
return M
