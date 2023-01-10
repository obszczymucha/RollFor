local modules = LibStub( "RollFor-Modules" )
if modules.SoftResMatchedNameDecorator then return end

local M = {}

function M.new( name_matcher, softres )
  local function get( item_id )
    local result = {}
    local softressers = softres.get( item_id )

    for _, v in pairs( softressers ) do
      local name = name_matcher.get_matched_name( v.name ) or v.name
      table.insert( result, { name = name, rolls = v.rolls } )
    end

    return result
  end

  local function is_player_softressing( player_name, item_id )
    local name = name_matcher.get_softres_name( player_name ) or player_name
    return softres.is_player_softressing( name, item_id )
  end

  local decorator = modules.clone( softres )
  decorator.get = get
  decorator.is_player_softressing = is_player_softressing

  return decorator
end

modules.SoftResMatchedNameDecorator = M
return M
