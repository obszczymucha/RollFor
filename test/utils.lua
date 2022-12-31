local M = {}

local lu = require( "luaunit" )

local m_slashcmdlist = {}
local m_messages = {}
local m_event_callback = nil
local m_tick_fn = nil

function M.princess()
  return "kenny"
end

function M.debug( message )
  print( string.format( "[ debug ]: %s", message ) )
end

function M.lndebug( message )
  print( "\n" )
  M.debug( message )
end

function M.party_message( message )
  return { message = message, chat = "PARTY" }
end

function M.raid_message( ... )
  local args = { ... }

  local result = {}

  for i = 1, #args do
    table.insert( result, { message = args[ i ], chat = "RAID" } )
  end

  ---@diagnostic disable-next-line: deprecated
  return function() return table.unpack( result ) end
end

function M.raid_warning( message )
  return { message = message, chat = "RAID_WARNING" }
end

function M.console_message( message )
  return { message = message, chat = "CONSOLE" }
end

function M.mock_wow_api()
  ---@diagnostic disable-next-line: lowercase-global
  strmatch = string.match
  CreateFrame = function( _, frameName )
    print( string.format( "[ CreateFrame ]: %s", frameName ) )

    return {
      RegisterEvent = function() end,
      SetScript = function( _, name, callback )
        if frameName == "ModUiFrame" and name == "OnEvent" then
          M.debug( "Registered ModUi callback." )
          m_event_callback = callback
        end
      end
    }
  end
end

function M.replace_colors( input )
  return string.gsub( input, "|c%x%x%x%x%x%x%x%x([^|]+)|r", "%1" )
end

function M.parse_item_link( item_link )
  return string.gsub( item_link, "|c%x%x%x%x%x%x%x%x|Hitem:%d+::::::::%d+:%d+::::::|h(.*)|h|r", "%1" )
end

function M.mock_library( name, object )
  require( "LibStub" )
  local result = LibStub:NewLibrary( name, 1 )
  if not result then return nil end
  if not object then return result end

  for k, v in pairs( object ) do
    result[ k ] = v
  end

  return result
end

local function facade()
  require( "LibStub" )
  return LibStub( "ModUiFacade-1.0" )
end

function M.mock_facade()
  M.mock( "IsInGuild", false )
  M.mock( "IsInGroup", false )
  M.mock( "IsInRaid", false )
  M.mock_messages()
end

function M.mock_slashcmdlist()
  facade().api.SlashCmdList = m_slashcmdlist
end

function M.mock_messages()
  m_messages = {}

  facade().api.SendChatMessage = function( message, chat )
    local parsed_message = M.parse_item_link( message )
    table.insert( m_messages, { message = parsed_message, chat = chat } )
  end

  facade().api.ChatFrame1 = {
    AddMessage = function( _, message )
      local message_without_colors = M.parse_item_link( M.replace_colors( message ) )
      table.insert( m_messages, { message = message_without_colors, chat = "CONSOLE" } )
    end
  }
end

function M.get_messages()
  return m_messages
end

function M.mock( funcName, result )
  if type( result ) == "function" then
    facade().api[ funcName ] = result
  else
    facade().api[ funcName ] = function() return result end
  end
end

function M.run_command( command, args )
  local f = m_slashcmdlist[ command ]

  if f then
    f( args )
  else
    M.lndebug( string.format( "No callback provided for command: ", command ) )
  end
end

function M.roll_for( item_name, count )
  M.run_command( "RF", string.format( "%s%s", count or "", M.item_link( item_name ) ) )
end

function M.roll_for_raw( raw_text )
  M.run_command( "RF", raw_text )
end

function M.cancel_rolling()
  M.run_command( "CR" )
end

function M.finish_rolling()
  M.run_command( "FR" )
end

function M.fire_event( name, ... )
  if not m_event_callback then
    print( "No event callback!" )
    return
  end

  m_event_callback( nil, name, ... )
end

