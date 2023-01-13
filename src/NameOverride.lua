local modules = LibStub( "RollFor-Modules" )
if modules.NameOverride then return end

local M = {}

local clone = modules.clone
local negate = modules.negate
local filter = modules.filter
local keys = modules.keys
local merge = modules.merge
local colors = modules.colors
local p = modules.pretty_print

-- This might get handy if I ever wanted to safe-guard the length of chat messages.
--local function show_manual_matches( players )
--if #players == 0 then
--p( "There are no players that can be manually matched." )
--return
--end

--p( string.format( "Target a player and type: |cffff9f69%s|r.", "/sro <number>" ) )
--local buffer = ""

--for i = 1, #players do
--local separator = ""

--if buffer ~= "" then
--separator = separator .. ", "
--end

--local next = string.format( "[|cffff9f69%d|r]:|cffff2f2f%s|r", i, players[ i ] )

--if string.len( buffer .. separator .. next ) > 255 then
--p( buffer )
--buffer = next
--else
--buffer = buffer .. separator .. next
--end
--end

--if buffer ~= "" then
--p( buffer )
--end
--end

function M.new( api, absent_unfiltered_softres, name_matcher )
  local manual_matches = {}
  local manual_match_options = nil

  local function show_manual_matches( matches, absent_players )
    if #matches == 0 and #absent_players == 0 then
      p( "There are no players that can be manually matched." )
      return
    end

    local index = 1

    if #matches > 0 then
      p( string.format( "To unmatch, clear your target and type: %s", colors.hl( "/sro <number>" ) ) )

      for i = 1, #matches do
        p( string.format( "[%s]: %s (manually matched with %s)", colors.green( index ), colors.hl( matches[ i ] ), colors.hl( manual_matches[ matches[ i ] ] ) ) )
        index = index + 1
      end
    end

    if #absent_players > 0 then
      p( string.format( "To match, target a player and type: %s", colors.hl( "/sro <number>" ) ) )

      for i = 1, #absent_players do
        p( string.format( "[%s]: %s", colors.green( index ), colors.red( absent_players[ i ] ) ) )
        index = index + 1
      end
    end
  end

  local parse_number = function( args )
    for i in args:gmatch "(%d+)" do
      return tonumber( i )
    end

    return nil
  end

  local function is_matched( player_name )
    return manual_matches[ player_name ] or name_matcher.is_matched( player_name )
  end

  local function create_matches_and_show()
    local absent_players = filter( absent_unfiltered_softres.get_all_softres_player_names(), negate( is_matched ) )
    local manually_matched = keys( manual_matches )
    manual_match_options = merge( {}, manually_matched, absent_players )
    show_manual_matches( manually_matched, absent_players )
  end

  local function override( args )
    if not manual_match_options or not args or args == "" then
      create_matches_and_show()
      return
    end

    local count = #manual_match_options
    local target = api().UnitName( "target" )
    local index = parse_number( args )

    if not index or index < 0 or index > count then
      p( "Invalid player number." )
      create_matches_and_show()

      return
    end

    local softres_name = manual_match_options[ index ]
    local already_matched_name = manual_matches[ softres_name ]

    if target and already_matched_name then
      p( string.format( "%s is already matched to %s.", colors.hl( softres_name ), colors.hl( already_matched_name ) ) )
      create_matches_and_show()
    elseif target and not already_matched_name then
      manual_matches[ softres_name ] = target
      p( string.format( "|cffff9f69%s|r is now soft-ressing as |cffff9f69%s|r.", target, softres_name ) )
      manual_match_options = nil
    elseif not target and already_matched_name then
      manual_match_options = nil
      manual_matches[ softres_name ] = nil
      p( string.format( "Unmatched |cffff2f2f%s|r.", softres_name ) )
    else
      p( string.format( "To match a player, target them first." ) )
      create_matches_and_show()
    end
  end

  local function get_matched_name( softres_name )
    return manual_matches[ softres_name ] or name_matcher.get_matched_name( softres_name )
  end

  local function get_softres_name( matched_name )
    for softres_name, name in pairs( manual_matches ) do
      if name == matched_name then return softres_name end
    end

    return name_matcher.get_softres_name( matched_name )
  end

  local decorator = clone( name_matcher )
  decorator.override = override
  decorator.is_matched = is_matched
  decorator.get_matched_name = get_matched_name
  decorator.get_softres_name = get_softres_name

  return decorator
end

modules.NameOverride = M
return M
