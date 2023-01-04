---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local ModUi = libStub:GetLibrary( "ModUi-1.0", 4 )
local M = ModUi:NewModule( "RollFor", { "TradeTracker" } )
if not M then return end

local dropped_loot_announce = libStub:GetLibrary( "RollFor-DroppedLootAnnounce" )
local version = "1.17"

local m_timer = nil
local m_seconds_left = nil
local m_rolled_item = nil
local m_rolled_item_count = 0
local m_rolled_item_reserved = false
local m_rolling = false
local m_rerolling = false
local m_rolls = {}
local m_offspec_rolls = {}
local m_rollers = {}
local m_offspec_rollers = {}
local m_winner_count = 0
local m_announced_source_ids = {}
local m_announcing = false
local m_cancelled = false
local m_item_to_be_awarded = nil
local m_item_award_confirmed = false
local m_awarded_items = {}
local m_dropped_items = {}
local m_reserved_by = {}

local AceGUI = libStub( "AceGUI-3.0" )
local item_utils = libStub( "ItemUtils" )

-- Persisted values
local m_softres_data = nil
local m_softres_items = {}
local m_hardres_items = {}
local m_softres_player_name_overrides = {}
local m_softres_passing = {}

-- Non-persisted softres values
local m_softres_frame = nil
local m_softres_data_dirty = false

-- Softres pass/override
local m_softres_pass_options = nil
local m_softres_unpass_options = nil
local m_softres_player_name_override_options = nil
local m_softres_player_name_unoverride_options = nil

local commPrefix = "ModUi-RollFor"
local wasInGroup = false

local api = ModUi.facade.api
local lua = ModUi.facade.lua

local chatFrame = api.ChatFrame1

local function reset()
  m_timer = nil
  m_seconds_left = nil
  m_rolled_item = nil
  m_rolled_item_count = 0
  m_rolled_item_reserved = false
  m_rolling = false
  m_rerolling = false
  m_rolls = {}
  m_offspec_rolls = {}
  m_rollers = {}
  m_offspec_rollers = {}
  m_winner_count = 0
  m_announced_source_ids = {}
  m_announcing = false
  m_cancelled = false
  m_item_to_be_awarded = nil
  m_item_award_confirmed = false
  m_awarded_items = {}
  m_dropped_items = {}
  m_softres_data_dirty = false
  m_softres_items = {}
  m_hardres_items = {}
  m_reserved_by = {}
end

local function UpdateGroupStatus()
  wasInGroup = api.IsInGroup() or api.IsInRaid()
end

local highlight = function( word )
  return string.format( "|cffff9f69%s|r", word )
end

local red = function( word )
  return string.format( "|cffff2f2f%s|r", word )
end

local function Report( text )
  local _silent = true

  if api.IsInRaid() and not _silent then
    api.SendChatMessage( text, "RAID" )
  elseif api.IsInGroup() and not _silent then
    api.SendChatMessage( text, "PARTY" )
  else
    M:PrettyPrint( text )
  end
end

function StringSimilarity( s1, s2 )
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

local function Levenshtein( s1, s2 )
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

local function improvedDescending( l, r )
  return l[ "levenshtein" ] < r[ "levenshtein" ] or
      l[ "levenshtein" ] == r[ "levenshtein" ] and l[ "similarity" ] > r[ "similarity" ]
end

--local function descending(l, r)
--  return l["similarity"] > r["similarity"]
--end

local function GetSimilarityPredictions( playersInGroupWhoDidNotSoftRes, playersNotInGroupWhoSoftRessed, sort )
  local results = {}

  for _, player in pairs( playersInGroupWhoDidNotSoftRes ) do
    local predictions = {}

    for _, candidate in pairs( playersNotInGroupWhoSoftRessed ) do
      local prediction = { [ "candidate" ] = candidate, [ "similarity" ] = StringSimilarity( player, candidate ),
        [ "levenshtein" ] = Levenshtein( player, candidate ) }
      table.insert( predictions, prediction )
    end

    table.sort( predictions, sort )
    results[ player ] = predictions
  end

  return results
end

