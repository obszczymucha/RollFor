---@diagnostic disable: undefined-global, undefined-field
local M = LibStub:NewLibrary( "RollFor-Modules", 1 )
if not M then return end

M.api = _G
M.lua = {
  format = format,
  time = time,
  strmatch = strmatch
}

function M.pretty_print( message ) M.api.ChatFrame1:AddMessage( string.format( "|cff209ff9RollFor|r: %s", message ) ) end

function M.count_elements( t, f )
  local result = 0

  for _, v in pairs( t ) do
    if f and f( v ) or not f then
      result = result + 1
    end
  end

  return result
end

function M.clone( t )
  local result = {}

  if not t then return result end

  for k, v in pairs( t ) do
    result[ k ] = v
  end

  return result
end

function M.is_player_master_looter()
  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, _, isMasterLooter = M.api.GetRaidRosterInfo( i )

    if name and name == M.MyName() then
      return isMasterLooter
    end
  end

  return false
end

function M.MyName()
  return M.api.UnitName( "player" )
end

function M.get_group_chat_type()
  return M.api.IsInRaid() and "RAID" or "PARTY"
end

function M.decolorize( input )
  return string.gsub( input, "|c%x%x%x%x%x%x%x%x([^|]+)|r", "%1" )
end

function M.dump( o )
  local entries = 0

  if type( o ) == 'table' then
    local s = '{'
    for k, v in pairs( o ) do
      if (entries == 0) then s = s .. " " end
      if type( k ) ~= 'number' then k = '"' .. k .. '"' end
      if (entries > 0) then s = s .. ", " end
      s = s .. '[' .. k .. '] = ' .. M.dump( v )
      entries = entries + 1
    end

    if (entries > 0) then s = s .. " " end
    return s .. '}'
  else
    return tostring( o )
  end
end

function M.fetch_item_link( item_id )
  local _, itemLink = M.api.GetItemInfo( tonumber( item_id ) )
  return itemLink
end

function M.prettify_table( t, f )
  local result = ""

  if #t == 0 then
    return result
  end

  if #t == 1 then
    return (f and f( t[ 1 ] ) or t[ 1 ])
  end

  for i = 1, #t - 1 do
    if result ~= "" then
      result = result .. ", "
    end

    result = result .. (f and f( t[ i ] ) or t[ i ])
  end

  result = result .. " and " .. (f and f( t[ #t ] ) or t[ #t ])
  return result
end

function M.filter( t, f )
  if not t then return nil end
  if type( f ) ~= "function" then return t end

  local result = {}

  for k, v in pairs( t ) do
    if f( k, v ) then result[ k ] = v end
  end

  return result
end

function M.my_raid_rank()
  for i = 1, 40 do
    local name, rank = M.api.GetRaidRosterInfo( i )

    if name and name == M.MyName() then
      return rank
    end
  end

  return 0
end

function M.table_contains_value( t, value, f )
  if not t then return false end

  for _, v in pairs( t ) do
    local val = type( f ) == "function" and f( v ) or v
    if val == value then return true end
  end

  return false
end

return M
