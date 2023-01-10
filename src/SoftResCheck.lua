local modules = LibStub( "RollFor-Modules" )
if modules.SoftResCheck then return end

local M = {}

local pretty_print = function( text ) modules.pretty_print( text, modules.orange ) end

function M.new( softres, name_matcher )
  local function check_softres()
    local softres_players = softres.get_all_softres_player_names()

    if #softres_players == 0 then
      pretty_print( "Nobody has soft-ressed." )
      return
    end

    name_matcher.report()
    pretty_print( "Someone is soft-ressing." )

    --local playersWhoDidNotSoftRes = GetPlayersWhoDidNotSoftRes()
    --local absentPlayersWhoSoftRessed = GetAbsentPlayersWhoSoftRessed()

    --if #playersWhoDidNotSoftRes == 0 then
    --ReportSoftResReady( silent and silent ~= "" or false )
    --elseif #absentPlayersWhoSoftRessed == 0 then
    ---- These players didn't soft res.
    --if not silent then ReportPlayersWhoDidNotSoftRes( playersWhoDidNotSoftRes ) end

    --M:ScheduleTimer( function()
    --CreateSoftResPassOptions()
    --ShowSoftResPassOptions()
    --end, 1 )
    --else
    --local predictions = GetSimilarityPredictions( playersWhoDidNotSoftRes, absentPlayersWhoSoftRessed, improvedDescending )
    --local overrides, belowThresholdOverrides = AssignPredictions( predictions )

    --for player, override in pairs( overrides ) do
    --local overriddenName = override[ "override" ]
    --local similarity = override[ "similarity" ]
    --M:PrettyPrint( string.format( "Auto-matched %s to %s (%s similarity).", highlight( player ), highlight( overriddenName )
    --,
    --similarity ) )
    --softResPlayerNameOverrides[ overriddenName ] = { [ "override" ] = player, [ "similarity" ] = similarity }
    --end

    --if M:CountElements( belowThresholdOverrides ) > 0 then
    -----@diagnostic disable-next-line: param-type-mismatch
    --for player, _ in pairs( belowThresholdOverrides ) do
    --M:PrettyPrint( string.format( "%s Could not find soft-ressed item for %s.", red( "Warning!" ), highlight( player ) ) )
    --end

    --M:PrettyPrint( string.format( "Show soft-ressed items with %s command.", highlight( "/srs" ) ) )
    --M:PrettyPrint( string.format( "Did they misspell their nickname? Check and fix it with %s command.",
    --highlight( "/sro" ) ) )
    --M:PrettyPrint( string.format( "If they don't want to soft-res, mark them with %s command.", highlight( "/srp" ) ) )
    --end

    --local playersWhoDidNotSoftRes = GetPlayersWhoDidNotSoftRes()

    --if #playersWhoDidNotSoftRes == 0 then
    --ReportSoftResReady( silent and silent ~= "" or false )
    --end
    --end
  end

  return {
    check_softres = check_softres
  }
end

modules.SoftResCheck = M
return M
