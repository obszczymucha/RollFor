local modules = LibStub( "RollFor-Modules" )
if modules.TradeTracker then return end

M = {}

function M.new( trade_complete_callback )
  local m_trading = false
  local m_items_giving = {}
  local m_items_receiving = {}
  local m_player_accepted = false
  local m_recipient_name = nil

  local pretty_print = modules.pretty_print

  local function highlight( text )
    return string.format( "|cffff9f69%s|r", text )
  end

  local function on_trade_show()
    m_recipient_name = modules.api.TradeFrameRecipientNameText:GetText() or "Unknown"

    if RollFor.settings.tradeTrackerDebug then
      pretty_print( string.format( "Started trading with %s.", highlight( m_recipient_name ) ) )
    end

    m_trading = true
    m_player_accepted = false
  end

  local function on_trade_player_item_changed( slot )
    local _, _, quantity = modules.api.GetTradePlayerItemInfo( slot )
    local item_link = modules.api.GetTradePlayerItemLink( slot )

    if quantity and item_link then
      m_items_giving[ slot ] = { quantity = quantity, link = item_link }
    else
      m_items_giving[ slot ] = nil
    end
  end

  local function on_trade_target_item_changed( slot )
    local _, _, quantity = modules.api.GetTradeTargetItemInfo( slot )
    local item_link = modules.api.GetTradeTargetItemLink( slot )

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
        pretty_print( string.format( "Trading with %s complete.", highlight( m_recipient_name ) ) )
      else
        pretty_print( "Trade cancelled by you." )
      end
    end

    if m_player_accepted then
      trade_complete_callback( m_recipient_name, m_items_giving, m_items_receiving )
    end

    m_items_giving = {}
    m_items_receiving = {}
  end

  local function on_trade_accept_update( player )
    m_player_accepted = player == 1
  end

  local function on_trade_request_cancel()
    if not m_trading then return end
    m_trading = false

    if RollFor.settings.tradeTrackerDebug then
      pretty_print( string.format( "Trade cancelled by %s.", highlight( m_recipient_name ) ) )
    end
  end

  return {
    on_trade_show = on_trade_show,
    on_trade_player_item_changed = on_trade_player_item_changed,
    on_trade_target_item_changed = on_trade_target_item_changed,
    on_trade_closed = on_trade_closed,
    on_trade_accept_update = on_trade_accept_update,
    on_trade_request_cancel = on_trade_request_cancel
  }
end

modules.TradeTracker = M
return M
