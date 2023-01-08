local modules = LibStub( "RollFor-Modules" )
if modules.SoftResAwardedLootDecorator then return end

local M = {}

function M.new( name_matcher, awarded_loot, softres )
  local get = softres.get

  softres.get = function( item_id )
    local result = {}
    local softressers = get( item_id )

    for _, v in pairs( softressers ) do
      local name = name_matcher.get_matched_name( v.name ) or v.name -- TODO: test this (remove v.name from get_softres_name and tests still pass)
      if not awarded_loot.has_item_been_awarded( name, item_id ) then
        --table.insert( result, v ) -- TODO: test - this breaks things but tests still pass
        table.insert( result, { name = name, rolls = v.rolls } )
      end
    end

    return result
  end

  return softres
end

modules.SoftResAwardedLootDecorator = M
return M
