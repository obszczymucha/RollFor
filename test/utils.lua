local M = {}

local lu = require( "luaunit" )

local m_slashcmdlist = {}
local m_messages = {}
local m_event_callback = nil
local m_tick_fn = nil
local m_repeating_tick_fn = nil
local m_rolling_item_name = nil
local m_is_master_looter = false
local m_player_name = nil
local m_target = nil

M.debug_enabled = false

function M.princess()
  return "kenny"
end

function M.debug( message )
  if not M.debug_enabled then return end
  print( string.format( "[ debug ]: %s", message ) )
end

function M.debugln( message )
  if not M.debug_enabled then return end
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
  M.modules().api.GetAddOnMetadata = function() return "2.5" end -- version
  M.modules().api.CreateFrame = function( _, frame_name )
    local frame = {
      RegisterEvent = function() end,
      SetScript = function( self, name, callback )
        if frame_name == "RollForFrame" and name == "OnEvent" then
          M.debug( "Registered OnEvent callback." )
          m_event_callback = callback
        end

        if name == "OnClick" then
          self.OnClickCallback = callback
        end

        if name == "OnHide" then
          self.OnHideCallback = callback
        end

        if name == "OnTextChanged" then
          self.OnTextChangedCallback = callback
        end
      end,
      Show = function() end,
      Hide = function( self )
        if self.OnHideCallback then self.OnHideCallback() end
      end,
      SetBackdrop = function() end,
      SetBackdropColor = function() end,
      SetBackdropBorderColor = function() end,
      SetFrameStrata = function() end,
      SetWidth = function() end,
      SetHeight = function() end,
      SetPoint = function() end,
      SetMovable = function() end,
      SetResizable = function() end,
      SetMinResize = function() end,
      SetToplevel = function() end,
      EnableMouse = function() end,
      SetNormalTexture = function() end,
      SetScrollChild = function() end,
      SetMultiLine = function() end,
      SetTextInsets = function() end,
      SetAutoFocus = function() end,
      SetFontObject = function() end,
      UpdateScrollChildRect = function() end,
      SetText = function( self, text )
        self.text = text
        if self.OnTextChangedCallback then self.OnTextChangedCallback() end
      end,
      GetText = function( self )
        return self.text
      end,
      IsVisible = function() end,
      CreateFontString = function()
        return {
          SetPoint = function() end,
          SetText = function() end,
          SetTextColor = function() end
        }
      end,
      Click = function( self )
        if self.OnClickCallback then self:OnClickCallback() end
      end
    }

    if frame_name then _G[ frame_name ] = frame end

    return frame
  end
  M.modules().api.LOOTFRAME_NUMBUTTONS = 4
  M.modules().api.StaticPopupDialogs = {}
  M.modules().api.RAID_CLASS_COLORS = {
    [ "WARRIOR" ] = {
      colorStr = "chuj"
    }
  }
  M.modules().api.ITEM_QUALITY_COLORS = {
    { hex = "asd" },
    { hex = "blue" },
    { hex = "green" },
    { hex = "purple" },
    { hex = "ass" },
    { hex = "princess" },
    { hex = "kenny" }
  }
  M.modules().api.FONT_COLOR_CODE_CLOSE = "|r"
end

function M.highlight( word )
  return string.format( "|cffff9f69%s|r", word )
end

function M.decolorize( input )
  return string.gsub( input, "|c%x%x%x%x%x%x%x%x([^|]+)|r", "%1" )
end

function M.parse_item_link( item_link )
  return string.gsub( item_link, "|c%x%x%x%x%x%x%x%x|Hitem:%d+.*|h(.*)|h|r", "%1" )
end

function M.mock_library( name, object )
  M.load_libstub()
  local result = LibStub:NewLibrary( name, 1 )
  if not result then return nil end
  if not object then return result end

  for k, v in pairs( object ) do
    result[ k ] = v
  end

  return result
end

function M.mock_api()
  M.mock_slashcmdlist()
  M.mock( "IsInGuild", false )
  M.mock( "IsInGroup", false )
  M.mock( "IsInRaid", false )
  M.mock( "UnitIsFriend", false )
  M.mock( "InCombatLockdown", false )
  M.mock( "UnitName", "Psikutas" )
  M.mock( "UnitClass", "Warrior" )
  M.mock_messages()
