local ModUi = LibStub:GetLibrary( "ModUi-1.0", 2 )
local M = ModUi:NewModule( "RollFor" )

local version = "0.1"

local timer = nil
local secondsLeft = nil
local itemOnRoll = nil
local itemOnRollCount = 0
local rolling = false
local reRolling = false
local rolls = {}
local rollers = {}
local winnerCount = 0

local AceGUI = LibStub("AceGUI-3.0")
local frame = nil
local testJson = "{\"id\":\"812469384114470972\",\"instance\":\"zg\",\"softreserves\":[{\"item\":6948,\"rollBonus\":0,\"name\":\"psikutas\",\"note\":\"\"},{\"item\":6948,\"rollBonus\":0,\"name\":\"Obszczymucha\",\"note\":\"\"},{\"item\":13446,\"rollBonus\":0,\"name\":\"Cykablyat\",\"note\":\"\"}],\"hardreserves\":[],\"note\":\"\",\"discord\":\"\"}"
local softResItEncryptedData = nil
local dataDirty = false
local softResItems = {}
local softResPlayerNameOverrides = {}
local softResPassing = {}
local softResPassOptions = nil
local softResUnpassOptions = nil
local softResPlayerNameOverrideOptions = nil
local softResPlayerNameUnoverrideOptions = nil
local softResItId = nil
local commPrefix = "ModUi-RollFor"
local wasInGroup = false

local function UpdateGroupStatus()
	wasInGroup = IsInGroup() or IsInRaid()
end

local highlight = function( word )
    return format( "|cffff9f69%s|r", word )
end

local red = function( word )
    return format( "|cffff2f2f%s|r", word )
end

local function Report( text, silent )
    if IsInRaid() and not silent then
        SendChatMessage( text, "RAID" )
    elseif IsInGroup() and not silent then
        SendChatMessage( text, "PARTY" )
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
                    ssnc = ssnc + ( 2 * i ) ^ 2
                    s1 = string.sub( s1, 0, j - 1 ) .. string.sub( s1, j + i )
                    s2 = string.sub( s2, 0, foundAt - 1 ) .. string.sub( s2, foundAt + i )
                    break
                end
            end
        end
    end

    return ( ssnc / ( ( n + m ) ^ 2 ) ) ^ ( 1 / 2 )
end

local function Levenshtein( s1, s2 )
    local len1 = #s1
    local len2 = #s2
    local matrix = {}
    local cost = 1
    local min = math.min;

    -- quick cut-offs to save time
    if ( len1 == 0 ) then
        return len2
    elseif ( len2 == 0 ) then
        return len1
    elseif ( s1 == s2 ) then
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
            if ( s1:byte( i ) == s2:byte( j ) ) then
                cost = 0
            end

            matrix[ i ][ j ] = min( matrix[ i - 1 ][ j ] + 1, matrix[ i ][ j - 1 ] + 1, matrix[ i - 1 ][ j - 1 ] + cost )
        end
    end

    -- return the last value - this is the Levenshtein distance
    return matrix[ len1 ][ len2 ]
end

local function improvedDescending( l, r )
    return l[ "levenshtein" ] < r[ "levenshtein"] or l[ "levenshtein" ] == r[ "levenshtein" ] and l[ "similarity" ] > r[ "similarity" ]
end

local function descending( l, r )
    return l[ "similarity" ] > r[ "similarity" ]
end

local function GetSimilarityPredictions( playersInGroupWhoDidNotSoftRes, playersNotInGroupWhoSoftRessed, sort )
    local results = {}

    for _, player in pairs( playersInGroupWhoDidNotSoftRes ) do
        local predictions = {}

        for _, candidate in pairs( playersNotInGroupWhoSoftRessed ) do
            local prediction = { [ "candidate" ] = candidate, [ "similarity" ] = StringSimilarity( player, candidate ), [ "levenshtein" ] = Levenshtein( player, candidate ) } 
            table.insert( predictions, prediction )
        end

        table.sort( predictions, sort )
        results[ player ] = predictions
    end

    return results
