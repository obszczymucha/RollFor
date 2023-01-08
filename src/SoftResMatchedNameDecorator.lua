local modules = LibStub( "RollFor-Modules" )
if modules.SoftResMatchedNameDecorator then return end

local M = {}

function M.new( name_matcher, softres )
  local get = softres.get
  local is_player_softressing = softres.is_player_softressing

  softres.get = function( item_id )
    local result = {}
    local softressers = get( item_id )

    for _, v in pairs( softressers ) do
      local name = name_matcher.get_matched_name( v.name ) or v.name
      table.insert( result, { name = name, rolls = v.rolls } )
    end

    return result
  end

  softres.is_player_softressing = function( player_name, item_id )
    local name = name_matcher.get_softres_name( player_name ) or player_name
    return is_player_softressing( name, item_id )
  end

  return softres
end

modules.SoftResMatchedNameDecorator = M
return M
