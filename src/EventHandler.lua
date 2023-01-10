local modules = LibStub( "RollFor-Modules" )
if modules.EventHandler then return end

local M = {}

function M.handle_events( origin )
  local m_first_enter_world

  --eventHandler( frame, event, ... )
  local function eventHandler( _, event, ... )
    if event == "PLAYER_LOGIN" then
      m_first_enter_world = false
    elseif event == "PLAYER_ENTERING_WORLD" then
      if not m_first_enter_world then
        origin.on_first_enter_world()
        m_first_enter_world = true
      end
    elseif event == "GROUP_FORMED" then
      origin.version_broadcast.on_joined_group()
    elseif event == "GROUP_JOINED" then
      origin.version_broadcast.on_joined_group()
    elseif event == "GROUP_LEFT" then
      origin.version_broadcast.on_left_group()
    elseif event == "CHAT_MSG_SYSTEM" then
      origin.on_chat_msg_system( ... )
    elseif event == "LOOT_READY" then
      origin.dropped_loot_announce.on_loot_ready()
    elseif event == "OPEN_MASTER_LOOT_LIST" then
      origin.master_loot.on_open_master_loot_list()
    elseif event == "LOOT_SLOT_CLEARED" then
      origin.master_loot.on_loot_slot_cleared()
    elseif event == "TRADE_SHOW" then
      origin.trade_tracker.on_trade_show()
    elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
      origin.trade_tracker.on_trade_player_item_changed( ... )
    elseif event == "TRADE_TARGET_ITEM_CHANGED" then
      origin.trade_tracker.on_trade_target_item_changed( ... )
    elseif event == "TRADE_CLOSED" then
      origin.trade_tracker.on_trade_closed()
    elseif event == "TRADE_ACCEPT_UPDATE" then
      origin.trade_tracker.on_trade_accept_update( ... )
    elseif event == "TRADE_REQUEST_CANCEL" then
      origin.trade_tracker.on_trade_request_cancel()
    end
  end

  local frame = modules.api.CreateFrame( "FRAME", "RollForFrame" )

  frame:RegisterEvent( "PLAYER_LOGIN" )
  frame:RegisterEvent( "PLAYER_ENTERING_WORLD" )
  frame:RegisterEvent( "GROUP_JOINED" )
  frame:RegisterEvent( "GROUP_LEFT" )
  frame:RegisterEvent( "GROUP_FORMED" )
  frame:RegisterEvent( "CHAT_MSG_SYSTEM" )
  frame:RegisterEvent( "LOOT_READY" )
  frame:RegisterEvent( "OPEN_MASTER_LOOT_LIST" )
  frame:RegisterEvent( "LOOT_SLOT_CLEARED" )
  frame:RegisterEvent( "TRADE_SHOW" )
  frame:RegisterEvent( "TRADE_PLAYER_ITEM_CHANGED" )
  frame:RegisterEvent( "TRADE_TARGET_ITEM_CHANGED" )
  frame:RegisterEvent( "TRADE_CLOSED" )
  frame:RegisterEvent( "TRADE_ACCEPT_UPDATE" )
  frame:RegisterEvent( "TRADE_REQUEST_CANCEL" )
  frame:SetScript( "OnEvent", eventHandler )
end

modules.EventHandler = M
return M