end

function M.modules()
  M.load_libstub()
  require( "src/modules" )
  return LibStub( "RollFor-Modules" )
end

function M.mock_slashcmdlist()
  M.modules().api.SlashCmdList = m_slashcmdlist
end

function M.mock_messages()
  m_messages = {}

  M.modules().api.SendChatMessage = function( message, chat )
    local parsed_message = M.parse_item_link( message )
    table.insert( m_messages, { message = parsed_message, chat = chat } )
  end

  M.modules().api.ChatFrame1 = {
    AddMessage = function( _, message )
      local message_without_colors = M.parse_item_link( M.decolorize( message ) )
      table.insert( m_messages, { message = message_without_colors, chat = "CONSOLE" } )
    end
  }
end

function M.get_messages()
  return m_messages
end

function M.mock( funcName, result )
  if type( result ) == "function" then
    M.modules().api[ funcName ] = result
  else
    M.modules().api[ funcName ] = function() return result end
  end
end

function M.mock_object( name, result )
  M.modules().api[ name ] = result
end

function M.run_command( command, args )
  local f = m_slashcmdlist[ command ]

  if f then
    f( args )
  else
    M.debugln( string.format( "No callback provided for command: ", command ) )
  end
end

function M.roll_for( item_name, count, item_id )
  M.run_command( "RF", string.format( "%s%s", count and string.format( "%sx", count ) or "", M.item_link( item_name, item_id ) ) )
  m_rolling_item_name = item_name
end

function M.roll_for_raw( raw_text )
  M.run_command( "RF", raw_text )
end

function M.raid_roll( item_name, item_id )
  M.run_command( "RR", M.item_link( item_name, item_id ) )
end

function M.raid_roll_raw( raw_text )
  M.run_command( "RR", raw_text )
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

function M.roll( player_name, roll, upper_bound )
  M.fire_event( "CHAT_MSG_SYSTEM", string.format( "%s rolls %d (1-%d)", player_name, roll, upper_bound or 100 ) )
end

function M.roll_os( player_name, roll )
  M.fire_event( "CHAT_MSG_SYSTEM", string.format( "%s rolls %d (1-99)", player_name, roll ) )
end

function M.mock_random_roll( player_name, roll, upper_bound )
  M.mock( "RandomRoll", function() M.roll( player_name, roll, upper_bound ) end )
end

function M.init()
  M.mock_api()
  M.fire_login_events()
  M.mock_messages()
  M.import_soft_res( nil )
  m_is_master_looter = false
end

function M.fire_login_events()
  M.fire_event( "PLAYER_LOGIN" )
  M.fire_event( "PLAYER_ENTERING_WORLD" )
end

function M.raid_leader( name )
  return function() return name, 1, nil, nil, "Warrior", nil, nil, nil, nil, nil, m_is_master_looter end
end

function M.raid_member( name )
  return function() return name, 0, nil, nil, "Warrior" end
end

function M.mock_table_function( name, values )
  M.modules().api[ name ] = function( key )
    local value = values[ key ]

    if type( value ) == "function" then
      return value()
    else
      return value
    end
  end
end

function M.item_link( name, id )
  return string.format( "|cff9d9d9d|Hitem:%s::::::::20:257::::::|h[%s]|h|r", id or "3299", name )
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

  if #players > 1 then
    local party = {
      [ "player" ] = players[ 1 ]
    }

    for i = 2, #players do
      party[ "party" .. i - 1 ] = players[ i ]
    end

    M.mock_table_function( "UnitName", party )
  end

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
  M.mock_table_function( "GetMasterLootCandidate", players )
end

M.LootQuality = {
  Poor = 0,
  Common = 1,
  Uncommon = 2,
  Rare = 3,
  Epic = 4,
  Legendary = 5
}

function M.loot_threshold( threshold )
  M.mock( "GetLootThreshold", threshold )
end

