package.path = "./?.lua;" .. package.path .. ";../?.lua;../Libs/?.lua;../Libs/ModUi/?.lua;../Libs/LibStub/?.lua"

local lu = require( "luaunit" )
local utils = require( "test/utils" )

local player = utils.player
local trade_with = utils.trade_with
local cancel_trade = utils.cancel_trade
local trade_complete = utils.trade_complete
local trade_cancelled_by_recipient = utils.trade_cancelled_by_recipient
local register_trade_callback = utils.register_trade_callback
local trade_items = utils.trade_items
local recipient_trades_items = utils.recipient_trades_items
local assert_messages = utils.assert_messages
local c = utils.console_message

TradeTrackerIntegrationSpec = {}

function TradeTrackerIntegrationSpec:should_log_trading_process_when_trade_cancelled_by_you()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )

  -- When
  cancel_trade()

  -- Then
  assert_messages(
    c( "RollFor: Started trading with Obszczymucha." ),
    c( "RollFor: Trade cancelled by you." )
  )
end

function TradeTrackerIntegrationSpec:should_log_trading_process_when_trade_cancelled_by_the_recipient()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )

  -- When
  trade_cancelled_by_recipient()

  -- Then
  assert_messages(
    c( "RollFor: Started trading with Obszczymucha." ),
    c( "RollFor: Trade cancelled by Obszczymucha." )
  )
end

function TradeTrackerIntegrationSpec:should_log_trading_process_when_trade_is_complete()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )

  -- When
  trade_complete()

  -- Then
  assert_messages(
    c( "RollFor: Started trading with Obszczymucha." ),
    c( "RollFor: Trading with Obszczymucha complete." )
  )
end

function TradeTrackerIntegrationSpec:should_call_back_with_recipient_name()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )
  local result
  register_trade_callback( function( recipient ) result = recipient end )

  -- When
  trade_complete()

  -- Then
  lu.assertEquals( result, "Obszczymucha" )
end

function TradeTrackerIntegrationSpec:should_call_back_with_items_given()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )
  local result
  register_trade_callback( function( _, items_given ) result = items_given end )
  trade_items( { item_link = "fake item link", quantity = 1 } )

  -- When
  trade_complete()

  -- Then
  lu.assertEquals( result, {
    { item_link = "fake item link", quantity = 1 }
  } )
end

function TradeTrackerIntegrationSpec:should_call_back_with_items_received()
  -- Given
  player( "Psikutas" )
  trade_with( "Obszczymucha" )
  local result
  register_trade_callback( function( _, _, items_received ) result = items_received end )
  recipient_trades_items( { item_link = "fake item link", quantity = 1 } )

  -- When
  trade_complete()

  -- Then
  lu.assertEquals( result, {
    { item_link = "fake item link", quantity = 1 }
  } )
end

local runner = lu.LuaUnit.new()
runner:setOutputType( "text" )

utils.mock_libraries()
utils.load_real_stuff()
require( "src/TradeTracker" )

os.exit( runner:runSuite( "-T", "Spec", "-m", "should", "-v" ) )