local function endsWith( str, ending )
  return ending == "" or str:sub( - #ending ) == ending
end

local function formatPercent( value )
  local result = string.format( "%.2f", value * 100 )

  if endsWith( result, "0" ) then
    result = string.sub( result, 0, string.len( result ) - 1 )
  end

  if endsWith( result, "0" ) then
    result = string.sub( result, 0, string.len( result ) - 1 )
  end

  if endsWith( result, "." ) then
    result = string.sub( result, 0, string.len( result ) - 1 )
  end

  return string.format( "%s%%", result )
end

function AssignPredictions( predictions )
  local results = {}
  local belowThresholdResults = {}

  for player, prediction in pairs( predictions ) do
    local topCandidate = prediction[ 1 ]
    local similarity = topCandidate[ "similarity" ]
    local levenshtein = topCandidate[ "levenshtein" ]

    local override = { [ "override" ] = topCandidate[ "candidate" ], [ "similarity" ] = formatPercent( similarity ),
      [ "levenshtein" ] = levenshtein }

    if similarity >= 0.57 then
      results[ player ] = override
    else
      belowThresholdResults[ player ] = override
    end
  end

  return results, belowThresholdResults
end

local function IsPlayerAlreadyOverridingAName( overridingPlayer )
  for player, override in pairs( m_softres_player_name_overrides ) do
    if player ~= override and override == overridingPlayer then return true end
  end

  return false
end

local function IsPlayerSoftResPassing( player )
  if m_softres_passing[ player ] or m_softres_passing[ string.lower( player ) ] then
    return true
  else
    return false
  end
end

local function OverridePlayerNames( players )
  local result = {}

  for _, player in pairs( players ) do
    table.insert( result, m_softres_player_name_overrides[ player.name ] and {
      name = m_softres_player_name_overrides[ player.name ][ "override" ],
      rolls = player.rolls
    } or player )
  end

  return result
end

local function FilterSoftResPassingPlayers( players )
  local rolling = {}
  local passing = {}

  for _, player in pairs( players ) do
    if not IsPlayerSoftResPassing( player.name ) then
      table.insert( rolling, player )
    else
      table.insert( passing, player )
    end
  end

  return rolling, passing
end

local function FilterAbsentPlayers( players )
  local present = {}
  local absent = {}

  for _, player in pairs( players ) do
    if M:IsPlayerInMyGroup( player.name ) then
      table.insert( present, player )
    else
      table.insert( absent, player )
    end
  end

  return present, absent
end

local function has_player_already_received_item( player, item_id )
  for _, v in pairs( m_awarded_items ) do
    if v.player == player and v.item_id == item_id then return true end
  end

  return false
end

local function FilterPlayersWhoAlreadyReceivedTheItem( item_id, players )
  local result = {}

  for _, player in pairs( players ) do
    if not has_player_already_received_item( player.name, item_id ) then
      table.insert( result, player )
    end
  end

  return result
end

local function map( t, f )
  if type( f ) ~= "function" then return t end

  local result = {}

  for k, v in pairs( t ) do
    result[ k ] = f( v )
  end

  return result
end

local function GetAllPlayers()
  return map( M:GetAllPlayersInMyGroup(), function( player )
    return { name = player, rolls = 1 }
  end )
end

local function IncludeReservedRolls( item_id )
  local reservedByPlayers = FilterPlayersWhoAlreadyReceivedTheItem( item_id,
    FilterAbsentPlayers( FilterSoftResPassingPlayers( OverridePlayerNames( M:CloneTable( m_softres_items[ item_id ] ) ) ) ) )

  local reserving_player_count = M:CountElements( reservedByPlayers )
  local rollers = reservedByPlayers and reserving_player_count > 0 and reservedByPlayers or GetAllPlayers()
  table.sort( reservedByPlayers, function( l, r ) return l.name < r.name end )
  return rollers, reservedByPlayers, reserving_player_count
end

local function GetAbsentPlayersWhoSoftRessed()
  local result = {}

  for name, override in pairs( m_softres_player_name_overrides ) do
    if not M:IsPlayerInMyGroup( override[ "override" ] ) and not IsPlayerSoftResPassing( name ) then
      table.insert( result, override[ "override" ] )
    end
  end

  return result
end

local function HasPlayerSoftRessed( player )
  for _, override in pairs( m_softres_player_name_overrides ) do
    if string.lower( player ) == string.lower( override[ "override" ] ) then return true end
  end

  return false
end

local function GetPlayersWhoDidNotSoftRes()
  local players = M:GetGroupMemberNames()
  local result = {}

  for _, player in pairs( players ) do
    if not HasPlayerSoftRessed( player ) and not IsPlayerSoftResPassing( player ) then
      table.insert( result, player )
    end
  end

  return result
end

local function add_soft_ressing_player( soft_res_items, player_name )
  for _, value in pairs( soft_res_items ) do
    if value.name == player_name then
      value.rolls = value.rolls + 1
      return
    end
  end

  table.insert( soft_res_items, { name = player_name, rolls = 1 } )
end

local function process_softres_items( entries )
  if not entries then return {} end
  local result = {}

  for i = 1, #entries do
    local entry = entries[ i ]
    local items = entry.items

    for j = 1, #items do
      local id = items[ j ].id

      if not result[ id ] then
        result[ id ] = {}
      end

      add_soft_ressing_player( result[ id ], entry.name )

      if not m_softres_player_name_overrides[ entry.name ] then
        m_softres_player_name_overrides[ entry.name ] = { [ "override" ] = entry.name, [ "similarity" ] = 0 }
      end
    end
  end

  return result
end

local function process_hardres_items( entries )
  if not entries then return {} end
  local result = {}

  for i = 1, #entries do
    local id = entries[ i ].id

    if not result[ id ] then
      result[ id ] = 1
    end
  end

  return result
end

function M.import_softres_data( data )
  m_softres_items = {}
  m_hardres_items = {}
  m_awarded_items = {}
  m_dropped_items = {}

  if not data then
    ModUiDb.rollfor.softres_items = {}
    ModUiDb.rollfor.hardres_items = {}
    ModUiDb.rollfor.awarded_items = {}
    ModUiDb.rollfor.dropped_items = {}
    return
  end

  m_softres_items = process_softres_items( data.softreserves )
  m_hardres_items = process_hardres_items( data.hardreserves )

  ModUiDb.rollfor.softres_items = m_softres_items
  ModUiDb.rollfor.hardres_items = m_hardres_items
end

local function ShowSoftRes( args )
  local needsRefetch = false
  local items = {}

  for item_id, players in pairs( m_softres_items ) do
    local itemLink = M:GetItemLink( item_id )

    if not itemLink then
      needsRefetch = true
    else
      items[ itemLink ] = FilterSoftResPassingPlayers( OverridePlayerNames( players ) )
    end
  end

  local silent = not (args and args == "report")

  if needsRefetch then
    M:DebugMsg( "Not all items were fetched. Retrying...", silent )
    M:ScheduleTimer( ShowSoftRes, 1 )
    return
  end

  if M:CountElements( items ) == 0 then
    Report( "No soft-res items found." )
    return
  end

  Report( "Soft-ressed items (red players are not in your group):" )
  local colorize = function( player )
    local rolls = player.rolls > 1 and string.format( " (%s)", player.rolls ) or ""
    return string.format( "|cff%s%s|r%s",
      M:IsPlayerInMyGroup( player.name ) and "ffffff" or "ff2f2f",
      player.name, rolls )
  end

  for itemLink, players in pairs( items ) do
    if M:CountElements( players ) > 0 then
      Report( string.format( "%s: %s", itemLink, M:TableToCommifiedPrettyString( players, colorize ) ) )
    end
  end
end

local function UpdateData( silent )
  if not m_softres_data_dirty then return end

  ModUiDb.rollfor.softres_data = m_softres_data

  local data = M:DecodeBase64( m_softres_data )

  if data then
    data = libStub:GetLibrary( "LibDeflate" ):DecompressZlib( data )
  end

  if data then
    data = ModUi.json.decode( data )
  end

  if data then
    M.import_softres_data( data )
    if not silent then
      M:PrettyPrint( string.format( "Data loaded successfully. Use %s command to list.", highlight( "/srs" ) ) )
    else
      M:PrettyPrint( "Soft-res data active." )
    end
  else
    M.import_softres_data( nil )
    if not silent then M:PrettyPrint( "Could not load soft-res data." ) end
  end

  m_softres_data_dirty = false
end

local function ShowSoftResPlayerNameOverrideOptions()
  local players = m_softres_player_name_override_options

  if M:CountElements( players ) == 0 then
    M:PrettyPrint( "There are no players that can be overridden." )
    return
  end

  M:PrettyPrint( string.format( "Target a player and type |cffff9f69%s|r.", "/sro <number>" ) )
  local buffer = ""

  for i = 1, #players do
    local separator = ""
    if buffer ~= "" then
      separator = separator .. ", "
    end

    local nextPlayer = string.format( "[|cffff9f69%d|r]:|cffff2f2f%s|r", i, players[ i ] )

    if (string.len( buffer .. separator .. nextPlayer ) > 255) then
      M:PrettyPrint( buffer )
      buffer = nextPlayer
    else
      buffer = buffer .. separator .. nextPlayer
    end
  end

  if buffer ~= "" then
    M:PrettyPrint( buffer )
  end
end

local function ReportSoftResReady()
  Report( "Soft-res setup is complete." )
end

local function CreateSoftResPlayerNameOverrideOptions()
  m_softres_player_name_override_options = GetAbsentPlayersWhoSoftRessed()
end

local function SoftResPlayerNameOverride( args )
  if not m_softres_player_name_override_options or not args or args == "" then
    CreateSoftResPlayerNameOverrideOptions()
    ShowSoftResPlayerNameOverrideOptions()
    return
  end

  local options_count = M:CountElements( m_softres_player_name_override_options )
  local matched = false
  local target = api.UnitName( "target" )

  if target and IsPlayerAlreadyOverridingAName( target ) then
    m_softres_player_name_override_options = nil
    local f = function( value )
      return function( v )
        return v[ "override" ] == value
      end
    end

    M:PrettyPrint( string.format( "Player |cffff2f2f%s|r is already overriding |cffff9f69%s|r!", target,
      M:GetKeyByValue( m_softres_player_name_overrides, f( target ) ) ) )
    return
  end

  for i in (args):gmatch "(%d+)" do
    if not matched then
      local index = tonumber( i )

      if index > 0 and index <= options_count and target then
        matched = true
        local player = m_softres_player_name_override_options[ index ]
        m_softres_player_name_overrides[ player ] = { [ "override" ] = target, [ "similarity" ] = 0 }
        ModUiDb.rollfor.softres_player_name_overrides = m_softres_player_name_overrides

        M:PrettyPrint( string.format( "|cffff9f69%s|r is now soft-ressing as |cffff9f69%s|r.", target, player ) )
        local count = M:CountElements( m_softres_player_name_override_options )

        if count == 0 then
          ReportSoftResReady()
        end
      end
    end
  end

  if matched then
    m_softres_player_name_override_options = nil
  else
    CreateSoftResPlayerNameOverrideOptions()
    ShowSoftResPlayerNameOverrideOptions()
  end
end

local function CreateSoftResPlayerNameUnoverrideOptions()
  m_softres_player_name_unoverride_options = {}

  for player, override in pairs( m_softres_player_name_overrides ) do
    if player ~= override[ "override" ] then
      table.insert( m_softres_player_name_unoverride_options, player )
    end
  end
end

local function ShowSoftResPlayerNameUnoverrideOptions()
  local players = m_softres_player_name_unoverride_options

  if M:CountElements( players ) == 0 then
    M:PrettyPrint( "There are no players that have their names soft-res overridden." )
    return
  end

  M:PrettyPrint( string.format( "To unoverride type |cffff9f69%s|r.", "/sruo <numbers...>" ) )
  local buffer = ""

  for i = 1, #players do
    local separator = ""
    if buffer ~= "" then
      separator = separator .. ", "
    end

    local player = players[ i ]
    local overrider = m_softres_player_name_overrides[ player ][ "override" ]
    local color = function( _player ) return M:IsPlayerInMyGroup( _player ) and "ffffff" or "ff2f2f" end
    local nextPlayer = string.format( "[|cffff9f69%d|r]:|cff%s%s|r (|cff%s%s|r)", i, color( player ), player,
      color( overrider ),
      overrider )

    if (string.len( buffer .. separator .. nextPlayer ) > 255) then
      M:PrettyPrint( buffer )
      buffer = nextPlayer
    else
      buffer = buffer .. separator .. nextPlayer
    end
  end

  if buffer ~= "" then
    M:PrettyPrint( buffer )
  end
end

local function SoftResPlayerNameUnoverride( args )
  if not m_softres_player_name_unoverride_options or not args or args == "" then
    CreateSoftResPlayerNameUnoverrideOptions()
    ShowSoftResPlayerNameUnoverrideOptions()
    return
  end

  local count = M:CountElements( m_softres_player_name_unoverride_options )

  for i in (args):gmatch "(%d+)" do
    local index = tonumber( i )

    if index > 0 and index <= count then
      local player = m_softres_player_name_unoverride_options[ index ]
      m_softres_player_name_overrides[ player ] = { [ "override" ] = player, [ "similarity" ] = 0 }
      ModUiDb.rollfor.softres_player_name_overrides = m_softres_player_name_overrides

      M:PrettyPrint( string.format( "|cffff9f69%s|r's name is no longer soft-res overridden.", player ) )
    end
  end

  CreateSoftResPlayerNameUnoverrideOptions()
  ShowSoftResPlayerNameUnoverrideOptions()
end

local function CreateSoftResPassOptions()
  --local absentPlayersWhoSoftRessed = GetAbsentPlayersWhoSoftRessed()
  local absentPlayersWhoSoftRessed = {}
  local presentPlayersWhoDidNotSoftRes = GetPlayersWhoDidNotSoftRes()
  m_softres_pass_options = M:JoinTables( absentPlayersWhoSoftRessed, presentPlayersWhoDidNotSoftRes )
end

local function ShowSoftResPassOptions()
  if #m_softres_pass_options == 0 then
    M:PrettyPrint( "No one is soft-res passing on loot." )
    return
  end

  M:PrettyPrint( string.format( "To soft-res pass type |cffff9f69%s|r.", "/srp <numbers...>" ) )
  local buffer = ""

  for i = 1, #m_softres_pass_options do
    local separator = ""

    if buffer ~= "" then
      separator = separator .. ", "
    end

    local player = m_softres_pass_options[ i ]
    local nextPlayer = string.format( "[|cffff9f69%d|r]:|cff%s%s|r", i,
      M:IsPlayerInMyGroup( player ) and "ffffff" or "ff2f2f",
      player )

    if (string.len( buffer .. separator .. nextPlayer ) > 255) then
      M:PrettyPrint( buffer )
      buffer = nextPlayer
    else
      buffer = buffer .. separator .. nextPlayer
    end
  end

  if buffer ~= "" then
    M:PrettyPrint( buffer )
  end
end

local function SoftResPass( args )
  if not m_softres_pass_options or not args or args == "" then
    CreateSoftResPassOptions()
    ShowSoftResPassOptions()
    return
  end

  local count = M:CountElements( m_softres_pass_options )

  for i in (args):gmatch "(%d+)" do
    local index = tonumber( i )

    if index > 0 and index <= count then
      local player = m_softres_pass_options[ index ]
      m_softres_passing[ player ] = true
      ModUiDb.rollfor.softres_passing = m_softres_passing

      M:PrettyPrint( string.format( "|cff%s%s|r is not soft-ressing.", M:IsPlayerInMyGroup( player ) and "ff9f69" or "ff2f2f"
        ,
        player ) )
    end
  end

  CreateSoftResPassOptions()
  ShowSoftResPassOptions()

  if M:CountElements( m_softres_pass_options ) == 0 then
    ReportSoftResReady()
  end
end

local function CreateSoftResUnpassOptions()
  m_softres_unpass_options = M:keys( M:filter( m_softres_passing, M.ValueIsTrue ) )
end

local function ShowSoftResUnpassOptions()
  local players = m_softres_unpass_options

  if M:CountElements( players ) == 0 then
    M:PrettyPrint( "No players are soft-res passing on loot." )
    return
  end

  M:PrettyPrint( string.format( "To soft-res unpass type |cffff9f69%s|r.", "/srup <numbers...>" ) )
  local buffer = ""

  for i = 1, #players do
    local separator = ""

    if buffer ~= "" then
      separator = separator .. ", "
    end

    local player = players[ i ]
    local nextPlayer = string.format( "[|cffff9f69%d|r]:|cff%s%s|r", i,
      M:IsPlayerInMyGroup( player ) and "ffffff" or "ff2f2f",
      player )

    if (string.len( buffer .. separator .. nextPlayer ) > 255) then
      M:PrettyPrint( buffer )
      buffer = nextPlayer
    else
      buffer = buffer .. separator .. nextPlayer
    end

    i = i + 1
  end

  if buffer ~= "" then
    M:PrettyPrint( buffer )
  end
end

local function SoftResUnpass( args )
  if not m_softres_unpass_options or not args or args == "" then
    CreateSoftResUnpassOptions()
    ShowSoftResUnpassOptions()
    return
  end

  local count = M:CountElements( m_softres_unpass_options )

  for i in (args):gmatch "(%d+)" do
    local index = tonumber( i )

    if index > 0 and index <= count then
      local player = m_softres_unpass_options[ index ]
      m_softres_passing[ player ] = false
      ModUiDb.rollfor.softres_passing = m_softres_passing

      M:PrettyPrint( string.format( "|cff%s%s|r is soft-ressing now.", M:IsPlayerInMyGroup( player ) and "ff2f2f" or "ff9f69"
        ,
        player ) )
    end
  end

  CreateSoftResUnpassOptions()
  ShowSoftResUnpassOptions()
end

local function ThereWasATie( topRoll, topRollers )
  table.sort( topRollers )
  local topRollersStr = M:TableToCommifiedPrettyString( topRollers )
  local topRollersStrColored = M:TableToCommifiedPrettyString( topRollers, highlight )

  M:PrettyPrint( string.format( "The %shighest %sroll was %d by %s.", not m_rerolling and m_winner_count > 0 and "next " or "",
    m_rerolling and "re-" or "", topRoll, topRollersStrColored, m_rolled_item ), M:GetGroupChatType() )
  api.SendChatMessage( string.format( "The %shighest %sroll was %d by %s.",
    not m_rerolling and m_winner_count > 0 and "next " or "",
    m_rerolling and "re-" or "", topRoll, topRollersStr, m_rolled_item ), M:GetGroupChatType() )
  m_rolls = {}
  m_rollers = map( topRollers, function( player_name ) return { name = player_name, rolls = 1 } end )
  m_offspec_rollers = {}
  m_rerolling = true
  m_rolling = true
  ModUi:ScheduleTimer( function() api.SendChatMessage( string.format( "%s /roll for %s now.", topRollersStr, m_rolled_item ),
      M:GetGroupChatType() )
  end, 2.5 )
end

local function CancelRollingTimer()
  ModUi:CancelTimer( m_timer )
  m_timer = nil
end

local function PrintRollingComplete()
  M:PrettyPrint( string.format( "Rolling for %s has %s.", m_rolled_item, m_cancelled and "been cancelled" or "finished" ) )
end

local function StopRolling()
  if not m_rolling then return end

  m_rolling = false
end

local function SortRolls( rolls )
  local function RollMap( _rolls )
    local result = {}

    for _, roll in pairs( _rolls ) do
      if not result[ roll ] then result[ roll ] = true end
    end

    return result
  end

  local function ToMap( _rolls )
    local result = {}

    for k, v in pairs( _rolls ) do
      if result[ v ] then
        table.insert( result[ v ][ "players" ], k )
      else
        result[ v ] = { roll = v, players = { k } }
      end
    end

    return result
  end

  local function f( l, r )
    if l > r then
      return true
    else
      return false
    end
  end

  local function ToSortedRollsArray( rollMap )
    local result = {}

    for k in pairs( rollMap ) do
      table.insert( result, k )
    end

    table.sort( result, f )
    return result
  end

  local function Merge( sortedRolls, t )
    local result = {}

    for _, v in ipairs( sortedRolls ) do
      table.insert( result, t[ v ] )
    end

    return result
  end

  local sortedRolls = ToSortedRollsArray( RollMap( rolls ) )
  local t = ToMap( rolls )

  return Merge( sortedRolls, t )
end

local function ShowSortedRolls( limit )
  local sortedRolls = SortRolls( m_rolls )
  local i = 1

  M:PrettyPrint( "Rolls:" )

  for _, v in ipairs( sortedRolls ) do
    if limit and limit > 0 and i > limit then return end

    M:PrettyPrint( string.format( "[|cffff9f69%d|r]: %s", v[ "roll" ], M:TableToCommifiedPrettyString( v[ "players" ] ) ) )
    i = i + 1
  end
end

local function PrintWinner( roll, players, is_offspec )
  local f = highlight
  local offspec = is_offspec and " (OS)" or ""

  M:PrettyPrint( string.format( "%s %srolled the %shighest (%s) for %s%s.", M:TableToCommifiedPrettyString( players, f ),
    m_rerolling and "re-" or "", not m_rerolling and m_winner_count > 0 and "next " or "", f( roll ), m_rolled_item, offspec ) )
  api.SendChatMessage( string.format( "%s %srolled the %shighest (%d) for %s%s.", M:TableToCommifiedPrettyString( players ),
    m_rerolling and "re-" or "", not m_rerolling and m_winner_count > 0 and "next " or "", roll, m_rolled_item, offspec ),
    M:GetGroupChatType() )
end

local function have_all_players_rolled_offspec()
  if #m_offspec_rollers == 0 then return false end

  for _, v in pairs( m_offspec_rollers ) do
    if v.rolls > 0 then return false end
  end

  return true
end

local function have_all_rolls_been_exhausted()
  local mainspec_roll_count = M:CountElements( m_rolls )
  local offspec_roll_count = M:CountElements( m_offspec_rolls )
  local total_roll_count = mainspec_roll_count + offspec_roll_count

  if m_rolled_item_count == #m_offspec_rollers and have_all_players_rolled_offspec() or
      #m_rollers == m_rolled_item_count and total_roll_count == #m_rollers then
    return true
  end

  for _, v in pairs( m_rollers ) do
    if v.rolls > 0 then return false end
  end

  return true
end

local function reindex( t )
  local result = {}

  for _, v in pairs( t ) do
    table.insert( result, v )
  end

  return result
end

local function announce_extra_rolls_left()
  local remaining_rollers = reindex( M:filter( m_rollers, function( _, roller ) return roller.rolls > 0 end ) )

  local transform = function( player )
    local rolls = player.rolls == 1 and "1 roll" or string.format( "%s rolls", player.rolls )
    return string.format( "%s (%s)", player.name, rolls )
  end

  ModUi.remaining_rollers = remaining_rollers
  local message = M:TableToCommifiedPrettyString( remaining_rollers, transform )
  api.SendChatMessage( string.format( "SR rolls remaining: %s", message ), M:GetGroupChatType() )
end

local function was_there_a_tie( sorted_rolls )
  if #sorted_rolls == 0 then return false end

  return #sorted_rolls[ 1 ].players > 1
end

local function process_sorted_rolls( sorted_rolls, forced, rolls_exhausted, is_offspec, fallback_fn )
  for _, v in ipairs( sorted_rolls ) do
    local roll = v[ "roll" ]
    local players = v[ "players" ]
    local candidate_count = m_winner_count + #players

    if m_rolled_item_count == candidate_count then
      if m_rolled_item_reserved and not forced and not rolls_exhausted then
        PrintWinner( roll, players, is_offspec )
        announce_extra_rolls_left()
      else
        StopRolling()
        PrintWinner( roll, players, is_offspec )
        m_winner_count = m_winner_count + 1
      end

      return
    elseif was_there_a_tie( sorted_rolls ) and (rolls_exhausted or is_offspec or m_seconds_left <= 0) then
      ThereWasATie( roll, players )
      return
    else
      PrintWinner( roll, players, is_offspec )

      if forced then
        StopRolling()
        m_winner_count = m_winner_count + 1
        return
      elseif m_rolled_item_reserved and not rolls_exhausted then
        announce_extra_rolls_left()
        return
      end

      m_winner_count = m_winner_count + 1
    end
  end

  if fallback_fn and m_winner_count < m_rolled_item_count then
    fallback_fn()
  else
    StopRolling()
  end
end

local function FinalizeRolling( forced )
  CancelRollingTimer()
  local rolls_exhausted = have_all_rolls_been_exhausted()

  local mainspec_roll_count = M:CountElements( m_rolls )
  local offspec_roll_count = M:CountElements( m_offspec_rolls )

  if mainspec_roll_count + offspec_roll_count == 0 then
    StopRolling()
    M:PrettyPrint( string.format( "Nobody rolled for %s.", m_rolled_item ) )
    api.SendChatMessage( string.format( "Nobody rolled for %s.", m_rolled_item ), M:GetGroupChatType() )
    PrintRollingComplete()
    return
  end

  local offspec_rolling = function() process_sorted_rolls( SortRolls( m_offspec_rolls ), forced, rolls_exhausted, true ) end

  if mainspec_roll_count > 0 then
    process_sorted_rolls( SortRolls( m_rolls ), forced, rolls_exhausted, false, offspec_rolling )
  else
    offspec_rolling()
  end

  if not m_rolling then
    PrintRollingComplete()
  end
end

local function OnTimer()
  if not m_timer then return end

  m_seconds_left = m_seconds_left - 1

  if m_seconds_left <= 0 then
    FinalizeRolling()
  elseif m_seconds_left == 3 then
    api.SendChatMessage( "Stopping rolls in 3", M:GetGroupChatType() )
  elseif m_seconds_left < 3 then
    api.SendChatMessage( m_seconds_left, M:GetGroupChatType() )
  end
end

local function GetRollAnnouncementChatType()
  local chatType = M:GetGroupChatType()
  local rank = M:MyRaidRank()

  if chatType == "RAID" and rank > 0 then
    return "RAID_WARNING"
  else
    return chatType
  end
end

local function GetSoftResInfo( softRessers, f )
  return string.format( "(SR by %s)", M:TableToCommifiedPrettyString( softRessers, f ) )
end

local function Subtract( from, t )
  local result = {}

  for _, v in ipairs( from ) do
    if not M:TableContainsValue( t, v, function( entry ) return entry.name end ) then
      table.insert( result, v )
    end
  end

  return result
end

local function compose( f1, f2 )
  return function( value )
    return f2( f1( value ) )
  end
end

local function copy_roller( roller )
  return { name = roller.name, rolls = roller.rolls }
end

local function copy_rollers( t )
  local result = {}

  for k, v in pairs( t ) do
    result[ k ] = copy_roller( v )
  end

  return result
end

local function RollFor( whoCanRoll, count, item, seconds, info, reservedBy )
  m_rollers = whoCanRoll
  m_rolled_item = item
  m_rolled_item_count = count
  m_reserved_by = reservedBy
  local softResCount = reservedBy and M:CountElements( reservedBy ) or 0
  m_rolled_item_reserved = softResCount > 0

  local name_with_rolls = function( player )
    if softResCount == count then return player.name end
    local rolls = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
    return string.format( "%s%s", player.name, rolls )
  end

  if m_rolled_item_reserved and softResCount <= count then
    M:PrettyPrint( string.format( "%s is soft-ressed by %s.",
      softResCount < count and string.format( "%dx%s out of %d", softResCount, item, count ) or item,
      M:TableToCommifiedPrettyString( reservedBy, compose( name_with_rolls, highlight ) ) ) )

    api.SendChatMessage( string.format( "%s is soft-ressed by %s.",
      softResCount < count and string.format( "%dx%s out of %d", softResCount, item, count ) or item,
      M:TableToCommifiedPrettyString( reservedBy, name_with_rolls ) ), GetRollAnnouncementChatType() )

    m_rolled_item_count = count - softResCount
    info = string.format( "(everyone except %s can roll). /roll (MS) or /roll 99 (OS)",
      M:TableToCommifiedPrettyString( reservedBy, function( player ) return player.name end ) )
    m_rollers = Subtract( M:GetAllPlayersInMyGroup(), reservedBy )
    m_offspec_rollers = {}
  elseif softResCount > 0 then
    info = GetSoftResInfo( reservedBy, name_with_rolls )
  else
    if not info or info == "" then info = "/roll (MS) or /roll 99 (OS)" end
    m_offspec_rollers = copy_rollers( m_rollers )
  end

  ModUi.rollers = m_rollers
  ModUi.offspec_rollers = m_offspec_rollers

  if m_rolled_item_count == 0 or #m_rollers == 0 then
    StopRolling()
    return
  end

  m_winner_count = 0
  m_seconds_left = seconds
  m_rolls = {}
  m_offspec_rolls = {}

  local countInfo = ""

  if m_rolled_item_count > 1 then countInfo = string.format( " %d top rolls win.", m_rolled_item_count ) end

  api.SendChatMessage( string.format( "Roll for %s%s:%s%s",
    m_rolled_item_count > 1 and string.format( "%dx", m_rolled_item_count ) or "", item,
    (not info or info == "") and "." or string.format( " %s.", info ), countInfo ), GetRollAnnouncementChatType() )
  m_rerolling = false
  m_rolling = true
  m_timer = ModUi:ScheduleRepeatingTimer( OnTimer, 1.7 )
end

local function is_item_hard_ressed( item_id )
  return m_hardres_items[ item_id ]
end

local function announce_hr( item )
  api.SendChatMessage( string.format( "%s is hard-ressed.", item ), GetRollAnnouncementChatType() )
end

local function ProcessRollForSlashCommand( args, slashCommand, whoRolls )
  if not api.IsInGroup() then
    M:PrettyPrint( "Not in a group." )
    return
  end

  for itemCount, item, seconds, info in (args):gmatch "(%d*)[xX]?(|%w+|Hitem.+|r)%s*(%d*)%s*(.*)" do
    if m_rolling then
      M:PrettyPrint( "Rolling already in progress." )
      return
    end

    local count = (not itemCount or itemCount == "") and 1 or tonumber( itemCount )
    local item_id = M:GetItemId( item )
    local rollers, reservedByPlayers = whoRolls( item_id )

    if is_item_hard_ressed( item_id ) then
      announce_hr( item )
      return
    elseif seconds and seconds ~= "" and seconds ~= " " then
      local secs = tonumber( seconds )
      RollFor( rollers, count, item, secs <= 3 and 4 or secs, info, reservedByPlayers )
    else
      RollFor( rollers, count, item, 8, info, reservedByPlayers )
    end

    return
  end

  M:PrettyPrint( string.format( "Usage: %s <%s> [%s]", slashCommand, highlight( "item" ), highlight( "seconds" ) ) )
end

local function ProcessSoftShowSortedRollsSlashCommand( args )
  if m_rolling then
    M:PrettyPrint( "Rolling is in progress." )
    return
  end

  if not m_rolls or M:CountElements( m_rolls ) == 0 then
    M:PrettyPrint( "No rolls found." )
    return
  end

  for limit in (args):gmatch "(%d+)" do
    ShowSortedRolls( tonumber( limit ) )
    return
  end

  ShowSortedRolls( 5 )
end

local function DecorateWithRollingCheck( f )
  return function( ... )
    if not m_rolling then
      M:PrettyPrint( "Rolling not in progress." )
      return
    end

    f( ... )
  end
end

local function ProcessCancelRollSlashCommand()
  CancelRollingTimer()
  m_cancelled = true
  StopRolling()
  PrintRollingComplete()
end

local function ProcessFinishRollSlashCommand()
  FinalizeRolling( true )
end

local function SoftResDataExists()
  return not (m_softres_data == "" or M:CountElements( m_softres_items ) == 0)
end

local function CheckSoftRes()
  if not SoftResDataExists() then
    Report( "No soft-res data found." )
    return
  end

  local playersWhoDidNotSoftRes = GetPlayersWhoDidNotSoftRes()
  local absentPlayersWhoSoftRessed = GetAbsentPlayersWhoSoftRessed()

  if #playersWhoDidNotSoftRes == 0 then
    ReportSoftResReady()
  elseif #absentPlayersWhoSoftRessed == 0 then
    M:ScheduleTimer( function()
      CreateSoftResPassOptions()
      ShowSoftResPassOptions()
    end, 1 )
  else
    local predictions = GetSimilarityPredictions( playersWhoDidNotSoftRes, absentPlayersWhoSoftRessed, improvedDescending )
    local overrides, belowThresholdOverrides = AssignPredictions( predictions )

    for player, override in pairs( overrides ) do
      local overriddenName = override[ "override" ]
      local similarity = override[ "similarity" ]
      M:PrettyPrint( string.format( "Auto-matched %s to %s (%s similarity).", highlight( player ), highlight( overriddenName )
        ,
        similarity ) )
      m_softres_player_name_overrides[ overriddenName ] = { [ "override" ] = player, [ "similarity" ] = similarity }
    end

    if M:CountElements( belowThresholdOverrides ) > 0 then
      ---@diagnostic disable-next-line: param-type-mismatch
      for player, _ in pairs( belowThresholdOverrides ) do
        M:PrettyPrint( string.format( "%s Could not find soft-ressed item for %s.", red( "Warning!" ), highlight( player ) ) )
      end

      M:PrettyPrint( string.format( "Show soft-ressed items with %s command.", highlight( "/srs" ) ) )
      M:PrettyPrint( string.format( "Did they misspell their nickname? Check and fix it with %s command.",
        highlight( "/sro" ) ) )
      M:PrettyPrint( string.format( "If they don't want to soft-res, mark them with %s command.", highlight( "/srp" ) ) )
    end

    local count = GetPlayersWhoDidNotSoftRes()

    if #count == 0 then
      ReportSoftResReady()
    end
  end
end

local function ProcessSoftResCheckSlashCommand()
  CheckSoftRes()
end

local function clear_storage()
  ModUiDb.rollfor = {}
  ModUiDb.rollfor.softres_items = {}
  ModUiDb.rollfor.hardres_items = {}
  ModUiDb.rollfor.softres_player_name_overrides = {}
  ModUiDb.rollfor.softres_passing = {}
  ModUiDb.rollfor.softres_data = ""
  ModUiDb.rollfor.awarded_items = {}
  ModUiDb.rollfor.dropped_items = {}

  m_softres_items = ModUiDb.rollfor.softres_items
  m_hardres_items = ModUiDb.rollfor.hardres_items
  m_softres_player_name_overrides = ModUiDb.rollfor.softres_player_name_overrides
  m_softres_passing = ModUiDb.rollfor.softres_passing
  m_softres_data = ModUiDb.rollfor.softres_data
  m_awarded_items = ModUiDb.rollfor.awarded_items
  m_dropped_items = ModUiDb.rollfor.dropped_items
end

local function SetupStorage()
  ModUiDb.rollfor = ModUiDb.rollfor or {}

  -- For legacy data compatibility
  if ModUiDb.rollfor.softResItEncryptedData then
    clear_storage()

    M:PrettyPrint( string.format( "%s Soft-res data has been cleared. Please re-import if needed.", red( "WARNING!" ) ) )
  end

  -- Future-proof the data if we need to do the migration.
  if not ModUiDb.rollfor.version then
    ModUiDb.rollfor.version = version
  end

  ModUiDb.rollfor.softres_items = ModUiDb.rollfor.softres_items or {}
  m_softres_items = ModUiDb.rollfor.softres_items

  ModUiDb.rollfor.hardres_items = ModUiDb.rollfor.hardres_items or {}
  m_hardres_items = ModUiDb.rollfor.hardres_items

  ModUiDb.rollfor.softres_player_name_overrides = ModUiDb.rollfor.softres_player_name_overrides or {}
  m_softres_player_name_overrides = ModUiDb.rollfor.softres_player_name_overrides

  ModUiDb.rollfor.softres_passing = ModUiDb.rollfor.softres_passing or {}
  m_softres_passing = ModUiDb.rollfor.softres_passing

  ModUiDb.rollfor.softres_data = ModUiDb.rollfor.softres_data or ""
  m_softres_data = ModUiDb.rollfor.softres_data

  ModUiDb.rollfor.awarded_items = ModUiDb.rollfor.awarded_items or {}
  m_awarded_items = ModUiDb.rollfor.awarded_items

  ModUiDb.rollfor.dropped_items = ModUiDb.rollfor.dropped_items or {}
  m_dropped_items = ModUiDb.rollfor.dropped_items
end

local function ShowGui()
  m_softres_frame = AceGUI:Create( "Frame" )
  m_softres_frame.frame:SetFrameStrata( "DIALOG" )
  m_softres_frame:SetTitle( "SoftResLoot" )
  m_softres_frame:SetLayout( "Fill" )
  m_softres_frame:SetWidth( 565 )
  m_softres_frame:SetHeight( 300 )
  m_softres_frame:SetCallback( "OnClose",
    function( widget )
      if not m_softres_data_dirty then
        if not SoftResDataExists() then
          M:PrettyPrint( "Invalid or no soft-res data found." )
        else
          CheckSoftRes()
        end
      else
        UpdateData()
        CheckSoftRes()
      end

      AceGUI:Release( widget )
    end
  )

  m_softres_frame:SetStatusText( "" )

  local importEditBox = AceGUI:Create( "MultiLineEditBox" )
  importEditBox:SetFullWidth( true )
  importEditBox:SetFullHeight( true )
  importEditBox:DisableButton( true )
  importEditBox:SetLabel( "SoftRes.it data" )

  if m_softres_data then
    importEditBox:SetText( m_softres_data )
  end

  importEditBox:SetCallback( "OnTextChanged", function()
    m_softres_data_dirty = true
    m_softres_data = importEditBox:GetText()
  end )

  m_softres_frame:AddChild( importEditBox )
end

local function ProcessSoftResSlashCommand( args )
  if args == "init" then
    clear_storage()
    M:PrettyPrint( "Soft-res data cleared." )

    return
  end

  ShowGui()
end

local function has_rolls_left( player_name, offspec_roll )
  local rollers = offspec_roll and m_offspec_rollers or m_rollers

  for _, v in pairs( rollers ) do
    if v.name == player_name then
      return v.rolls > 0
    end
  end

  return false
end

local function subtract_roll( player_name, offspec )
  local rollers = offspec and m_offspec_rollers or m_rollers

  for _, v in pairs( rollers ) do
    if v.name == player_name then
      v.rolls = v.rolls - 1
      return
    end
  end
end

local function record_roll( player_name, roll, offspec )
  local rolls = offspec and m_offspec_rolls or m_rolls

  if not rolls[ player_name ] or rolls[ player_name ] < roll then
    rolls[ player_name ] = roll
  end
end

local function get_soft_ressing_players()
  local item_id = M:GetItemId( m_rolled_item )
  return m_softres_items[ item_id ]
end

local function has_player_soft_ressed( player )
  local soft_ressing_players = get_soft_ressing_players()
  if not soft_ressing_players then return false end

  for _, value in pairs( soft_ressing_players ) do
    if value.name == player then return true end
  end

  return false
end

local function OnRoll( player, roll, min, max )
  if not m_rolling or min ~= 1 or (max ~= 99 and max ~= 100) then return end

  local offspec_roll = max == 99
  local soft_ressed = M:CountElements( m_reserved_by ) > 0
  local soft_ressed_by_player = has_player_soft_ressed( player )

  if soft_ressed and not soft_ressed_by_player then
    M:PrettyPrint( string.format( "|cffff9f69%s|r did not SR %s. This roll (|cffff9f69%s|r) is ignored.", player, m_rolled_item, roll ) )
    return
  elseif soft_ressed and soft_ressed_by_player and offspec_roll then
    M:PrettyPrint( string.format( "|cffff9f69%s|r did SR %s, but rolled OS. This roll (|cffff9f69%s|r) is ignored.", player, m_rolled_item, roll ) )
    return
  elseif not has_rolls_left( player, offspec_roll ) then
    M:PrettyPrint( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player, roll ) )
    return
  end

  subtract_roll( player, offspec_roll )
  record_roll( player, roll, offspec_roll )

  if have_all_rolls_been_exhausted() then FinalizeRolling() end
