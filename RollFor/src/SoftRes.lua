local modules = LibStub( "RollFor-Modules" )
if modules.SoftRes then return end

local M = {}

---@diagnostic disable-next-line: undefined-global
local libStub = LibStub

--function M:new()
--local o = {}
--setmetatable( o, self )
--self.__index = self

--return o
--end

function M.new( db )
  local softres_items = {}
  local hardres_items = {}

  local function persist( data )
    db.char.softres_data = data
  end

  function M.decode( encoded_softres_data )
    if not encoded_softres_data then return nil end

    local data = modules.decode_base64( encoded_softres_data )

    if not data then
      modules.pretty_print( "Couldn't decode softres data!", modules.colors.red )
      persist( nil )
      return nil
    end

    data = libStub( "LibDeflate" ):DecompressZlib( data )

    if not data then
      modules.pretty_print( "Couldn't decompress softres data!", modules.colors.red )
      persist( nil )
      return nil
    end


    data = libStub( "Json-0.1.2" ).decode( data )
    persist( encoded_softres_data )

    return data
  end

  local function clear( report )
    if modules.count_elements( softres_items ) == 0 and modules.count_elements( hardres_items ) == 0 then return end
    softres_items = {}
    hardres_items = {}
    persist( nil )
    if report then modules.pretty_print( "Cleared soft-res data." ) end
  end

  local function add( item_id, player_name )
    softres_items[ item_id ] = softres_items[ item_id ] or {}
    local items = softres_items[ item_id ]

    for _, value in pairs( items ) do
      if value.name == player_name then
        value.rolls = value.rolls + 1
        return
      end
    end

    table.insert( items, { name = player_name, rolls = 1 } )
  end

  local function add_hr( item_id )
    hardres_items[ item_id ] = hardres_items[ item_id ] or 1
  end

  local function get( item_id )
    return softres_items[ item_id ] or {}
  end

  local function is_player_softressing( player_name, item_id )
    if item_id and not softres_items[ item_id ] then return false end

    if item_id then
      for _, player in pairs( softres_items[ item_id ] ) do
        if player.name == player_name then return true end
      end
    else
      for _, players in pairs( softres_items ) do
        for _, player in pairs( players ) do
          if player.name == player_name then return true end
        end
      end
    end

    return false
  end

  local function sort_softres_items()
    for _, players in pairs( softres_items ) do
      table.sort( players, function( left, right ) return left.name < right.name end )
    end
  end

  local function process_softres_items( entries )
    if not entries then return end

    for i = 1, #entries do
      local entry = entries[ i ]
      local items = entry.items

      for j = 1, #items do
        local item_id = items[ j ].id

        add( item_id, entry.name )
      end
    end

    sort_softres_items()
  end

  local function process_hardres_items( entries )
    if not entries then return end

    for i = 1, #entries do
      local item_id = entries[ i ].id

      add_hr( item_id )
    end
  end

  local function import( softres_data )
    clear()
    if not softres_data then return end
    process_softres_items( softres_data.softreserves )
    process_hardres_items( softres_data.hardreserves )
  end

  local function get_item_ids()
    local result = {}

    for k, _ in pairs( softres_items ) do
      table.insert( result, k )
    end

    return result
  end

  local function is_item_hardressed( item_id )
    return hardres_items[ item_id ] and hardres_items[ item_id ] == 1 or false
  end

  local function dump( o )
    local entries = 0

    if type( o ) == 'table' then
      local s = '{'
      for k, v in pairs( o ) do
        if (entries == 0) then s = s .. " " end
        if type( k ) ~= 'number' then k = '"' .. k .. '"' end
        if (entries > 0) then s = s .. ", " end
        s = s .. '[' .. k .. '] = ' .. dump( v )
        entries = entries + 1
      end

      if (entries > 0) then s = s .. " " end
      return s .. '}'
    else
      return tostring( o )
    end
  end

  local function show()
    print( dump( softres_items ) )
  end

  local function get_all_softres_player_names()
    local softres_player_names = {}

    for _, softres_players in pairs( softres_items ) do
      for _, player in pairs( softres_players ) do
        softres_player_names[ player.name ] = 1
      end
    end

    local result = {}

    for player_name, _ in pairs( softres_player_names ) do
      table.insert( result, player_name )
    end

    return result
  end

  return {
    get = get,
    is_player_softressing = is_player_softressing,
    get_item_ids = get_item_ids,
    is_item_hardressed = is_item_hardressed,
    show = show,
    get_all_softres_player_names = get_all_softres_player_names,
    import = import,
    clear = clear
  }
end

modules.SoftRes = M
return M
