local modules = LibStub( "RollFor-Modules" )
if modules.AwardedLoot then return end

local M = {}

local function persist( items )
  if not RollForDb then RollForDb = {} end
  if not RollForDb.rollfor then RollForDb.rollfor = {} end
  RollForDb.rollfor.awarded_items = items
end

function M.new()
  local awarded_items = RollForDb and RollForDb.rollfor and RollForDb.rollfor.awarded_items or {} -- TODO: This breaks tests.

  local function award( player, item_id )
    table.insert( awarded_items, { player = player, item_id = item_id } )
    persist( awarded_items )
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

modules.AwardedLoot = M
return M