end

local function OnChatMsgSystem( message )
  for player, roll, min, max in (message):gmatch( "([^%s]+) rolls (%d+) %((%d+)%-(%d+)%)" ) do
    OnRoll( player, tonumber( roll ), tonumber( min ), tonumber( max ) )
  end
end

local function VersionRecentlyReminded()
  if not ModUiDb.rollfor.last_new_version_reminder_timestamp then return false end

  local time = lua.time()

  -- Only remind once a day
  if time - ModUiDb.rollfor.last_new_version_reminder_timestamp > 3600 * 24 then
    return false
  else
    return true
  end
end

local function StripDots( v )
  local result, _ = v:gsub( "%.", "" )
  return result
end

local function IsNewVersion( v )
  local myVersion = tonumber( StripDots( version ) )
  local theirVersion = tonumber( StripDots( v ) )

  return theirVersion > myVersion
end

-- OnComm(prefix, message, distribution, sender)
local function OnComm( prefix, message, _, _ )
  if prefix ~= commPrefix then return end

  local cmd, value = lua.strmatch( message, "^(.*)::(.*)$" )

  if cmd == "VERSION" and IsNewVersion( value ) and not VersionRecentlyReminded() then
    ModUiDb.rollfor.last_new_version_reminder_timestamp = lua.time()
    M:PrettyPrint( string.format( "New version (%s) is available!", highlight( string.format( "v%s", value ) ) ) )
  end
