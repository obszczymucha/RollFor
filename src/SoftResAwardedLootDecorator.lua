local M = {}

function M.new( awarded_loot, softres )
  local get = softres.get

  softres.get = function( item_id )
    local result = {}
    local softressers = get( item_id )

    for _, v in pairs( softressers ) do
      if not awarded_loot.has_item_been_awarded( v.matched_name, item_id ) then
        table.insert( result, v )
      end
    end

    return result
  end

  return softres
end

SoftResAwardedLootDecorator = M
return M