function M.mock_blizzard_loot_buttons()
  for i = 1, M.modules().api.LOOTFRAME_NUMBUTTONS do
    local name = "LootButton" .. i
    M.mock_object( name, {
      GetName = function() return name end,
      GetScript = function() end,
      SetScript = function( self, event, callback )
        if event == "OnClick" then
          self.OnClickCallback = callback
        end
      end,
      Click = function( self )
        if self.OnClickCallback then
          self:OnClickCallback()
        else
          M.debugln( string.format( "No OnClick callback provided for button: ", name ) )
        end
      end
    } )
  end
end

function M.mock_unit_name()
  M.mock_table_function( "UnitName", { [ "player" ] = m_player_name, [ "target" ] = m_target } )
end

function M.load_roll_for()
  local libStub = M.load_libstub()
  return libStub( "RollFor-2" )
end

function M.player( name )
  M.init()
  m_player_name = name
  m_target = nil
  M.mock_unit_name()
  M.mock( "IsInGroup", false )
  local rf = M.load_roll_for()

  -- TODO: Maybe awarded loot shouldn't be accessible.
  rf.awarded_loot.clear()
end

function M.master_looter( name )
  M.player( name )
  m_is_master_looter = true
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

-- Return console message first then its equivalent raid warning message.
-- This returns a function, we check for that later to do the magic.
function M.console_and_raid_warning( message )
  return function()
    return M.console_message( string.format( "RollFor: %s", message ) ), M.raid_warning( message )
  end
end

-- Helper functions.
function M.assert_messages( ... )
  local args = { ... }
  local expected = {}
  M.flatten( expected, args )
  lu.assertEquals( M.get_messages(), expected )
end

function M.tick()
  if not m_tick_fn then
    M.debug( "Tick function not set." )
    return
  end

  m_tick_fn()
  m_tick_fn = nil
end

function M.repeating_tick( times )
  if not m_repeating_tick_fn then
    M.debug( "Repeating tick function not set." )
    return
  end

  local count = times or 1

  for _ = 1, count do
    m_repeating_tick_fn()
  end
end

function M.mock_libraries()
  m_tick_fn = nil
  m_repeating_tick_fn = nil
  M.mock_wow_api()
  M.mock_library( "AceConsole-3.0" )
  M.mock_library( "AceEvent-3.0", { RegisterMessage = function() end } )
  M.mock_library( "AceTimer-3.0", {
    ScheduleTimer = function( _, f )
      m_tick_fn = f
    end,
    ScheduleRepeatingTimer = function( _, f )
      m_repeating_tick_fn = f
      return 2
    end,
    CancelTimer = function( _, timer_id )
      if timer_id == 1 then m_tick_fn = nil end
      if timer_id == 2 then m_repeating_tick_fn = nil end
    end
  } )
  M.mock_library( "AceComm-3.0", { RegisterComm = function() end, SendCommMessage = function() end } )
  M.mock_library( "AceDB-3.0", {
    New = function( _, _ )
      return {
        global = {},
        char = {}
      }
    end
  } )
end

function M.load_real_stuff()
  M.load_libstub()
  require( "settings" )
  require( "src/modules" )
  M.mock_api()
  M.mock_slashcmdlist()
  require( "src/Api" )
  require( "src/ItemUtils" )
  require( "src/RollingLogicUtils" )
  require( "src/DroppedLoot" )
  require( "src/DroppedLootAnnounce" )
  require( "src/TradeTracker" )
  require( "src/SoftRes" )
  require( "src/SoftResGui" )
  require( "src/AwardedLoot" )
  require( "src/SoftResAwardedLootDecorator" )
  require( "src/SoftResPresentPlayersDecorator" )
  require( "src/SoftResAbsentPlayersDecorator" )
  require( "src/SoftResMatchedNameDecorator" )
  require( "src/GroupRoster" )
  require( "src/NameAutoMatcher" )
  require( "src/NameManualMatcher" )
  require( "src/NameMatchReport" )
  require( "src/EventHandler" )
  require( "src/VersionBroadcast" )
  require( "src/MasterLoot" )
  require( "src/SoftResCheck" )
  require( "src/NonSoftResRollingLogic" )
  require( "src/SoftResRollingLogic" )
  require( "src/TieRollingLogic" )
  require( "src/RaidRollRollingLogic" )
  require( "src/MasterLootTracker" )
  require( "src/MasterLootFrame" )
  require( "src/UsagePrinter" )
  require( "Libs/LibDeflate/LibDeflate" )
  require( "src/Json" )
  require( "main" )