end

local function BroadcastVersion( target )
  ModUi:SendCommMessage( commPrefix, "VERSION::" .. version, target )
end

local function BroadcastVersionToTheGuild()
  if not api.IsInGuild() then return end
  BroadcastVersion( "GUILD" )
end

local function BroadcastVersionToTheGroup()
  if not api.IsInGroup() and not api.IsInRaid() then return end
  BroadcastVersion( api.IsInRaid() and "RAID" or "PARTY" )
end

local function get_dropped_item_name( item_id )
  for _, item in pairs( m_dropped_items ) do
    if item.id == item_id then return item.name end
  end

  return nil
end

local function on_trade_complete( recipient, items_given, items_received )
  for i = 1, #items_given do
    local item = items_given[ i ]
    local item_id = item_utils.get_item_id( item.link )
    local item_name = get_dropped_item_name( item_id )

    if item_name then
      M.award_item( recipient, item_id, item_name, item.link )
    end
  end

  for i = 1, #items_received do
    local item = items_received[ i ]
    local item_id = item_utils.get_item_id( item.link )

    M.unaward_item( recipient, item_id, item.link )
  end
end

local function OnFirstEnterWorld()
  reset()

  -- Roll For commands
  SLASH_RF1 = "/rf"
  api.SlashCmdList[ "RF" ] = function( args ) ProcessRollForSlashCommand( args, "/rf", IncludeReservedRolls ) end
  SLASH_ARF1 = "/arf"
  api.SlashCmdList[ "ARF" ] = function( args ) ProcessRollForSlashCommand( args, "/arf", GetAllPlayers ) end
  SLASH_CR1 = "/cr"
  api.SlashCmdList[ "CR" ] = DecorateWithRollingCheck( ProcessCancelRollSlashCommand )
  SLASH_FR1 = "/fr"
  api.SlashCmdList[ "FR" ] = DecorateWithRollingCheck( ProcessFinishRollSlashCommand )

  -- Soft Res commands
  SLASH_SR1 = "/sr"
  api.SlashCmdList[ "SR" ] = ProcessSoftResSlashCommand
  SLASH_SSR1 = "/ssr"
  api.SlashCmdList[ "SSR" ] = ProcessSoftShowSortedRollsSlashCommand
  SLASH_SRS1 = "/srs"
  api.SlashCmdList[ "SRS" ] = ShowSoftRes
  SLASH_SRC1 = "/src"
  api.SlashCmdList[ "SRC" ] = ProcessSoftResCheckSlashCommand
  SLASH_SRO1 = "/sro"
  api.SlashCmdList[ "SRO" ] = SoftResPlayerNameOverride
  SLASH_SRUO1 = "/sruo"
  api.SlashCmdList[ "SRUO" ] = SoftResPlayerNameUnoverride
  SLASH_SRP1 = "/srp"
  api.SlashCmdList[ "SRP" ] = SoftResPass
  SLASH_SRUP1 = "/srup"
  api.SlashCmdList[ "SRUP" ] = SoftResUnpass

  SetupStorage()

  -- dataDirty = true
  -- local data = libStub:GetLibrary( "LibDeflate" ):CompressZlib( testJson )
  -- softResItEncryptedData = M:EncodeBase64( data )

  UpdateData( true )

  -- For testing:
  --MockFunctionsForTesting()

  BroadcastVersionToTheGuild()
  BroadcastVersionToTheGroup()
  ModUi:RegisterComm( commPrefix, OnComm )
  UpdateGroupStatus()

  M:PrettyPrint( string.format( "Loaded (%s).", highlight( string.format( "v%s", version ) ) ) )
