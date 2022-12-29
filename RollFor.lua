---@diagnostic disable: redefined-local
local ModUi = LibStub:GetLibrary( "ModUi-1.0", 3 )
local M = ModUi:NewModule( "RollFor" )
local version = "1.11"

---@diagnostic disable-next-line: undefined-global
local chatFrame = ChatFrame1

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
local m_loot_source_guid = nil
local m_announced_items = {}

local AceGUI = LibStub( "AceGUI-3.0" )
local frame = nil
--local testJson = "{\"id\":\"812469384114470972\",\"instance\":\"zg\",\"softreserves\":[{\"item\":6948,\"rollBonus\":0,\"name\":\"psikutas\",\"note\":\"\"},{\"item\":6948,\"rollBonus\":0,\"name\":\"Obszczymucha\",\"note\":\"\"},{\"item\":13446,\"rollBonus\":0,\"name\":\"Cykablyat\",\"note\":\"\"}],\"hardreserves\":[],\"note\":\"\",\"discord\":\"\"}"
local softResItEncryptedData = nil
local dataDirty = false
local m_softres_items = {}
local m_hardres_items = {}
local softResPlayerNameOverrides = {}
local softResPassing = {}
local softResPassOptions = nil
local softResUnpassOptions = nil
local softResPlayerNameOverrideOptions = nil
local softResPlayerNameUnoverrideOptions = nil
local softResItId = nil
local commPrefix = "ModUi-RollFor"
local wasInGroup = false

local api = ModUi.facade.api
local lua = ModUi.facade.lua

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
  for player, override in pairs( softResPlayerNameOverrides ) do
    if player ~= override and override == overridingPlayer then return true end
  end

  return false
end

local function IsPlayerSoftResPassing( player )
  if softResPassing[ player ] or softResPassing[ string.lower( player ) ] then
    return true
  else
    return false
  end
end

local function OverridePlayerNames( players )
  local result = {}

  for k, player in pairs( players ) do
    result[ k ] = softResPlayerNameOverrides[ player.name ] and { name = softResPlayerNameOverrides[ player.name ][ "override" ], rolls = player.rolls } or
        player
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

local function IncludeReservedRolls( itemId )
  local reservedByPlayers = FilterAbsentPlayers( FilterSoftResPassingPlayers( OverridePlayerNames( M:CloneTable( m_softres_items
    [ itemId ] ) ) ) ) -- If someone has been overriden

  local reserving_player_count = M:CountElements( reservedByPlayers )
  local rollers = reservedByPlayers and reserving_player_count > 0 and reservedByPlayers or GetAllPlayers()
  return rollers, reservedByPlayers, reserving_player_count
end

local function GetAbsentPlayersWhoSoftRessed()
  local result = {}

  for name, override in pairs( softResPlayerNameOverrides ) do
    if not M:IsPlayerInMyGroup( override[ "override" ] ) and not IsPlayerSoftResPassing( name ) then
      table.insert( result, override[ "override" ] )
    end
  end

  return result
end

local function HasPlayerSoftRessed( player )
  for _, override in pairs( softResPlayerNameOverrides ) do
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
  if not entries then return end

  for i = 1, #entries do
    local entry = entries[ i ]
    local items = entry.items

    for j = 1, #items do
      local id = items[ j ].id

      if not m_softres_items[ id ] then
        m_softres_items[ id ] = {}
      end

      add_soft_ressing_player( m_softres_items[ id ], entry.name )

      if not softResPlayerNameOverrides[ entry.name ] then
        softResPlayerNameOverrides[ entry.name ] = { [ "override" ] = entry.name, [ "similarity" ] = 0 }
      end
    end
  end
end

local function process_hardres_items( entries )
  if not entries then return end

  for i = 1, #entries do
    local id = entries[ i ].id

    if not m_hardres_items[ id ] then
      m_hardres_items[ id ] = 1
    end
  end
end

local function ProcessData( data )
  ModUi.dupa = data
  m_softres_items = {}
  m_hardres_items = {}

  if not data then
    M.data = nil
    ModUiDb.rollfor.softResItems = m_softres_items
    return
  end

  softResItId = data.metadata.id
  ModUiDb.rollfor.softResItId = softResItId
  process_softres_items( data.softreserves )
  process_hardres_items( data.hardreserves )

  ModUiDb.rollfor.softResItems = m_softres_items
  M.data = data
