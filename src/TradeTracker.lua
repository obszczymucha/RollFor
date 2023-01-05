local ModUi = LibStub:GetLibrary( "ModUi-1.0", 4 )
local E = ModUi:NewExtension( "TradeTracker" )
local OnTradeComplete, EmitTradeCompleteEvent = E:RegisterCallback( "tradeComplete" )

local api = ModUi.facade.api

local m_trading = false
local m_items_giving = {}
local m_items_receiving = {}
local m_player_accepted = false
local m_recipient_name = nil

local function highlight( text )
  return string.format( "|cffff9f69%s|r", text )
end

local function on_trade_show()
  m_recipient_name = api.TradeFrameRecipientNameText:GetText() or "Unknown"

  if RollFor.settings.tradeTrackerDebug then
    E:PrettyPrint( string.format( "Started trading with %s.", highlight( m_recipient_name ) ) )
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
    m_items_giving[ slot ] = { quantity = quantity, link = item_link }
  else
    m_items_giving[ slot ] = nil
  end
end

local function on_trade_target_item_changed( slot )
  local _, _, quantity = api.GetTradeTargetItemInfo( slot )
  local item_link = api.GetTradeTargetItemLink( slot )

  if quantity and item_link then
    m_items_receiving[ slot ] = { quantity = quantity, link = item_link }
  else
    m_items_receiving[ slot ] = nil
  end
end

local function on_trade_closed()
  if not m_trading then return end
  m_trading = false

  if RollFor.settings.tradeTrackerDebug then
    if m_player_accepted then
      E:PrettyPrint( string.format( "Trading with %s complete.", highlight( m_recipient_name ) ) )
    else
      E:PrettyPrint( "Trade cancelled by you." )
    end
  end

  if m_player_accepted then
    -- For some fucking unknown reason if these are not cloned then m_items_giving is empty.
    EmitTradeCompleteEvent( m_recipient_name, E:CloneTable( m_items_giving ), E:CloneTable( m_items_receiving ) )
  end
end

local function on_trade_accept_update( player )
  m_player_accepted = player == 1
end

local function on_trade_request_cancel()
  if not m_trading then return end
  m_trading = false

  if RollFor.settings.tradeTrackerDebug then
    E:PrettyPrint( string.format( "Trade cancelled by %s.", highlight( m_recipient_name ) ) )
  end
end

local function init()
  E.PrettyPrint = ModUi:GetModule( "RollFor" ).PrettyPrint
end

function E.Initialize()
  E:OnFirstEnterWorld( init )
  E:OnTradeShow( on_trade_show )
  E:OnTradePlayerItemChanged( on_trade_player_item_changed )
  E:OnTradeTargetItemChanged( on_trade_target_item_changed )
  E:OnTradeClosed( on_trade_closed )
  E:OnTradeAcceptUpdate( on_trade_accept_update )
  E:OnTradeRequestCancel( on_trade_request_cancel )
end

function E.ExtendComponent( component )
  component.OnTradeComplete = OnTradeComplete
end

return E