end

local function OnJoinedGroup()
  if not wasInGroup then
    BroadcastVersionToTheGroup()
  end

  UpdateGroupStatus()
end

local function OnLeftGroup()
  UpdateGroupStatus()
end

local function Init()
  M.PrettyPrint = function( _, message ) chatFrame:AddMessage( string.format( "|cff209ff9RollFor|r: %s", message ) ) end
end

local function filter_softres_items()
  local result = {}

  for item_id, players in pairs( m_softres_items ) do
    local filtered_players = FilterPlayersWhoAlreadyReceivedTheItem( item_id,
      FilterAbsentPlayers( FilterSoftResPassingPlayers( OverridePlayerNames( players ) ) ) )

    if #filtered_players > 0 then
      result[ item_id ] = filtered_players
    end
  end

  return result
end

local function OnLootReady()
  if not M:IsPlayerMasterLooter() or m_announcing then return end

  local source_guid, items, announcements = dropped_loot_announce.process_dropped_items( filter_softres_items(), m_hardres_items )
  local was_announced = m_announced_source_ids[ source_guid ]
  if was_announced then return end

  m_announcing = true
  local item_count = #items

  local target = api.UnitName( "target" )
  local target_msg = target and not api.UnitIsFriend( "player", "target" ) and string.format( " by %s", target ) or ""

  if item_count > 0 then
    api.SendChatMessage( string.format( "%s item%s dropped%s:", item_count, item_count > 1 and "s" or "", target_msg ), M:GetGroupChatType() )

    for i = 1, item_count do
      local item = items[ i ]
      table.insert( m_dropped_items, { id = item.id, name = item.name } )
    end

    for i = 1, #announcements do
      api.SendChatMessage( announcements[ i ], M:GetGroupChatType() )
    end

    ModUiDb.rollfor.dropped_items = m_dropped_items
    m_announced_source_ids[ source_guid ] = true
  end

  m_announcing = false