end

local function ShowSoftRes( args )
  local needsRefetch = false
  local items = {}

  for item, players in pairs( m_softres_items ) do
    local itemLink = M:GetItemLink( item )

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
  if not dataDirty then return end

  ModUiDb.rollfor.softResItEncryptedData = softResItEncryptedData

  local data = M:DecodeBase64( softResItEncryptedData )

  if data then
    data = LibStub:GetLibrary( "LibDeflate" ):DecompressZlib( data )
  end

  if data then
    data = ModUi.json.decode( data )
  end

  if data then
    ProcessData( data )
    if not silent then
      M:PrettyPrint( string.format( "Data loaded successfully. Use %s command to list.", highlight( "/srs" ) ) )
    else
      M:PrettyPrint( "Soft-res data active." )
    end
  else
    ProcessData( nil )
    if not silent then M:PrettyPrint( "Could not load soft-res data." ) end
  end

  dataDirty = false
end

local function ReportPlayersWhoDidNotSoftRes( players )
  if #players == 1 then
    Report( string.format( "%s, please soft-res now or whisper me the item you want to soft-res.", players[ 1 ] ) )
    return
  end

  local buffer = ""

  for i = 1, #players do
    local separator = ""
    if buffer ~= "" then
      separator = separator .. ", "
    else
      buffer = buffer .. "The following players did not soft-res: "
    end

    local nextPlayer = players[ i ]

    if (string.len( buffer .. separator .. nextPlayer ) > 255) then
      Report( buffer )
      buffer = nextPlayer
    else
      buffer = buffer .. separator .. nextPlayer
    end
  end

  if buffer ~= "" then
    Report( buffer )
  end

  Report( "Please soft-res now or whisper me the item you want to soft-res." )
end

local function ShowSoftResPlayerNameOverrideOptions()
  local players = softResPlayerNameOverrideOptions

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

local function ReportSoftResReady( silent )
  local url = string.format( "https://softres.it/raid/%s", softResItId )
  Report( string.format( "Soft-res url: %s.", silent and highlight( url ) or url ) )
  Report( "Soft-res setup is complete." )
end

local function CreateSoftResPlayerNameOverrideOptions()
  softResPlayerNameOverrideOptions = GetAbsentPlayersWhoSoftRessed()
end

local function SoftResPlayerNameOverride( args )
  if not softResPlayerNameOverrideOptions or not args or args == "" then
    CreateSoftResPlayerNameOverrideOptions()
    ShowSoftResPlayerNameOverrideOptions()
    return
  end

  local count = M:CountElements( softResPlayerNameOverrideOptions )
  local matched = false
  local target = api.UnitName( "target" )

  if target and IsPlayerAlreadyOverridingAName( target ) then
    softResPlayerNameOverrideOptions = nil
    local f = function( value )
      return function( v )
        return v[ "override" ] == value
      end
    end

    M:PrettyPrint( string.format( "Player |cffff2f2f%s|r is already overriding |cffff9f69%s|r!", target,
      M:GetKeyByValue( softResPlayerNameOverrides, f( target ) ) ) )
    return
  end

  for i in (args):gmatch "(%d+)" do
    if not matched then
      local index = tonumber( i )

      if index > 0 and index <= count and target then
        matched = true
        local player = softResPlayerNameOverrideOptions[ index ]
        softResPlayerNameOverrides[ player ] = { [ "override" ] = target, [ "similarity" ] = 0 }
        ModUiDb.rollfor.softResPlayerNameOverrides = softResPlayerNameOverrides

        M:PrettyPrint( string.format( "|cffff9f69%s|r is now soft-ressing as |cffff9f69%s|r.", target, player ) )
        local count = M:CountElements( softResPlayerNameOverrideOptions )

        if count == 0 then
          ReportSoftResReady()
        end
      end
    end
  end

  if matched then
    softResPlayerNameOverrideOptions = nil
  else
    CreateSoftResPlayerNameOverrideOptions()
    ShowSoftResPlayerNameOverrideOptions()
  end
end

