local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.MasterLoot then return end

local M = {}

local pretty_print = modules.pretty_print

local function idempotent_hookscript( frame, event, callback )
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

local function find_loot_confirmation_details()
  local frames = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }

  for i = 1, #frames do
    local base_frame_name = frames[ i ]
    local frame = _G[ base_frame_name .. "Text" ]

    if frame and frame:IsVisible() and frame.text_arg1 and frame.text_arg2 then
      local yes_button = _G[ base_frame_name .. "Button1" ]
      local no_button = _G[ base_frame_name .. "Button2" ]

      return base_frame_name, yes_button, no_button
    end
  end

  return nil
end

function M.new( origin )
  local item_to_be_awarded
  local item_award_confirmed

  local function hook_loot_confirmation_events( base_frame_name, yes_button, no_button )
    idempotent_hookscript( yes_button, "OnClick", function()
      local text_frame = _G[ base_frame_name .. "Text" ]
      local player = text_frame and text_frame.text_arg2
      local colored_item_name = text_frame and text_frame.text_arg1

      if player and colored_item_name then
        item_to_be_awarded = { player = player, colored_item_name = colored_item_name }
        item_award_confirmed = true
        pretty_print( string.format( "Attempting to award %s with %s.", item_to_be_awarded.player, item_to_be_awarded.colored_item_name ) )
      end
    end )

    idempotent_hookscript( no_button, "OnClick", function()
      item_award_confirmed = false
      item_to_be_awarded = nil
    end )
  end

  local function on_open_master_loot_list()
    for k, frame in pairs( modules.api.MasterLooterFrame ) do
      if type( k ) == "string" and k:find( "player", 1, true ) == 1 then
        idempotent_hookscript( frame, "OnClick", function()
          local base_frame_name, yes_button, no_button = find_loot_confirmation_details()
          if base_frame_name and yes_button and no_button then
            hook_loot_confirmation_events( base_frame_name, yes_button, no_button )
          end
        end )
      end
    end
  end

  local function on_loot_slot_cleared()
    if item_to_be_awarded and item_award_confirmed then
      local item_name = modules.decolorize( item_to_be_awarded.colored_item_name )
      local item_id = origin.dropped_loot.get_dropped_item_id( item_name )

      if item_id then
        origin.award_item( item_to_be_awarded.player, item_id, item_name, item_to_be_awarded.colored_item_name )
      else
        pretty_print( string.format( "Cannot determine item id for %s.", item_to_be_awarded.colored_item_name ) )
      end

      item_to_be_awarded = nil
      item_award_confirmed = false
    end
  end

  return {
    on_loot_slot_cleared = on_loot_slot_cleared,
    on_open_master_loot_list = on_open_master_loot_list
  }
end

modules.MasterLoot = M
return M
