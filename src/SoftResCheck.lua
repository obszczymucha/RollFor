local modules = LibStub( "RollFor-Modules" )
if modules.SoftResCheck then return end

local M = {}

local filter = modules.filter
local negate = modules.negate
local colors = modules.colors
local pretty_print = function( text ) modules.pretty_print( text, colors.softres ) end

function M.new( origin )
  local group_roster = origin.group_roster
  local softres = origin.matched_name_softres
  local name_matcher = origin.name_matcher

  local function show_who_is_not_softressing()
    local not_softressing = filter( group_roster.get_all_players_in_my_group(), negate( softres.is_player_softressing ) )

    if #not_softressing == 0 then
      modules.pretty_print( "All players in the group are soft-ressing.", colors.green )
      return
    end

    local p = function( text ) modules.pretty_print( text, colors.grey ) end
    p( "Players who did not soft-res:" )

    for _, player in pairs( not_softressing ) do
      p( colors.hl( player ) )
    end
  end

  local function check_softres()
    local softres_players = softres.get_all_softres_player_names()

    if #softres_players == 0 then
      pretty_print( "Nobody has soft-ressed." )
      return
    end

    name_matcher.report()
    show_who_is_not_softressing()

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

  local function show_softres()
    local needs_refetch = false
    local softressed_item_ids = softres.get_item_ids()
    local items = {}
    local p = pretty_print

    for _, item_id in pairs( softressed_item_ids ) do
      local players = softres.get( item_id )
      local item_link = modules.fetch_item_link( item_id )

      if not item_link then
        needs_refetch = true
      else
        items[ item_link ] = players
      end
    end

    if needs_refetch then
      modules.pretty_print( "Fetching soft-ressed items details from the server...", modules.grey )
      origin.ace_timer:ScheduleTimer( show_softres, 1 )
      return
    end

    local absent_softres_players = origin.absent_softres( softres ).get_all_softres_player_names()

    if modules.count_elements( items ) == 0 then
      p( "No soft-res items found." )
      return
    end

    name_matcher.report()
    p( string.format( "Soft-ressed items%s:",
      #absent_softres_players > 0 and string.format( " (players in %s are not in your group)", colors.red( "red" ) ) or "" ) )

    local colorize = function( player )
      local c = group_roster.is_player_in_my_group( player.name ) and colors.white or colors.red
      return player.rolls > 1 and string.format( "%s (%s)", c( player.name ), player.rolls ) or string.format( "%s", c( player.name ) )
    end

    for item_link, players in pairs( items ) do
      if modules.count_elements( players ) > 0 then
        p( string.format( "%s: %s", item_link, modules.prettify_table( players, colorize ) ) )
      end
    end

    show_who_is_not_softressing()
  end

  return {
    check_softres = check_softres,
    show_softres = show_softres,
    show_who_is_not_softressing = show_who_is_not_softressing
  }
end

modules.SoftResCheck = M
return M