local function CreateSoftResPlayerNameUnoverrideOptions()
  softResPlayerNameUnoverrideOptions = {}

  for player, override in pairs( softResPlayerNameOverrides ) do
    if player ~= override[ "override" ] then
      table.insert( softResPlayerNameUnoverrideOptions, player )
    end
  end
end

local function ShowSoftResPlayerNameUnoverrideOptions()
  local players = softResPlayerNameUnoverrideOptions

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
    local overrider = softResPlayerNameOverrides[ player ][ "override" ]
    local color = function( player ) return M:IsPlayerInMyGroup( player ) and "ffffff" or "ff2f2f" end
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
  if not softResPlayerNameUnoverrideOptions or not args or args == "" then
    CreateSoftResPlayerNameUnoverrideOptions()
    ShowSoftResPlayerNameUnoverrideOptions()
    return
  end

  local count = M:CountElements( softResPlayerNameUnoverrideOptions )

  for i in (args):gmatch "(%d+)" do
    local index = tonumber( i )

    if index > 0 and index <= count then
      local player = softResPlayerNameUnoverrideOptions[ index ]
      softResPlayerNameOverrides[ player ] = { [ "override" ] = player, [ "similarity" ] = 0 }
      ModUiDb.rollfor.softResPlayerNameOverrides = softResPlayerNameOverrides

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
  softResPassOptions = M:JoinTables( absentPlayersWhoSoftRessed, presentPlayersWhoDidNotSoftRes )
end

local function ShowSoftResPassOptions()
  if #softResPassOptions == 0 then
    M:PrettyPrint( "No one is soft-res passing on loot." )
    return
  end

  M:PrettyPrint( string.format( "To soft-res pass type |cffff9f69%s|r.", "/srp <numbers...>" ) )
  local buffer = ""

  for i = 1, #softResPassOptions do
    local separator = ""

    if buffer ~= "" then
      separator = separator .. ", "
    end

    local player = softResPassOptions[ i ]
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
  if not softResPassOptions or not args or args == "" then
    CreateSoftResPassOptions()
    ShowSoftResPassOptions()
    return
  end

  local count = M:CountElements( softResPassOptions )

  for i in (args):gmatch "(%d+)" do
    local index = tonumber( i )

    if index > 0 and index <= count then
      local player = softResPassOptions[ index ]
      softResPassing[ player ] = true
      ModUiDb.rollfor.softResPassing = softResPassing

      M:PrettyPrint( string.format( "|cff%s%s|r is not soft-ressing.", M:IsPlayerInMyGroup( player ) and "ff9f69" or "ff2f2f"
        ,
        player ) )
    end
  end

  CreateSoftResPassOptions()
  ShowSoftResPassOptions()

  if M:CountElements( softResPassOptions ) == 0 then
    ReportSoftResReady()
  end
end

local function CreateSoftResUnpassOptions()
  softResUnpassOptions = M:keys( M:filter( softResPassing, M.ValueIsTrue ) )
end

local function ShowSoftResUnpassOptions()
  local players = softResUnpassOptions

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
  if not softResUnpassOptions or not args or args == "" then
    CreateSoftResUnpassOptions()
    ShowSoftResUnpassOptions()
    return
  end

  local count = M:CountElements( softResUnpassOptions )

  for i in (args):gmatch "(%d+)" do
    local index = tonumber( i )

    if index > 0 and index <= count then
      local player = softResUnpassOptions[ index ]
      softResPassing[ player ] = false
      ModUiDb.rollfor.softResPassing = softResPassing

      M:PrettyPrint( string.format( "|cff%s%s|r is soft-ressing now.", M:IsPlayerInMyGroup( player ) and "ff2f2f" or "ff9f69"
        ,
        player ) )
    end
  end

  CreateSoftResUnpassOptions()
  ShowSoftResUnpassOptions()
end

local function ThereWasATie( topRoll, topRollers )
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
end

local function PrintRollingComplete()
  local itemsLeft = m_rolled_item_count > 0 and
      string.format( " (%d item%s left)", m_rolled_item_count, m_rolled_item_count > 1 and "s" or "" ) or ""
  M:PrettyPrint( string.format( "Rolling for %s has finished%s.", m_rolled_item, itemsLeft ) )
end

