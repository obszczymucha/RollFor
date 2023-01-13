local modules = LibStub( "RollFor-Modules" )
if modules.NameMatcher then return end

local M = {}

local colors = modules.colors
local count = modules.count_elements
local pretty_print = function( text ) modules.pretty_print( text, colors.name_checker ) end
local hl = colors.highlight

local function to_map( t )
  local result = {}

  for _, v in pairs( t ) do
    result[ v ] = 1
  end

  return result
end

-- Returns the values that are in the left table, but not in the right table.
local function is_in_left_but_not_in_right( left, right )
  local softres_player_map = to_map( right )
  local result = {}

  for _, player_name in pairs( left ) do
    if not softres_player_map[ player_name ] then
      table.insert( result, player_name )
    end
  end

  return result
end

local function string_similarity( s1, s2 )
  local n = string.len( s1 )
  local m = string.len( s2 )
  local ssnc = 0

  if n > m then
    s1, s2 = s2, s1
    n, m = m, n
  end

  for i = n, 1, -1 do
    if i <= string.len( s1 ) then
      for j = 1, n - i + 1, 1 do
        local pattern = string.sub( s1, j, j + i - 1 )
        if string.len( pattern ) == 0 then break end
        local foundAt = string.find( s2, pattern )

        if foundAt ~= nil then
          ssnc = ssnc + (2 * i) ^ 2
          s1 = string.sub( s1, 0, j - 1 ) .. string.sub( s1, j + i )
          s2 = string.sub( s2, 0, foundAt - 1 ) .. string.sub( s2, foundAt + i )
          break
        end
      end
    end
  end

  return (ssnc / ((n + m) ^ 2)) ^ (1 / 2)
end

local function get_levenshtein( s1, s2 )
  local len1 = #s1
  local len2 = #s2
  local matrix = {}
  local cost = 1
  local min = math.min;

  -- quick cut-offs to save time
  if (len1 == 0) then
    return len2
  elseif (len2 == 0) then
    return len1
  elseif (s1 == s2) then
    return 0
  end

  -- initialise the base matrix values
  for i = 0, len1, 1 do
    matrix[ i ] = {}
    matrix[ i ][ 0 ] = i
  end
  for j = 0, len2, 1 do
    matrix[ 0 ][ j ] = j
  end

  -- actual Levenshtein algorithm
  for i = 1, len1, 1 do
    for j = 1, len2, 1 do
      if (s1:byte( i ) == s2:byte( j )) then
        cost = 0
      end

      matrix[ i ][ j ] = min( matrix[ i - 1 ][ j ] + 1, matrix[ i ][ j - 1 ] + 1, matrix[ i - 1 ][ j - 1 ] + cost )
    end
  end

  -- return the last value - this is the Levenshtein distance
  return matrix[ len1 ][ len2 ]
end

local function get_similarity_predictions( present_players_who_did_not_softres, absent_players_who_did_softres, sort )
  local result = {}

  for _, player in pairs( present_players_who_did_not_softres ) do
    local predictions = {}

    for _, candidate in pairs( absent_players_who_did_softres ) do
      local prediction = { [ "candidate" ] = candidate, [ "similarity" ] = string_similarity( player, candidate ),
        [ "levenshtein" ] = get_levenshtein( player, candidate ) }
      table.insert( predictions, prediction )
    end

    table.sort( predictions, sort )
    result[ player ] = predictions
  end

  return result
end

local function improved_descending( l, r )
  return l[ "levenshtein" ] < r[ "levenshtein" ] or
      l[ "levenshtein" ] == r[ "levenshtein" ] and l[ "similarity" ] > r[ "similarity" ]
end

local function ends_with( str, ending )
  return ending == "" or str:sub( - #ending ) == ending
end

local function format_percent( value )
  local result = string.format( "%.2f", value * 100 )

  if ends_with( result, "0" ) then
    result = string.sub( result, 0, string.len( result ) - 1 )
  end

  if ends_with( result, "0" ) then
    result = string.sub( result, 0, string.len( result ) - 1 )
  end

  if ends_with( result, "." ) then
    result = string.sub( result, 0, string.len( result ) - 1 )
  end

  return string.format( "%s%%", result )
end

local function assign_predictions( predictions )
  local results = {}
  local results_below_threshold = {}

  for player, prediction in pairs( predictions ) do
    local top_candidate = prediction[ 1 ]
    local similarity = top_candidate[ "similarity" ]
    local levenshtein = top_candidate[ "levenshtein" ]

    local match = { [ "matched_name" ] = top_candidate[ "candidate" ], [ "similarity" ] = format_percent( similarity ),
      [ "levenshtein" ] = levenshtein }

    if similarity >= 0.57 then
      results[ player ] = match
    else
      results_below_threshold[ player ] = match
    end
  end

  return results, results_below_threshold
end

function M.new( group_roster, softres )
  local matched_names = {}
  local matched_names_below_threshold = {}

  local function auto_match()
    matched_names = {}
    matched_names_below_threshold = {}

    local present_players = group_roster.get_all_players_in_my_group()
    local softres_player_names = softres.get_all_softres_player_names()

    local present_players_who_did_not_softres = is_in_left_but_not_in_right( present_players, softres_player_names )
    if #present_players_who_did_not_softres == 0 then return end

    local absent_players_who_did_softres = is_in_left_but_not_in_right( softres_player_names, present_players )
    if #absent_players_who_did_softres == 0 then return end

    local predictions = get_similarity_predictions( present_players_who_did_not_softres, absent_players_who_did_softres, improved_descending )
    local matched, matched_below_threshold = assign_predictions( predictions )

    for player, match_result in pairs( matched ) do
      local matched_name = match_result[ "matched_name" ]
      local similarity = match_result[ "similarity" ]
      matched_names[ matched_name ] = { [ "matched_name" ] = player, [ "similarity" ] = similarity }
    end

    for player, match_result in pairs( matched_below_threshold ) do
      local matched_name = match_result[ "matched_name" ]
      local similarity = match_result[ "similarity" ]
      matched_names_below_threshold[ matched_name ] = { [ "matched_name" ] = player, [ "similarity" ] = similarity }
    end
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

    --local count = GetPlayersWhoDidNotSoftRes()

    --if #count == 0 then
    --ReportSoftResReady()
    --end
  end

  local function get_softres_name( matched_name )
    for softres_name, match in pairs( matched_names ) do
      if match.matched_name == matched_name then return softres_name end
    end

    return nil
  end

  local function get_matched_name( softres_name )
    return matched_names[ softres_name ] and matched_names[ softres_name ].matched_name or nil
  end

  local function report()
    if count( matched_names ) == 0 and count( matched_names_below_threshold ) == 0 then return end

    for softres_name, match in pairs( matched_names ) do
      pretty_print( string.format( "Auto-matched %s with %s.", hl( softres_name ), hl( match.matched_name ) ) )
    end

    for softres_name, match in pairs( matched_names_below_threshold ) do
      modules.pretty_print( string.format( "Couldn't auto-match %s. The closest match: %s.", hl( softres_name ), hl( match.matched_name ) ),
        colors.red )
    end
  end

  return {
    auto_match = auto_match,
    get_softres_name = get_softres_name,
    get_matched_name = get_matched_name,
    report = report
  }
end

modules.NameMatcher = M
return M