end

---@diagnostic disable-next-line: unused-local, unused-function
local function OnPartyMessage( message, player )
  for name, roll in (message):gmatch( "(%a+) rolls (%d+)" ) do
    --M:Print( string.format( "Party: %s %s", name, message ) )
    OnRoll( name, tonumber( roll ), 1, 100 )
  end
  for name, roll in (message):gmatch( "(%a+) rolls os (%d+)" ) do
    --M:Print( string.format( "Party: %s %s", name, message ) )
    OnRoll( name, tonumber( roll ), 1, 99 )
  end
end

local function idempotent_hookscript( frame, event, callback )
  if not frame.RollForHookScript then
    frame.RollForHookScript = frame.HookScript

    frame.HookScript = function( self, _event, f )
      if _event:find( "RollForIdempotent", 1, true ) == 1 then
        if not frame[ _event ] then
          local real_event = _event:gsub( "RollForIdempotent", "" )
          frame.RollForHookScript( self, real_event, f )
          frame[ _event ] = true
        end
      else
        frame.RollForHookScript( self, _event, f )
      end
    end
  end

  frame:HookScript( "RollForIdempotent" .. event, callback )
end

local function find_loot_confirmation_details()
  local frames = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }

  for i = 1, #frames do
    local base_frame_name = frames[ i ]
    local frame = _G[ base_frame_name .. "Text" ]

    if frame and frame:IsVisible() and frame.text_arg1 and frame.text_arg2 then
      local yes_button = _G[ base_frame_name .. "Button1" ]
      local no_button = _G[ base_frame_name .. "Button2" ]

      return base_frame_name, yes_button, no_button
    end
  end

  return nil
