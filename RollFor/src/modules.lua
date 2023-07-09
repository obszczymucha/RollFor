---@diagnostic disable: undefined-global, undefined-field
local M = LibStub:NewLibrary( "RollFor-Modules", 1 )
if not M then return end

M.api = _G
M.lua = {
  format = format,
  time = time,
  strmatch = strmatch
}

M.colors = {
  highlight = function( text )
    return string.format( "|cffff9f69%s|r", text )
  end,
  blue = function( text )
    return string.format( "|cff209ff9%s|r", text )
  end,
  white = function( text )
    return string.format( "|cffffffff%s|r", text )
  end,
  red = function( text )
    return string.format( "|cffff2f2f%s|r", text )
  end,
  orange = function( text )
    return string.format( "|cffff8f2f%s|r", text )
  end,
  grey = function( text )
    return string.format( "|cff9f9f9f%s|r", text )
  end,
  green = function( text )
    return string.format( "|cff2fff5f%s|r", text )
  end
}

M.colors.softres = M.colors.blue
M.colors.name_matcher = M.colors.blue
M.colors.hl = M.colors.highlight

function M.pretty_print( message, color_fn )
  local c = color_fn and type( color_fn ) == "function" and color_fn or color_fn and type( color_fn ) == "string" and M.colors[ color_fn ] or M.colors.blue
  M.api.ChatFrame1:AddMessage( string.format( "%s: %s", c( "RollFor" ), message ) )
end

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
  if M.api.IsInRaid() then
    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, _, isMasterLooter = M.api.GetRaidRosterInfo( i )

      if name and name == M.MyName() then
        return isMasterLooter
      end
    end

    return false
  end

  return M.api.GetLootMethod() == "master" and M.api.UnitIsPartyLeader( "player" )
end

function M.MyName()
  return M.api.UnitName( "player" )
end

function M.get_group_chat_type()
  return M.api.IsInRaid() and "RAID" or "PARTY"
end

function M.decolorize( input )
  return input and string.gsub( input, "|c%x%x%x%x%x%x%x%x([^|]+)|r", "%1" )
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

function M.filter( t, f, extract_field )
  if not t then return nil end
  if type( f ) ~= "function" then return t end

  local result = {}

  for i = 1, #t do
    local v = t[ i ]
    local value = type( v ) == "table" and extract_field and v[ extract_field ] or v
    if f( value ) then table.insert( result, v ) end
  end

  return result
end

function M.take( t, n )
  if n == 0 then return {} end

  local result = {}

  for i = 1, #t do
    if i > n then return result end
    table.insert( result, t[ i ] )
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

function M.map( t, f, extract_field )
  if type( f ) ~= "function" then return t end

  local result = {}

  for k, v in pairs( t ) do
    if type( v ) == "table" and extract_field then
      local mapped_result = f( v[ extract_field ] )
      local value = M.clone( v )
      value[ extract_field ] = mapped_result
      result[ k ] = value
    else
      result[ k ] = f( v )
    end
  end

  return result
end

function M.negate( f )
  return function( v )
    return not f( v )
  end
end

function M.no_nil( f )
  return function( v )
    return f( v ) or v
  end
end

function M.merge( result, next, ... )
  if type( result ) ~= "table" then return {} end
  if type( next ) ~= "table" then return result end

  for i = 1, #next do
    table.insert( result, next[ i ] )
  end

  return M.merge( result, ... )
end

function M.keys( t )
  if type( t ) ~= "table" then return {} end

  local result = {}

  for k, _ in pairs( t ) do
    table.insert( result, k )
  end

  return result
end

function M.find( value, t, extract_field )
  if type( t ) ~= "table" or #t == 0 then return nil end

  for _, v in pairs( t ) do
    local val = extract_field and v[ extract_field ] or v
    if val == value then return v end
  end

  return nil
end

function M.idempotent_hookscript( frame, event, callback )
  if not frame.RollForHookScript then
    frame.RollForHookScript = frame.HookScript

    frame.HookScript = function( self, _event, f )
      if _event:find( "RollForIdempotent", 1, true ) == 1 then
        if not frame[ _event ] then
          local real_event = _event:gsub( "RollForIdempotent", "" )
          frame.RollForHookScript( self, real_event, f )
          frame[ _event ] = true
        end
      else
        frame.RollForHookScript( self, _event, f )
      end
    end
  end

  frame:HookScript( "RollForIdempotent" .. event, callback )
end

function M.colorize_item_by_quality( item_name, item_quality )
  local color = M.api.ITEM_QUALITY_COLORS[ item_quality ].hex
  return color .. item_name .. M.api.FONT_COLOR_CODE_CLOSE
end

function M.colorize_player_by_class( name, class )
  if not class then return name end
  local color = M.api.RAID_CLASS_COLORS[ class:upper() ].colorStr
  return "|c" .. color .. name .. M.api.FONT_COLOR_CODE_CLOSE
end

RollFor.pretty_print = M.pretty_print
return M
