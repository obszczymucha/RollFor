local M = {}

function M.new()
  local awarded_items = {}

  -- TODO: persist
  local function award( player, item_id, item_name )
    table.insert( awarded_items, { player = player, item_id = item_id, item_name = item_name } )
  end

  local function has_item_been_awarded( player, item_id )
    for _, item in pairs( awarded_items ) do
      if item.player == player and item.item_id == item_id then return true end
    end

    return false
  end

  local function clear()
    awarded_items = {}
  end

  return {
    award = award,
    has_item_been_awarded = has_item_been_awarded,
    clear = clear
  }
end

AwardedLoot = M
return M