local function StopRolling()
  m_rolling = false
  PrintRollingComplete()
end

local function SortRolls( rolls )
  local function RollMap( rolls )
    local result = {}

    for _, roll in pairs( rolls ) do
      if not result[ roll ] then result[ roll ] = true end
    end

    return result
  end

  local function ToMap( rolls )
    local result = {}

    for k, v in pairs( rolls ) do
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

  local function Merge( sortedRolls, map )
    local result = {}

    for _, v in ipairs( sortedRolls ) do
      table.insert( result, map[ v ] )
    end

    return result
  end

  local sortedRolls = ToSortedRollsArray( RollMap( rolls ) )
  local map = ToMap( rolls )

  return Merge( sortedRolls, map )
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

local function have_all_rolls_been_exhausted()
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

local function process_sorted_rolls( sorted_rolls, forced, rolls_exhausted, is_offspec, fallback_fn )
  for _, v in ipairs( sorted_rolls ) do
    local roll = v[ "roll" ]
    local players = v[ "players" ]

    if m_rolled_item_count == #players then
      if m_rolled_item_reserved and not forced and not rolls_exhausted then
        PrintWinner( roll, players, is_offspec )
        announce_extra_rolls_left()
      else
        m_rolled_item_count = m_rolled_item_count - #players
        StopRolling()
        PrintWinner( roll, players, is_offspec )
      end

      return
    elseif m_rolled_item_count < #players and (rolls_exhausted or is_offspec) then
      ThereWasATie( roll, players )
      return
    else
      PrintWinner( roll, players, is_offspec )

      if forced then
        StopRolling()
      elseif m_rolled_item_reserved and not rolls_exhausted then
        announce_extra_rolls_left()
        return
      end

      m_rolled_item_count = m_rolled_item_count - #players
      m_winner_count = m_winner_count + 1

      if fallback_fn then
        fallback_fn()
      else
        StopRolling()
      end
    end
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
    return
  end

  local offspec_rolling = function() process_sorted_rolls( SortRolls( m_offspec_rolls ), forced, rolls_exhausted, true ) end

  if mainspec_roll_count > 0 then
    process_sorted_rolls( SortRolls( m_rolls ), forced, rolls_exhausted, false, offspec_rolling )
  else
    offspec_rolling()
  end
end

local function OnTimer()
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
  local softResCount = reservedBy and M:CountElements( reservedBy ) or 0
  m_rolled_item_reserved = softResCount > 0

  local name_with_rolls = function( player )
    if softResCount == count then return player.name end
    local rolls = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
    return string.format( "%s%s", player.name, rolls )
  end

  if m_rolled_item_reserved and softResCount <= count then
    M:PrettyPrint( string.format( "%s soft-ressed by %s.%s",
      softResCount < count and string.format( "%dx%s out of %d", softResCount, item, count ) or item,
      M:TableToCommifiedPrettyString( reservedBy, compose( name_with_rolls, highlight ) ), softResCount == count and " No need to roll." or "" ) )

    api.SendChatMessage( string.format( "%s soft-ressed by %s.%s",
      softResCount < count and string.format( "%dx%s out of %d", softResCount, item, count ) or item,
      M:TableToCommifiedPrettyString( reservedBy, name_with_rolls ), softResCount == count and " No need to roll." or "" ), GetRollAnnouncementChatType() )

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
    local itemId = M:GetItemId( item )
    local rollers, reservedByPlayers = whoRolls( itemId )

    if seconds and seconds ~= "" and seconds ~= " " then
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

local function ProcessCancelRollSlashCommand( args )
  CancelRollingTimer()
  StopRolling()
  local reason = args and args ~= "" and args ~= " " and string.format( " (%s)", args ) or ""
  api.SendChatMessage( string.format( "Rolling for %s cancelled%s.", m_rolled_item, reason ), M:GetGroupChatType() )
end

local function ProcessFinishRollSlashCommand()
  FinalizeRolling( true )
end

local function SoftResDataExists()
  return not (softResItEncryptedData == "" or M:CountElements( m_softres_items ) == 0)
end

