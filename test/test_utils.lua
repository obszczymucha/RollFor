local M = {}

function M.princess()
  return "kenny"
end

function M.mock_wow_api()
  ---@diagnostic disable-next-line: lowercase-global
  strmatch = string.match
  CreateFrame = function()
    return {
      RegisterEvent = function() end,
      SetScript = function() end
    }
  end
end

function M.NewLibrary( name )
  require( "LibStub" )
  return LibStub:NewLibrary( name, 1 )
end

return M
