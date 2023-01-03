local ModUi = LibStub:GetLibrary( "ModUi-1.0", 4 )
local M = ModUi:NewModule( "TradeTracker" )

local api = ModUi.facade.api

local m_trading = false
local m_items_giving = {}
local m_items_receiving = {}
local m_player_accepted = false

local function on_trade_show()
  if RollFor.settings.tradeTrackerDebug then
    M:PrettyPrint( "Trade opened." )
  end

  m_trading = true
  m_items_giving = {}
  m_items_receiving = {}
  m_player_accepted = false
end

local function on_trade_player_item_changed( slot )
  local _, _, quantity = api.GetTradePlayerItemInfo( slot )
  local item_link = api.GetTradePlayerItemLink( slot )

  if quantity and item_link then
    m_items_giving[ slot ] = { quantity = quantity, item_link = item_link }
  else
    m_items_giving[ slot ] = nil
  end
end

local function on_trade_target_item_changed( slot )
  local _, _, quantity = api.GetTradeTargetItemInfo( slot )
  local item_link = api.GetTradeTargetItemLink( slot )

  if quantity and item_link then
    m_items_receiving[ slot ] = { quantity = quantity, item_link = item_link }
  else
    m_items_receiving[ slot ] = nil
  end
end

local function on_trade_closed()
  if not m_trading then return end
  m_trading = false

  if not RollFor.settings.tradeTrackerDebug then return end

  if m_player_accepted then
    M:PrettyPrint( "Trade complete." )
    M:PrettyPrint( string.format( "Given: %s", M:dump( m_items_giving ) ) )
    M:PrettyPrint( string.format( "Received: %s", M:dump( m_items_receiving ) ) )
  else
    M:PrettyPrint( "Trade cancelled by you." )
  end
end

local function on_trade_accept_update( player )
  m_player_accepted = player == 1
end

local function on_trade_request_cancel()
  if not m_trading then return end
  m_trading = false

  if RollFor.settings.tradeTrackerDebug then
    M:PrettyPrint( "Trade cancelled by target." )
  end
end

function M.Initialize()
  M:OnTradeShow( on_trade_show )
  M:OnTradePlayerItemChanged( on_trade_player_item_changed )
  M:OnTradeTargetItemChanged( on_trade_target_item_changed )
  M:OnTradeClosed( on_trade_closed )
  M:OnTradeAcceptUpdate( on_trade_accept_update )
  M:OnTradeRequestCancel( on_trade_request_cancel )
end

return M