local function CheckSoftRes( silent )
  if not SoftResDataExists() then
    Report( "No soft-res data found." )
    return
  end

  local playersWhoDidNotSoftRes = GetPlayersWhoDidNotSoftRes()
  local absentPlayersWhoSoftRessed = GetAbsentPlayersWhoSoftRessed()

  if #playersWhoDidNotSoftRes == 0 then
    ReportSoftResReady( silent and silent ~= "" or false )
  elseif #absentPlayersWhoSoftRessed == 0 then
    -- These players didn't soft res.
    if not silent then ReportPlayersWhoDidNotSoftRes( playersWhoDidNotSoftRes ) end

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
      softResPlayerNameOverrides[ overriddenName ] = { [ "override" ] = player, [ "similarity" ] = similarity }
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

    local playersWhoDidNotSoftRes = GetPlayersWhoDidNotSoftRes()

    if #playersWhoDidNotSoftRes == 0 then
      ReportSoftResReady( silent and silent ~= "" or false )
    end
  end
end

local function ProcessSoftResCheckSlashCommand( args )
  if args and args == "report" then
    CheckSoftRes( false )
  else
    CheckSoftRes( true )
  end
end

local function SetupStorage()
  if not ModUiDb.rollfor then
    ModUiDb.rollfor = {}
  end

  if not ModUiDb.rollfor.softResItems then
    ModUiDb.rollfor.softResItems = {}
  end

  if not ModUiDb.rollfor.softResPlayerNameOverrides then
    ModUiDb.rollfor.softResPlayerNameOverrides = {}
  end

  if not ModUiDb.rollfor.softResPassing then
    ModUiDb.rollfor.softResPassing = {}
  end

  if not ModUiDb.rollfor.softResItEncryptedData then
    ModUiDb.rollfor.softResItEncryptedData = ""
  end

  m_softres_items = ModUiDb.rollfor.softResItems
  softResPlayerNameOverrides = ModUiDb.rollfor.softResPlayerNameOverrides
  softResPassing = ModUiDb.rollfor.softResPassing
  softResItEncryptedData = ModUiDb.rollfor.softResItEncryptedData
  softResItId = ModUiDb.rollfor.softResItId
end

local function ShowGui()
  frame = AceGUI:Create( "Frame" )
  frame.frame:SetFrameStrata( "DIALOG" )
  frame:SetTitle( "SoftResLoot" )
  frame:SetLayout( "Fill" )
  frame:SetWidth( 565 )
  frame:SetHeight( 300 )
  frame:SetCallback( "OnClose",
    function( widget )
      if not dataDirty then
        if not SoftResDataExists() then
          M:PrettyPrint( "Invalid or no soft-res data found." )
        else
          CheckSoftRes( true )
        end
      else
        UpdateData()
        CheckSoftRes( true )
      end

      AceGUI:Release( widget )
    end
  )

  frame:SetStatusText( "" )

  local importEditBox = AceGUI:Create( "MultiLineEditBox" )
  importEditBox:SetFullWidth( true )
  importEditBox:SetFullHeight( true )
  importEditBox:DisableButton( true )
  importEditBox:SetLabel( "SoftRes.it data" )

  if softResItEncryptedData then
    importEditBox:SetText( softResItEncryptedData )
  end

  importEditBox:SetCallback( "OnTextChanged", function()
    dataDirty = true
    softResItEncryptedData = importEditBox:GetText()
  end )

  frame:AddChild( importEditBox )
end

local function ProcessSoftResSlashCommand( args )
  if args == "init" then
    ModUiDb.rollfor.softResItems = {}
    ModUiDb.rollfor.softResPlayerNameOverrides = {}
    ModUiDb.rollfor.softResPassing = {}
    ModUiDb.rollfor.softResItEncryptedData = ""
    ModUiDb.rollfor.softResItId = nil

    m_softres_items = ModUiDb.rollfor.softResItems
    softResPlayerNameOverrides = ModUiDb.rollfor.softResPlayerNameOverrides
    softResPassing = ModUiDb.rollfor.softResPassing
    softResItEncryptedData = ModUiDb.rollfor.softResItEncryptedData
    softResItId = ModUiDb.rollfor.softResItId
    M:PrettyPrint( "Soft-res data cleared." )

    return
  end

  ShowGui()
end

local function has_rolls_left( player_name )
  for _, v in pairs( m_rollers ) do
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

