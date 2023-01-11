local modules = LibStub( "RollFor-Modules" )
if modules.SoftResAwardedLootDecorator then return end

local M = {}

local filter = modules.filter

function M.new( awarded_loot, softres )
  local function get( item_id )
    return filter( softres.get( item_id ), function( v )
      return not awarded_loot.has_item_been_awarded( v.name, item_id )
    end )
  end

  local decorator = modules.clone( softres )
  decorator.get = get

  return decorator
end

modules.SoftResAwardedLootDecorator = M
return M
