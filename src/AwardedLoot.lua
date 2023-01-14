local modules = LibStub( "RollFor-Modules" )
if modules.AwardedLoot then return end

local M = {}

function M.new( db )
  local awarded_items = db.awarded_items or {} -- TODO: This breaks tests.

  local function persist()
    db.awarded_items = awarded_items
  end

  local function award( player, item_id )
    table.insert( awarded_items, { player = player, item_id = item_id } )
    persist()
  end

  local function has_item_been_awarded( player, item_id )
    for _, item in pairs( awarded_items ) do
      if item.player == player and item.item_id == item_id then return true end
    end

    return false
  end

  local function clear( report )
    awarded_items = {}
    persist()
    if report then modules.pretty_print( "Cleared awarded loot data." ) end
  end

  return {
    award = award,
    has_item_been_awarded = has_item_been_awarded,
    clear = clear
  }
end

modules.AwardedLoot = M
return M