local function OnRoll( player, roll, min, max )
  if not m_rolling or min ~= 1 or (max ~= 99 and max ~= 100) then return end

  if not has_rolls_left( player ) then
    M:PrettyPrint( string.format( "|cffff9f69%s|r exhausted their rolls. This roll (|cffff9f69%s|r) is ignored.", player, roll ) )
    return
  end

  local offspec_roll = max == 99
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
  if not ModUiDb.rollfor.lastNewVersionReminder then return false end

  local time = lua.time()

  -- Only remind once a day
  if time - ModUiDb.rollfor.lastNewVersionReminder > 3600 * 24 then
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
    ModUiDb.rollfor.lastNewVersionReminder = lua.time()
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

local function OnFirstEnterWorld()
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
  -- local data = LibStub:GetLibrary( "LibDeflate" ):CompressZlib( testJson )
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

local function format_item_announcement( item_id, item_link )
  if m_hardres_items[ item_id ] then
    return string.format( "%s (HR)", item_link )
  elseif m_softres_items[ item_id ] then
    local _, reserving_players, reserving_players_count = IncludeReservedRolls( item_id )
    if reserving_players_count == 0 then
      return item_link
    else
      local name_with_rolls = function( player )
        local rolls = player.rolls > 1 and string.format( " [%s rolls]", player.rolls ) or ""
        return string.format( "%s%s", player.name, rolls )
      end

      return string.format( "%s %s", item_link, GetSoftResInfo( reserving_players, name_with_rolls ) )
    end
  else
    return item_link
  end
end

local function process_dropped_item( item_index )
  local link = api.GetLootSlotLink( item_index )
  if not link then return nil end

  local quality = select( 5, api.GetLootSlotInfo( item_index ) ) or 0
  if quality ~= 4 then return nil end

  local item_id = M:GetItemId( link )
  --M:Print( string.format( "%s %s %s", link, quality, item_id ) )

  return { id = item_id, link = link, quality = quality, message = format_item_announcement( item_id, link ) }
end

local function process_dropped_items()
  m_loot_source_guid = nil
  local result = {}
  local item_count = api.GetNumLootItems()

  for item_index = 1, item_count do
    m_loot_source_guid = m_loot_source_guid or api.GetLootSourceInfo( item_index )
    local item = process_dropped_item( item_index )

    if item then table.insert( result, item ) end
  end

  m_loot_source_guid = m_loot_source_guid or "unknown"
  return result
end

local function OnLootReady()
  if not M:IsPlayerMasterLooter() then return end

  local was_announced = function( item_id )
    return m_announced_items[ m_loot_source_guid ] and m_announced_items[ m_loot_source_guid ][ item_id ]
  end

  local items = process_dropped_items()
  local items_to_announce = M:filter( items, function( _, v ) return not was_announced( v.id ) end )
  local count = M:CountElements( items_to_announce )
  if count == 0 then return end

  local target = api.UnitName( "target" )
  local target_msg = target and api.UnitIsFriend( "player", "target" ) and string.format( " by %s", target ) or ""

  --M:Print( string.format( "source_guid: %s", m_loot_source_guid ) )

  api.SendChatMessage( string.format( "%s item%s dropped%s:", count, count > 1 and "s" or "", target_msg ), M:GetGroupChatType() )

  for i = 1, count do
    local item = items_to_announce[ i ]
    if not was_announced( item.id ) then
      api.SendChatMessage( string.format( "%s. %s", i, item.message ), M:GetGroupChatType() )
    end

    m_announced_items[ m_loot_source_guid ] = m_announced_items[ m_loot_source_guid ] or {}
    m_announced_items[ m_loot_source_guid ][ item.id ] = 1
  end
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

function M.Initialize()
  Init()
  M:OnFirstEnterWorld( OnFirstEnterWorld )
  M:OnChatMsgSystem( OnChatMsgSystem )
  M:OnJoinedGroup( OnJoinedGroup )
  M:OnLeftGroup( OnLeftGroup )
  M:OnLootReady( OnLootReady )

  -- For testing:
  --M:OnPartyMessage( OnPartyMessage )
  --M:OnPartyLeaderMessage( OnPartyMessage )
end