function M.roll( player_name, roll )
  M.fire_event( "CHAT_MSG_SYSTEM", string.format( "%s rolls %d (1-100)", player_name, roll ) )
end

function M.roll_os( player_name, roll )
  M.fire_event( "CHAT_MSG_SYSTEM", string.format( "%s rolls %d (1-99)", player_name, roll ) )
end

function M.init()
  M.mock_facade()
  M.fire_login_events()
  M.mock_messages()
end

function M.fire_login_events()
  M.fire_event( "PLAYER_LOGIN" )
  M.fire_event( "PLAYER_ENTERING_WORLD" )
end

function M.raid_leader( name )
  return function() return name, 1 end
end

function M.raid_member( name )
  return function() return name, 0 end
end

function M.mock_table_function( name, values )
  facade().api[ name ] = function( key )
    local value = values[ key ]
    if type( value ) == "function" then
      return value()
    else
      return value
    end
  end
end

function M.item_link( name )
  return string.format( "|cff9d9d9d|Hitem:3299::::::::20:257::::::|h[%s]|h|r", name )
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

function M.flatten( target, source )
  if type( target ) ~= "table" then return end

  for i = 1, #source do
    local value = source[ i ]

    if type( value ) == "function" then
      local args = { value() }
      M.flatten( target, args )
    else
      table.insert( target, value )
    end
  end
end

function M.is_in_party( ... )
  local players = { ... }
  M.mock( "IsInGroup", true )
  M.mock( "IsInRaid", false )
  M.mock_table_function( "GetRaidRosterInfo", players )
end

function M.add_normal_raider_ranks( players )
  local result = {}

  for i = 1, #players do
    local value = players[ i ]

    if type( value ) == "string" then
      table.insert( result, M.raid_member( value ) )
    else
      table.insert( result, value )
    end
  end

  return result
end

function M.is_in_raid( ... )
  local players = M.add_normal_raider_ranks( { ... } )
  M.mock( "IsInGroup", true )
  M.mock( "IsInRaid", true )
  M.mock_table_function( "GetRaidRosterInfo", players )
end

function M.player( name )
  M.init()
  M.mock_table_function( "UnitName", { [ "player" ] = name } )
  M.mock( "IsInGroup", false )
end

function M.rolling_not_in_progress()
  return M.console_message( "RollFor: Rolling not in progress." )
end

-- Return console message first then its equivalent raid message.
-- This returns a function, we check for that later to do the magic.
function M.console_and_raid_message( message )
  return function()
    return M.console_message( string.format( "RollFor: %s", message ) ), M.raid_message( message )
  end
end

-- Helper functions.
function M.assert_messages( ... )
  local args = { ... }
  local expected = {}
  M.flatten( expected, args )
  lu.assertEquals( M.get_messages(), expected )
end

function M.tick( times )
  if not m_tick_fn then
    M.debug( "Tick function not set." )
    return
  end

  local count = times or 1

  for _ = 1, count do
    m_tick_fn()
  end
end

function M.mock_libraries()
  m_tick_fn = nil
  M.mock_wow_api()
  M.mock_library( "AceConsole-3.0" )
  M.mock_library( "AceEvent-3.0", { RegisterMessage = function() end } )
  M.mock_library( "AceTimer-3.0", {
    ScheduleRepeatingTimer = function( _, f )
      m_tick_fn = f
      return 1
    end,
    CancelTimer = function() m_tick_fn = nil end,
    ScheduleTimer = function( _, f ) f() end
  } )
  M.mock_library( "AceComm-3.0", { RegisterComm = function() end, SendCommMessage = function() end } )
  M.mock_library( "AceGUI-3.0" )
  M.mock_library( "AceDB-3.0", { New = function( _, name ) _G[ name ] = {} end } )
end

function M.load_real_stuff()
  require( "LibStub" )
  require( "ModUi/facade" )
  M.mock_facade()
  M.mock_slashcmdlist()
  require( "ModUi" )
  require( "ModUi/utils" )
  require( "RollFor" )
end

return M