end

local function hook_loot_confirmation_events( base_frame_name, yes_button, no_button )
  idempotent_hookscript( yes_button, "OnClick", function()
    local text_frame = _G[ base_frame_name .. "Text" ]
    local player = text_frame and text_frame.text_arg2
    local colored_item_name = text_frame and text_frame.text_arg1

    if player and colored_item_name then
      m_item_to_be_awarded = { player = player, colored_item_name = colored_item_name }
      m_item_award_confirmed = true
      M:PrettyPrint( string.format( "Attempting to award %s with %s.", m_item_to_be_awarded.player, m_item_to_be_awarded.colored_item_name ) )
    end
  end )

  idempotent_hookscript( no_button, "OnClick", function()
    m_item_award_confirmed = false
    m_item_to_be_awarded = nil
  end )
end

local function OnOpenMasterLootList()
  -- item name: StaticPopup1Text.text_arg1
  -- example: "|cffa334eeBlessed Tanzanite|r"

  for k, frame in pairs( api.MasterLooterFrame ) do
    if type( k ) == "string" and k:find( "player", 1, true ) == 1 then
      idempotent_hookscript( frame, "OnClick", function()
        local base_frame_name, yes_button, no_button = find_loot_confirmation_details()
        if base_frame_name and yes_button and no_button then
          hook_loot_confirmation_events( base_frame_name, yes_button, no_button )
        end
      end )
    end
  end
