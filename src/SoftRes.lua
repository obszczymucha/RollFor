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
--
--
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding

local function decode_base64( data )
  if not data then return nil end

  data = string.gsub( data, '[^' .. b .. '=]', '' )
  return (data:gsub( '.', function( x )
    if (x == '=') then return '' end
    local r, f = '', (b:find( x ) - 1)
    for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r;
  end ):gsub( '%d%d%d?%d?%d?%d?%d?%d?', function( x )
    if (#x ~= 8) then return '' end
    local c = 0
    for i = 1, 8 do c = c + (x:sub( i, i ) == '1' and 2 ^ (8 - i) or 0) end
    return string.char( c )
  end ))
end

function M.decode( encoded_softres_data )
  local data = decode_base64( encoded_softres_data )
  if not data then return nil end

  data = libStub( "LibDeflate" ):DecompressZlib( data )
  if not data then return nil end

  data = libStub( "Json-0.1.2" ).decode( data )

  return data
end

function M.new( softres_data )
  local softres_items = {}
  local hardres_items = {}

  local function clear()
    softres_items = {}
    hardres_items = {}
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
    if not softres_items[ item_id ] then return false end

    for _, v in pairs( softres_items[ item_id ] ) do
      if v.name == player_name then return true end
    end

    return false
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
  end

  local function process_hardres_items( entries )
    if not entries then return end

    for i = 1, #entries do
      local item_id = entries[ i ].id

      add_hr( item_id )
    end
  end

  local function process_data()
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

  process_data()

  return {
    get = get,
    is_player_softressing = is_player_softressing,
    get_item_ids = get_item_ids,
    is_item_hardressed = is_item_hardressed,
    show = show,
    get_all_softres_player_names = get_all_softres_player_names
  }
end

modules.SoftRes = M
return M
