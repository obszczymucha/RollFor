local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.MasterLoot then return end

local M = {}
local pretty_print = modules.pretty_print
local hl = modules.colors.hl

function M.new( dropped_loot, award_item, master_loot_frame, master_loot_tracker )
  local m_receiving_player_name
  local m_confirmed_slot

  local function on_loot_slot_cleared( slot )
    if m_receiving_player_name and m_confirmed_slot then
      local item_name = modules.api.LootFrame.selectedItemName
      local item_quality = modules.api.LootFrame.selectedQuality
      local item_id = dropped_loot.get_dropped_item_id( item_name )
      local item = master_loot_tracker.get( slot )
      local colored_item_name = modules.colorize_item_by_quality( item_name, item_quality )

      if item_id then
        award_item( m_receiving_player_name, item_id, item_name, item.link )
        master_loot_tracker.remove( slot )
      else
        pretty_print( string.format( "Cannot determine item id for %s.", colored_item_name ) )
      end

      m_receiving_player_name = nil
      m_confirmed_slot = nil
      master_loot_frame.hide()
    end
  end

  local function on_confirm( slot, player )
    m_receiving_player_name = player.name
    m_confirmed_slot = slot
    modules.api.GiveMasterLoot( slot, player.index )
    master_loot_frame.hide()
  end

  local function normal_loot( button )
    m_receiving_player_name = nil
    m_confirmed_slot = nil
    button:OriginalOnClick()
  end

  local function master_loot( button )
    m_receiving_player_name = nil
    m_confirmed_slot = nil
    local item_name = _G[ button:GetName() .. "Text" ]:GetText()
    modules.api.LootFrame.selectedQuality = button.quality
    modules.api.LootFrame.selectedItemName = item_name
    modules.api.LootFrame.selectedSlot = button.slot
    master_loot_frame.create( on_confirm )
    master_loot_frame.hide()

    if (master_loot_frame.create_candidate_frames()) then
      master_loot_frame.anchor( button )
      master_loot_frame.show()
    else
      modules.pretty_print( "Game API is broken. It doesn't return any Master Loot candidates." )
      normal_loot( button )
    end
  end

  local function on_loot_opened()
    m_receiving_player_name = nil
    m_confirmed_slot = nil

    -- TODO: Maybe extract this to a separate UI-only handling component and keep the logic pure.
    for i = 1, modules.api.LOOTFRAME_NUMBUTTONS do
      local name = "LootButton" .. i
      local button = _G[ name ]

      if button then
        if not button.OriginalOnClick then button.OriginalOnClick = button:GetScript( "OnClick" ) end

        button:SetScript( "OnClick",
          function( self, mouse_button )
            if mouse_button == "RightButton" then
              master_loot_frame.hide()
              normal_loot( self )
              return
            end

            if modules.api.IsModifiedClick( "CHATLINK" ) then
              modules.api.ChatFrameEditBox:Show()
              modules.api.ChatFrameEditBox:SetText( "/rf" )
              modules.api.ChatEdit_InsertLink( modules.api.GetLootSlotLink( self.slot ) )
              return
            end

            if mouse_button == "LeftButton" and modules.api.IsAltKeyDown() then
              modules.api.ChatFrameEditBox:Show()
              modules.api.ChatFrameEditBox:SetText( "/rr" )
              modules.api.ChatEdit_InsertLink( modules.api.GetLootSlotLink( self.slot ) )
              return
            end

            if self.hasItem and self.quality and self.quality >= modules.api.GetLootThreshold() then
              modules.api.CloseDropDownMenus()
              master_loot( self )
              return
            end

            master_loot_frame.hide()
            normal_loot( self )
          end
        )
      end
    end
  end

  local function on_loot_closed()
    master_loot_frame.hide()
    local items_left = master_loot_tracker.count()

    if not m_confirmed_slot and not m_receiving_player_name then
      if items_left > 0 then pretty_print( "Not all items were distributed." ) end
      return
    end

    if items_left == 0 then return end
    local item = master_loot_tracker.get( m_confirmed_slot )

    if items_left > 1 then
      pretty_print( "%s (slot %s) was supposed to be given to %s.", item and item.link or "Item", m_confirmed_slot, m_receiving_player_name )
      return
    end

    if item == nil then
      pretty_print( "A different slot left in the tracker.", "red" )
      return
    end

    award_item( m_receiving_player_name, item.id, item.name, item.link )
    master_loot_tracker.remove( m_confirmed_slot )
    m_receiving_player_name = nil
    m_confirmed_slot = nil
  end

  local on_recipient_inventory_full = function()
    if m_receiving_player_name and m_confirmed_slot then
      pretty_print( string.format( "%s's inventory is full.", hl( m_receiving_player_name ) ), "red" )
      m_receiving_player_name = nil
      m_confirmed_slot = nil
    end
  end

  return {
    on_loot_slot_cleared = on_loot_slot_cleared,
    on_loot_opened = on_loot_opened,
    on_loot_closed = on_loot_closed,
    on_recipient_inventory_full = on_recipient_inventory_full
  }
end

modules.MasterLoot = M
return M