end

function M.rolling_finished()
  return M.console_message( string.format( "RollFor: Rolling for [%s] has finished.", m_rolling_item_name ) )
end

local function make_loot_slot_links( items )
  local result = {}

  for i = 1, #items do
    local item = items[ i ]
    table.insert( result, M.item_link( item.name, item.id ) )
  end

  return result
end

local function make_loot_slot_info( items )
  local result = {}

  for i = 1, #items do
    local item = items[ i ]
    table.insert( result, function() return nil, nil, nil, item.quality or 4 end )
  end

  return result
end

function M.loot( ... )
  local items = { ... }
  local count = items and #items or 0
  M.mock( "GetNumLootItems", count )

  if count > 0 then
    M.mock( "UnitGUID", items[ 1 ].source_id )
    M.mock_table_function( "GetLootSlotLink", make_loot_slot_links( items ) )
    M.mock_table_function( "GetLootSlotInfo", make_loot_slot_info( items ) )
  end

  M.fire_event( "LOOT_OPENED" )
end

function M.item( name, id, quality )
  return { name = name, id = id, source_id = 123, quality = quality }
end

function M.targetting_enemy( name )
  m_target = name
  M.mock_unit_name()
  M.mock( "UnitIsFriend", false )
end

function M.targetting_player( name )
  m_target = name
  M.mock_unit_name()
  M.mock( "UnitIsFriend", true )
end

function M.import_soft_res( data )
  local rf = M.load_roll_for()
  rf.import_softres_data( data )
end

local function find_soft_res_entry( softreserves, player )
  for i = 1, #softreserves do
    if softreserves[ i ].name == player then
      return softreserves[ i ]
    end
  end

  return nil
end

function M.create_softres_data( ... )
  local items = { ... }
  local hardreserves = {}
  local softreserves = {}

  for i = 1, #items do
    local item = items[ i ]

    if item.soft_res then
      local entry = find_soft_res_entry( softreserves, item.player ) or {}

      if not entry.name then
        table.insert( softreserves, entry )
      end

      entry.name = item.player
      entry.items = entry.items or {}
      table.insert( entry.items, { id = item.item_id } )
    else
      table.insert( hardreserves, { id = item.item_id } )
    end
  end

  local data = {
    metadata = {
      id = 123
    },
    hardreserves = hardreserves,
    softreserves = softreserves
  }

  return data
end

function M.soft_res( ... )
  M.import_soft_res( M.create_softres_data( ... ) )
end

function M.soft_res_item( player, item_id )
  return { soft_res = true, player = player, item_id = item_id }
end

function M.hard_res_item( item_id )
  return { soft_res = false, item_id = item_id }
end

function M.award( player, item_name, item_id )
  local rf = M.load_roll_for()
  rf.award_item( player, item_id, item_name, M.item_link( item_name, item_id ) )
end

function M.epic_threshold()
  M.loot_quality_threshold( 4 )
end

function M.loot_quality_threshold( quality )
  RollFor.settings.announce_loot_quality_threshold = quality
end

function M.load_libstub()
  ---@diagnostic disable-next-line: lowercase-global
  strmatch = string.match
  require( "LibStub" )

  return LibStub
end

function M.trade_with( recipient, trade_tracker )
  RollFor.settings.trade_tracker_debug = true
  M.mock_object( "TradeFrameRecipientNameText", { GetText = function() return recipient end } )
  M.mock_table_function( "GetTradePlayerItemInfo", { [ "1" ] = nil } )
  M.mock_table_function( "GetTradePlayerItemLink", { [ "1" ] = nil } )

  if trade_tracker then
    trade_tracker.on_trade_show()
  else
    M.fire_event( "TRADE_SHOW" )
  end
end

function M.cancel_trade( trade_tracker )
  RollFor.settings.trade_tracker_debug = true

  if trade_tracker then
    trade_tracker.on_trade_accept_update( 0 )
    trade_tracker.on_trade_closed()
  else
    M.fire_event( "TRADE_ACCEPT_UPDATE", 0 )
    M.fire_event( "TRADE_CLOSED" )
  end