end

local function endsWith( str, ending )
    return ending == "" or str:sub( -#ending ) == ending
 end

function formatPercent( value )
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

        local override = { [ "override" ] = topCandidate[ "candidate" ], [ "similarity" ] = formatPercent( similarity ), [ "levenshtein" ] = levenshtein }

        if similarity >= 0.65 then
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
    if softResPassing[ player ] or softResPassing[ string.lower( player) ] then
        return true
    else
        return false
    end
end

local function OverridePlayerNames( players )
    local result = {}

    for k, player in pairs( players ) do
        result[ k ] = softResPlayerNameOverrides[ player ] and softResPlayerNameOverrides[ player ][ "override" ] or player
    end

    return result
end

local function FilterSoftResPassingPlayers( players )
    local rolling = {}
    local passing = {}

    for _, player in pairs( players ) do
        if not IsPlayerSoftResPassing( player ) then
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
        if M:IsPlayerInMyGroup( player ) then
            table.insert( present, player )
        else
            table.insert( absent, player )
        end
    end

    return present, absent
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
    for name, override in pairs( softResPlayerNameOverrides ) do
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

local function ProcessData( data )
    softResItems = {}
    
    if not data then
        M.data = nil
        ModUiDb.rollfor.softResItems = softResItems
        return
    end

    softResItId = data.id
    ModUiDb.rollfor.softResItId = softResItId

    for i=1, #data.softreserves do
        local entry = data.softreserves[ i ]

        if not softResItems[ entry.item ] then
            softResItems[ entry.item ] = {}
        end

        if not M:TableContainsValue( softResItems[ entry.item ], entry.name ) then table.insert( softResItems[ entry.item ], entry.name ) end
        if not softResPlayerNameOverrides[ entry.name ] then softResPlayerNameOverrides[ entry.name ] = { [ "override" ] = entry.name, [ "similarity" ] = 0 } end
    end

    ModUiDb.rollfor.softResItems = softResItems
    M.data = data
end

local function ShowSoftRes( args )
    local needsRefetch = false
    local items = {}

    for item, players in pairs( softResItems ) do
        local itemLink = M:GetItemLink( item )

        if not itemLink then
            needsRefetch = true
        else
            items[ itemLink ] = FilterSoftResPassingPlayers( OverridePlayerNames( players ) )
        end
    end

    local silent = not ( args and args == "report" )

    if needsRefetch then
        M:DebugMsg( "Not all items were fetched. Retrying...", silent )
        M:ScheduleTimer( ShowSoftRes, 1 )
        return
    end

    if M:CountElements( items ) == 0 then
        Report( "No soft-res items found.", silent )
        return
    end

    Report( "Soft-ressed items (red players are not in your group):", silent )
    local colorize = function( player ) return format( "|cff%s%s|r", M:IsPlayerInMyGroup( player ) and "ffffff" or "ff2f2f", player ) end

    for itemLink, players in pairs( items ) do
        if M:CountElements( players ) > 0 then
            Report( format( "%s: %s", itemLink, M:TableToCommifiedPrettyString( players, colorize ) ), silent )
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
            M:PrettyPrint( format( "Data loaded successfully. Use %s command to list.", highlight( "/srs" ) ) )
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
        Report( format( "%s, please soft-res now or whisper me the item you want to soft-res.", players[ 1 ] ) )
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

        if ( string.len( buffer .. separator .. nextPlayer ) > 255 ) then
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

local function ReportPlayersWithPossibleDiscordNames( players )
    if #players == 1 then
        Report( format( "Has anyone soft-ressed with this Discord name: %s?", players[ 1 ] ) )
        return
    end

    Report( "Has anyone soft-ressed with these Discord names?" )

    local buffer = ""

    for i = 1, #players do
        local separator = ""
        if buffer ~= "" then
            separator = separator .. ", "
        end

        local nextPlayer = players[ i ]

        if ( string.len( buffer .. separator .. nextPlayer ) > 255 ) then
            Report( buffer )
            buffer = nextPlayer
        else
            buffer = buffer .. separator .. nextPlayer
        end
    end

    if buffer ~= "" then
        Report( buffer )
    end
end

local function ShowSoftResPlayerNameOverrideOptions()
    local players = softResPlayerNameOverrideOptions
    
    if M:CountElements( players ) == 0 then
        M:PrettyPrint( "There are no players that can be overridden." )
        return
    end

    M:PrettyPrint( format( "Target a player and type |cffff9f69%s|r.", "/sro <number>" ) )
    local buffer = ""

    for i = 1, #players do
        local separator = ""
        if buffer ~= "" then
            separator = separator .. ", "
        end

        local nextPlayer = format( "[|cffff9f69%d|r]:|cffff2f2f%s|r", i, players[ i ] )

        if ( string.len( buffer .. separator .. nextPlayer ) > 255 ) then
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
    local url = format( "https://softres.it/raid/%s", softResItId )
    Report( format( "Soft-res url: %s.", silent and highlight( url ) or url ), silent )
    Report( "Soft-res setup is complete.", true )
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
    local target = UnitName( "target" )

    if target and IsPlayerAlreadyOverridingAName( target ) then
        softResPlayerNameOverrideOptions = nil
        local f = function( value )
            return function( v )
                return v[ "override"] == value
            end
        end

        M:PrettyPrint( format( "Player |cffff2f2f%s|r is already overriding |cffff9f69%s|r!", target, M:GetKeyByValue( softResPlayerNameOverrides, f( target ) ) ) )
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

                M:PrettyPrint( format( "|cffff9f69%s|r is now soft-ressing as |cffff9f69%s|r.", target, player ) )
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

    M:PrettyPrint( format( "To unoverride type |cffff9f69%s|r.", "/sruo <numbers...>" ) )
    local buffer = ""

    for i = 1, #players do
        local separator = ""
        if buffer ~= "" then
            separator = separator .. ", "
        end

        local player = players[ i ]
        local overrider = softResPlayerNameOverrides[ player ][ "override" ]
        local color = function( player ) return M:IsPlayerInMyGroup( player ) and "ffffff" or "ff2f2f" end
        local nextPlayer = format( "[|cffff9f69%d|r]:|cff%s%s|r (|cff%s%s|r)", i, color( player ), player, color( overrider ), overrider )

        if ( string.len( buffer .. separator .. nextPlayer ) > 255 ) then
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
    local matched = false

    for i in (args):gmatch "(%d+)" do
        local index = tonumber( i )

        if index > 0 and index <= count then
            matched = true
            local player = softResPlayerNameUnoverrideOptions[ index ]
            softResPlayerNameOverrides[ player ] = { [ "override" ] = player, [ "similarity" ] = 0 }
            ModUiDb.rollfor.softResPlayerNameOverrides = softResPlayerNameOverrides

            M:PrettyPrint( format( "|cffff9f69%s|r's name is no longer soft-res overridden.", player ) )
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

    M:PrettyPrint( format( "To soft-res pass type |cffff9f69%s|r.", "/srp <numbers...>" ) )
    local buffer = ""

    for i = 1, #softResPassOptions do
        local separator = ""

        if buffer ~= "" then
            separator = separator .. ", "
        end

        local player = softResPassOptions[ i ]
        local nextPlayer = format( "[|cffff9f69%d|r]:|cff%s%s|r", i, M:IsPlayerInMyGroup( player ) and "ffffff" or "ff2f2f", player )

        if ( string.len( buffer .. separator .. nextPlayer ) > 255 ) then
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

    local matched = false
    local count = M:CountElements( softResPassOptions )

    for i in (args):gmatch "(%d+)" do
        local index = tonumber( i )

        if index > 0 and index <= count then
            matched = true
            local player = softResPassOptions[ index ]
            softResPassing[ player ] = true
            ModUiDb.rollfor.softResPassing = softResPassing

            M:PrettyPrint( format( "|cff%s%s|r is not soft-ressing.", M:IsPlayerInMyGroup( player ) and "ff9f69" or "ff2f2f", player ) )
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

    M:PrettyPrint( format( "To soft-res unpass type |cffff9f69%s|r.", "/srup <numbers...>" ) )
    local buffer = ""

    for i = 1, #players do
        local separator = ""

        if buffer ~= "" then
            separator = separator .. ", "
        end

        local player = players[ i ]
        local nextPlayer = format( "[|cffff9f69%d|r]:|cff%s%s|r", i, M:IsPlayerInMyGroup( player ) and "ffffff" or "ff2f2f", player )

        if ( string.len( buffer .. separator .. nextPlayer ) > 255 ) then
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
    local matched = false

    for i in (args):gmatch "(%d+)" do
        local index = tonumber( i )

        if index > 0 and index <= count then
            matched = true
            local player = softResUnpassOptions[ index ]
            softResPassing[ player ] = false
            ModUiDb.rollfor.softResPassing = softResPassing

            M:PrettyPrint( format( "|cff%s%s|r is soft-ressing now.", M:IsPlayerInMyGroup( player ) and "ff2f2f" or "ff9f69", player ) )
        end
    end

    CreateSoftResUnpassOptions()
    ShowSoftResUnpassOptions()
end

local function TopRollersToString( topRollers, colorStart, colorEnd )
    local result = ""

    for i = 1, #topRollers - 1 do
        if result ~= "" then
            result = result .. ", "
        end

        result = result .. format( "%s%s%s", colorStart or "", topRollers[ i ], colorEnd or "" )
    end

    result = result .. " and " .. format( "%s%s%s", colorStart or "", topRollers[ #topRollers ], colorEnd or "" )
    return result
end

local function ThereWasATie( topRoll, topRollers )
    local topRollersStr = M:TableToCommifiedPrettyString( topRollers )
    local topRollersStrColored = M:TableToCommifiedPrettyString( topRollers, highlight )

    M:PrettyPrint( format( "The %shighest %sroll was %d by %s.", not reRolling and winnerCount > 0 and "next " or "", reRolling and "re-" or "", topRoll, topRollersStrColored, itemOnRoll), M:GetGroupChatType() )
    SendChatMessage( format( "The %shighest %sroll was %d by %s.", not reRolling and winnerCount > 0 and "next " or "", reRolling and "re-" or "", topRoll, topRollersStr, itemOnRoll), M:GetGroupChatType() )
    rolls = {}
    rollers = topRollers
    reRolling = true
    rolling = true
    ModUi:ScheduleTimer( function() SendChatMessage( format( "%s re-roll for %s now.", topRollersStr, itemOnRoll), M:GetGroupChatType() ) end, 2.5 )
end

local function StopRolling()
    ModUi:CancelTimer( timer )
    rolling = false
end

local function SortRolls( rolls )
    local function RollMap( rolls )
        local result = {}

        for player, roll in pairs( rolls ) do
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

        for k, v in ipairs( sortedRolls ) do
            table.insert( result, map[ v ] )
        end

        return result
    end

    sortedRolls = ToSortedRollsArray( RollMap( rolls ) )
    map = ToMap( rolls )

    return Merge( sortedRolls, map )
end

local function ShowSortedRolls( limit )
    local sortedRolls = SortRolls( rolls )
    i = 1

    M:PrettyPrint( "Rolls:" )

    for k, v in ipairs( sortedRolls ) do
        if limit and limit > 0 and i > limit then return end

        M:PrettyPrint( format( "[|cffff9f69%d|r]: %s", v[ "roll" ], M:TableToCommifiedPrettyString( v[ "players" ] ) ) )
        i = i + 1
    end
end

local function PrintWinner( roll, players )
    local f = highlight

    M:PrettyPrint( format( "%s %srolled the %shighest (%s) for %s.", M:TableToCommifiedPrettyString( players, f ), reRolling and "re-" or "", not reRolling and winnerCount > 0 and "next " or "", f( roll ), itemOnRoll ) )
    SendChatMessage( format( "%s %srolled the %shighest (%d) for %s.", M:TableToCommifiedPrettyString( players ), reRolling and "re-" or "", not reRolling and winnerCount > 0 and "next " or "", roll, itemOnRoll ), M:GetGroupChatType() )
end

local function PrintRollingComplete()
    local itemsLeft = itemOnRollCount > 0 and format( " (%d item%s left)", itemOnRollCount, itemOnRollCount > 1 and "s" or "" ) or ""
    M:PrettyPrint( format( "Rolling for %s has finished%s.", itemOnRoll, itemsLeft ) )
end

local function FinalizeRolling()
    StopRolling()

    if M:CountElements( rolls ) == 0 then
        M:PrettyPrint( format( "Nobody rolled for %s.", itemOnRoll ) )
        SendChatMessage( format( "Nobody rolled for %s.", itemOnRoll ), M:GetGroupChatType() )
        PrintRollingComplete()
        return
    end

    local sortedRolls = SortRolls( rolls )

    for k, v in ipairs( sortedRolls ) do
        local roll = v[ "roll" ]
        local players = v[ "players" ]

        if itemOnRollCount == #players then
            PrintWinner( roll, players )
            itemOnRollCount = itemOnRollCount - #players
            PrintRollingComplete()
            return
        elseif itemOnRollCount < #players then
            ThereWasATie( roll, players )
            return
        else
            PrintWinner( roll, players )
            itemOnRollCount = itemOnRollCount - #players
            winnerCount = winnerCount + 1
        end
    end

    PrintRollingComplete()
end

local function OnTimer()
    secondsLeft = secondsLeft - 1

    if secondsLeft <= 0 then
        FinalizeRolling()
    elseif secondsLeft == 3 then
        SendChatMessage( "Stopping rolls in 3", M:GetGroupChatType() )
    elseif secondsLeft < 3 then
        SendChatMessage( secondsLeft, M:GetGroupChatType() )
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

local function GetSoftResInfo( softRessers )
    return format( "(soft-ressed by: %s)", M:TableToCommifiedPrettyString( softRessers ) )
end

local function Subtract( from, t )
    local result = {}

    for _, v in ipairs( from ) do
        if not M:TableContainsValue( t, v ) then
            table.insert( result, v )
        end
    end

    return result
end

local function RollFor( whoCanRoll, count, item, seconds, info, softRes )
    rollers = whoCanRoll
    itemOnRoll = item
    itemOnRollCount = count
    local softResCount = softRes and #softRes or 0

    if softResCount > 0 and softResCount <= count then
        M:PrettyPrint( format( "%s soft-ressed by %s.", softResCount < count and format( "%dx%s out of %d", softResCount, item, count ) or item, M:TableToCommifiedPrettyString( softRes, highlight ) ) )
        SendChatMessage( format( "%s soft-ressed by %s.", softResCount < count and format( "%dx%s out of %d", softResCount, item, count ) or item, M:TableToCommifiedPrettyString( softRes ) ), GetRollAnnouncementChatType() )
        itemOnRollCount = count - softResCount
        info = format( "(everyone except %s can roll)", M:TableToCommifiedPrettyString( softRes ) )
        rollers = Subtract( M:GetAllPlayersInMyGroup(), softRes )
    elseif softResCount > 0 then
        info = GetSoftResInfo( softRes )
    end

    if itemOnRollCount == 0 or #rollers == 0 then
        PrintRollingComplete()
        return
    end

    winnerCount = 0
    secondsLeft = seconds
    rolls = {}

    local countInfo = ""

    if itemOnRollCount > 1 then countInfo = format( " %d top rolls win.", itemOnRollCount ) end

    SendChatMessage( format( "Roll for %s%s%s%s", itemOnRollCount > 1 and format( "%dx", itemOnRollCount ) or "", item, ( not info or info == "" ) and "." or format( " %s.", info ), countInfo ), GetRollAnnouncementChatType() )
    reRolling = false
    rolling = true
    timer = ModUi:ScheduleRepeatingTimer( OnTimer, 1.7 )
end

local function IncludeReservedRolls( itemId )
    local reservedByPlayers = FilterAbsentPlayers( FilterSoftResPassingPlayers( OverridePlayerNames( M:CloneTable( softResItems[ itemId ] ) ) ) ) -- If someone has been overriden
    local rollers = reservedByPlayers and M:CountElements( reservedByPlayers ) > 0 and reservedByPlayers or M:GetAllPlayersInMyGroup()

    return rollers, reservedByPlayers
end

local function ProcessRollForSlashCommand( args, slashCommand, whoRolls )
    if not IsInGroup() then
        M:PrettyPrint( "Not in a group." )
        return
    end

    for itemCount, item, seconds, info in (args):gmatch "(%d*)[xX]?(|%w+|Hitem.+|r)%s*(%d*)%s*(.*)" do
        if rolling then
            M:PrettyPrint( "Rolling already in progress." )
            return
        end

        local count = 1
        if itemCount and itemCount ~= "" then count = tonumber( itemCount ) end

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

    M:PrettyPrint( format( "Usage: %s <%s> [%s]", slashCommand, highlight( "item" ), highlight( "seconds" ) ) )
end

local function ProcessSoftShowSortedRollsSlashCommand( args )
    if rolling then
        M:PrettyPrint( "Rolling is in progress." )
        return
    end

    if not rolls or M:CountElements( rolls ) == 0 then
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
        if not rolling then
            M:PrettyPrint( "Rolling not in progress." )
            return
        end

        f( ... )
    end
end

local function ProcessCancelRollSlashCommand( args )
    StopRolling()
    local reason = args and args ~= "" and args ~= " " and format( " (%s)", args) or ""
    SendChatMessage( format( "Rolling for %s cancelled%s.", itemOnRoll, reason ), M:GetGroupChatType() )
end

local function ProcessFinishRollSlashCommand( args )
    local reason = args and args ~= "" and args ~= " " and format( " (%s)", args) or ""

    if secondsLeft < 4 then
        SendChatMessage( format( "Finishing rolls early%s.", reason ), M:GetGroupChatType() )
    end

    FinalizeRolling()
end

local function SoftResDataExists()
    return not ( softResItEncryptedData == "" or M:CountElements( softResItems ) == 0 )
end

local function CheckSoftRes( silent )
    if not SoftResDataExists() then
        Report( "No soft-res data found.", true )
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
        -- if not silent then ReportPlayersWithPossibleDiscordNames( absentPlayersWhoSoftRessed ) end

        -- M:ScheduleTimer( function()
        --     CreateSoftResPlayerNameOverrideOptions()
        --     ShowSoftResPlayerNameOverrideOptions()
        --     CreateSoftResPassOptions()
        --     ShowSoftResPassOptions()
        -- end, 1 )
        local predictions = GetSimilarityPredictions( playersWhoDidNotSoftRes, absentPlayersWhoSoftRessed, improvedDescending )

        -- for k, v in pairs( predictions ) do
        --     for _, value in ipairs( v ) do
        --         M:PrettyPrint( format( "%s: %s %s %s", k, value[ "candidate" ], value[ "similarity" ], value[ "levenshtein" ] ) )
        --     end
        -- end

        local overrides, belowThresholdOverrides = AssignPredictions( predictions )

        for player, override in pairs( overrides ) do
            local overriddenName = override[ "override" ]
            local levenshtein = format( "L%s", override[ "levenshtein" ] )
            local similarity = override[ "similarity"]
            M:PrettyPrint( format( "Auto-matched %s to %s (%s, %s similarity).", highlight( player ), highlight( overriddenName ), levenshtein, similarity ) )
            softResPlayerNameOverrides[ overriddenName ] = { [ "override" ] = player, [ "similarity" ] = similarity, [ "levenshtein" ] = levenshtein }
        end

        if M:CountElements( belowThresholdOverrides ) > 0 then
            for player, override in pairs( belowThresholdOverrides ) do
                M:PrettyPrint( format( "%s Could not find soft-ressed item for %s.", red( "Warning!" ), highlight( player ) ) )
            end

            M:PrettyPrint( format( "Show soft-ressed items with %s command.", highlight( "/srs" ) ) )
            M:PrettyPrint( format( "Did they misspell their nickname? Check and fix it with %s command.", highlight( "/sro" ) ) )
            M:PrettyPrint( format( "If they don't want to soft-res, mark them with %s command.", highlight( "/srp" ) ) )
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

    softResItems = ModUiDb.rollfor.softResItems
    softResPlayerNameOverrides = ModUiDb.rollfor.softResPlayerNameOverrides
    softResPassing = ModUiDb.rollfor.softResPassing
    softResItEncryptedData = ModUiDb.rollfor.softResItEncryptedData
    softResItId = ModUiDb.rollfor.softResItId
end

local function AddManualSoftRes( item )
    if not UnitName( "target" ) then
        M:PrettyPrint( format( "Target a player and type |cffff9f69%s|r.", "/sradd <item>" ) )
        return
    end
end

local function SoftResInvite()
    local count = 0

    for name, override in pairs( softResPlayerNameOverrides ) do
        if override[ "override" ] ~= UnitName( "player" ) and not M:IsPlayerInMyGroup( override[ "override" ] ) then
            InviteUnit( override )
            count = count + 1
        end
    end

    M:ScheduleTimer( function() M:PrettyPrint( format( "Invited %d players.", count ) ) end, 1 )
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
    for item in (args):gmatch "(|%w+|Hitem.+|r)" do
        AddManualSoftRes( item )
        return
    end

    if args == "init" then
        ModUiDb.rollfor.softResItems = {}
        ModUiDb.rollfor.softResPlayerNameOverrides = {}
        ModUiDb.rollfor.softResPassing = {}
        ModUiDb.rollfor.softResItEncryptedData = ""
        ModUiDb.rollfor.softResItId = nil

        softResItems = ModUiDb.rollfor.softResItems
        softResPlayerNameOverrides = ModUiDb.rollfor.softResPlayerNameOverrides
        softResPassing = ModUiDb.rollfor.softResPassing
        softResItEncryptedData = ModUiDb.rollfor.softResItEncryptedData
        softResItId = ModUiDb.rollfor.softResItId
        M:PrettyPrint( "Soft-res data cleared." )

        return
    end

    ShowGui()
end

local function OnRoll( player, roll, min, max )
    if not rolling or min ~= 1 or max ~= 100 then return end

    if rolls[ player ] then
        M:PrettyPrint( format( "|cffff9f69%s|r double rolled.", player ) )
        return
    end

    if M:TableContainsValue( rollers, player ) then
        rolls[ player ] = roll
        M:RemoveValueFromTableIgnoreCase( rollers, player )
    end

    local rollersLeft = M:CountElements( rollers )

    if rollersLeft == 0 then
        FinalizeRolling()
    end
end

local function OnChatMsgSystem( message )
    for player, roll, min, max in (message):gmatch ( "([^%s]+) rolls (%d+) %((%d+)%-(%d+)%)") do
        OnRoll( player, tonumber( roll ), tonumber( min ), tonumber( max ) )
    end
end

local function MockFunctionsForTesting()
    softResItems = { [6948] = { "Psikutas", "Haxxramas", "Xolt" } }
    M.IsPlayerInMyGroup = function( self, player ) return true end
    M.GetAllPlayersInMyGroup = function( self ) return { "Cyakbylat", "Xolt", "Psikutas" } end
end

local function VersionRecentlyReminded()
    if not ModUiDb.rollfor.lastNewVersionReminder then return false end

    local time = time()

    if time - ModUiDb.rollfor.lastNewVersionReminder > 30 then
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

local function OnComm( prefix, message, distribution, sender )
	if prefix ~= commPrefix then return end

    local cmd, value = strmatch( message, "^(.*)::(.*)$" )

    if cmd == "VERSION" and IsNewVersion( value ) and not VersionRecentlyReminded() then
        ModUiDb.rollfor.lastNewVersionReminder = time()
        M:PrettyPrint( format( "New version (%s) is available!", highlight( format( "v%s", value ) ) ) )
    end
end

local function BroadcastVersion( target )
    ModUi:SendCommMessage( commPrefix, "VERSION::" .. version, target )
end

local function BroadcastVersionToTheGuild()
	if not IsInGuild() then return end
	BroadcastVersion( "GUILD" )
end

local function BroadcastVersionToTheGroup()
    if not IsInGroup() and not IsInRaid() then return end
    BroadcastVersion( IsInRaid() and "RAID" or "PARTY" )
end

local function OnFirstEnterWorld()
    SLASH_SR1 = "/sr"
    SlashCmdList[ "SR" ] = ProcessSoftResSlashCommand
    SLASH_SSR1 = "/ssr"
    SlashCmdList[ "SSR" ] = ProcessSoftShowSortedRollsSlashCommand
    SLASH_RF1 = "/rf"
    SlashCmdList[ "RF" ] = function( args ) ProcessRollForSlashCommand( args, "/rf", IncludeReservedRolls ) end
    SLASH_ARF1 = "/arf"
    SlashCmdList[ "ARF" ] = function( args ) ProcessRollForSlashCommand( args, "/arf", M.GetAllPlayersInMyGroup ) end
    SLASH_CR1 = "/cr"
    SlashCmdList[ "CR" ] = DecorateWithRollingCheck( ProcessCancelRollSlashCommand )
    SLASH_FR1 = "/fr"
    SlashCmdList[ "FR" ] = DecorateWithRollingCheck( ProcessFinishRollSlashCommand )
    SLASH_SRS1 = "/srs"
    SlashCmdList[ "SRS" ] = ShowSoftRes
    SLASH_SRC1 = "/src"
    SlashCmdList[ "SRC" ] = ProcessSoftResCheckSlashCommand
    SLASH_SRO1 = "/sro"
    SlashCmdList[ "SRO" ] = SoftResPlayerNameOverride
    SLASH_SRUO1 = "/sruo"
    SlashCmdList[ "SRUO" ] = SoftResPlayerNameUnoverride
    SLASH_SRP1 = "/srp"
    SlashCmdList[ "SRP" ] = SoftResPass
    SLASH_SRUP1 = "/srup"
    SlashCmdList[ "SRUP" ] = SoftResUnpass
    SLASH_SRINVITE1 = "/srinvite"
    SlashCmdList[ "SRINVITE" ] = SoftResInvite

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
    M:PrettyPrint("Loaded.")
end

local function OnPartyMessage( message, player )
    OnChatMsgSystem( message )
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

function M.Initialize()
    M:OnFirstEnterWorld( OnFirstEnterWorld )
    M:OnChatMsgSystem( OnChatMsgSystem )
    M:OnJoinedGroup( OnJoinedGroup )
    M:OnLeftGroup( OnLeftGroup )

    -- For testing:
    --M:OnPartyMessage( OnPartyMessage )
    --M:OnPartyLeaderMessage( OnPartyMessage )
end
