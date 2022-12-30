local M = {}

local m_slashcmdlist = {}
local m_messages = {}
local m_event_callback = nil

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

function M.raid_message( message )
  return { message = message, chat = "RAID" }
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

function M.NewLibrary( name, object )
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

function M.roll_for( item_name )
  M.run_command( "RF", M.item_link( item_name ) )
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

return M