end

function M.trade_cancelled_by_recipient( trade_tracker )
  RollFor.settings.trade_tracker_debug = true
  if trade_tracker then
    trade_tracker.on_trade_request_cancel()
  else
    M.fire_event( "TRADE_REQUEST_CANCEL" )
    M.fire_event( "TRADE_CLOSED" )
  end
end

function M.trade_complete( trade_tracker )
  RollFor.settings.trade_tracker_debug = true

  if trade_tracker then
    trade_tracker.on_trade_accept_update( 1, 1 )
    trade_tracker.on_trade_closed()
  else
    M.fire_event( "TRADE_ACCEPT_UPDATE", 1, 1 )
    M.fire_event( "TRADE_CLOSED" )
  end
end

function M.map( t, f )
  if type( f ) ~= "function" then return t end
  local result = {}

  for _, v in pairs( t ) do
    local value = f( v )
    table.insert( result, value )
  end

  return result
end

function M.trade_items( trade_tracker, ... )
  local items = { ... }
  M.mock_table_function( "GetTradePlayerItemInfo", M.map( items, function( v ) return function() return _, _, v.quantity end end ) )
  M.mock_table_function( "GetTradePlayerItemLink", M.map( items, function( v ) return function() return v.item_link end end ) )

  for i = 1, #items do
    if trade_tracker then
      trade_tracker.on_trade_player_item_changed( i )
    else
      M.fire_event( "TRADE_PLAYER_ITEM_CHANGED", i )
    end
  end
end

function M.recipient_trades_items( trade_tracker, ... )
  local items = { ... }
  M.mock_table_function( "GetTradeTargetItemInfo", M.map( items, function( v ) return function() return _, _, v.quantity end end ) )
  M.mock_table_function( "GetTradeTargetItemLink", M.map( items, function( v ) return function() return v.item_link end end ) )

  for i = 1, #items do
    if trade_tracker then
      trade_tracker.on_trade_target_item_changed( i )
    else
      M.fire_event( "TRADE_TARGET_ITEM_CHANGED", i )
    end
  end
end

local function get_player_frame_from_master_looter_frame( player_name )
  for i = 1, 40 do
    local button = _G[ "RollForLootFrameButton" .. i ]

    if button and button.player and button.player.name == player_name then
      return button
    end
  end
end

function M.master_loot( item_name, player_name )
  M.mock( "IsModifiedClick", false )
  M.mock( "CloseDropDownMenus", function() end )
  local button = _G[ "LootButton1" ]
  M.mock_object( "LootButton1Text", {
    GetText = function() return item_name end
  } )
  button.hasItem = true
  button.quality = M.LootQuality.Epic
  button.slot = 1
  M.mock_object( "LootFrame", {} )
  M.mock( "StaticPopup_Show", function() end )
  button:Click()
  local player_frame = get_player_frame_from_master_looter_frame( player_name )
  player_frame:Click()
end

function M.mock_softres_gui()
end

function M.confirm_master_looting( player_name )
  M.mock( "GiveMasterLoot", function() end )
  M.modules().api.StaticPopupDialogs[ "ROLLFOR_MASTER_LOOT_CONFIRMATION_DIALOG" ].OnAccept( { name = player_name, value = 1 } )
  M.fire_event( "LOOT_SLOT_CLEARED", 1 )
end

function M.cancel_master_looting()
  M.modules().api.StaticPopup1Button2.fire_event( "OnClick" )
end

function M.clear_dropped_items_db()
  local rollfor = M.load_roll_for()
  rollfor.db.char.dropped_items = {}
end

function M.read_file( file_name )
  local file = io.open( file_name, "r" )
  if not file then return nil end

  local content = file:read( "*a" )
  file:close()

  return content
end

function M.import_softres_via_gui( fixture_name )
  local sr_data = M.read_file( fixture_name )
  local sr_frame = _G[ "RollForSoftResLootFrame" ]
  sr_frame.editbox:SetText( sr_data )
  sr_frame:Hide()
end

return M
