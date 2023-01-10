local modules = LibStub( "RollFor-Modules" )
if modules.SoftResAwardedLootDecorator then return end

local M = {}

function M.new( awarded_loot, softres )
  local function get( item_id )
    local result = {}
    local softressers = softres.get( item_id )

    for _, v in pairs( softressers ) do
      if not awarded_loot.has_item_been_awarded( v.name, item_id ) then
        table.insert( result, v )
      end
    end

    return result
  end

  local decorator = modules.clone( softres )
  decorator.get = get

  return decorator
end

modules.SoftResAwardedLootDecorator = M
return M