end

local function get_item_id( item_name )
  for _, item in pairs( m_dropped_items ) do
    if item.name == item_name then return item.id end
  end

  return nil
end

local function OnLootSlotCleared()
  if m_item_to_be_awarded and m_item_award_confirmed then
    local item_name = M:decolorize( m_item_to_be_awarded.colored_item_name )
    local item_id = get_item_id( item_name )

    if item_id then
      M.award_item( m_item_to_be_awarded.player, item_id, item_name, m_item_to_be_awarded.colored_item_name )
    else
      M:PrettyPrint( string.format( "Cannot determine item id for %s.", m_item_to_be_awarded.colored_item_name ) )
    end

    m_item_to_be_awarded = nil
    m_item_award_confirmed = false
  end
end

function M.award_item( player, item_id, item_name, item_link_or_colored_item_name )
  table.insert( m_awarded_items, { player = player, item_id = item_id, item_name = item_name } )
  ModUiDb.rollfor.awarded_items = m_awarded_items
  M:PrettyPrint( string.format( "%s received %s.", highlight( player ), item_link_or_colored_item_name ) )
end

---@diagnostic disable-next-line: unused-local, unused-function
local function remove_from_awarded_items( player, item_id )
  local result = {}

  for i = 1, #m_awarded_items do
    local item = m_awarded_items[ i ]
    if item.player ~= player or item.item_id ~= item_id then
      table.insert( result, item )
    end
  end

  return result
end

---@diagnostic disable-next-line: unused-local
function M.unaward_item( player, item_id, item_link_or_colored_item_name )
  --TODO: Think if we want to do this.
  --m_awarded_items = remove_from_awarded_items( player, item_id )
  --ModUiDb.rollfor.awarded_items = m_awarded_items
  M:PrettyPrint( string.format( "%s returned %s.", highlight( player ), item_link_or_colored_item_name ) )
end

function M.Initialize()
  Init()
  M:OnFirstEnterWorld( OnFirstEnterWorld )
  M:OnChatMsgSystem( OnChatMsgSystem )
  M:OnJoinedGroup( OnJoinedGroup )
  M:OnLeftGroup( OnLeftGroup )
  M:OnLootReady( OnLootReady )
  M:OnOpenMasterLootList( OnOpenMasterLootList )
  M:OnLootSlotCleared( OnLootSlotCleared )
  M:OnTradeComplete( on_trade_complete )

  -- For testing:
  --M:OnPartyMessage( OnPartyMessage )
  --M:OnPartyLeaderMessage( OnPartyMessage )
end

return M
