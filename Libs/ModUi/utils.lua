ModUi = LibStub:GetLibrary( "ModUi-1.0", true )
if ModUi.Utils then return end

ModUi.Utils = {}

local function MyName()
	return UnitName( "player" )
end

local function MySex()
	return UnitSex( "player" )
end


local function MyRaidRank()
    for i = 1, 40 do
        local name, rank = GetRaidRosterInfo( i )

        if name and name == MyName() then
            return rank
        end
    end

    return 0
end

local function GetRaidRosterInfo( component, index )
	return _G[ "GetRaidRosterInfo" ]( index )
end

local function GetAllPlayersInMyGroup( component )
	local result = {}

	if not ( IsInGroup() or IsInRaid() ) then
		local myName = component:MyName()
		table.insert( result, myName )
		return result
	end

	for i = 1, 40 do
		local name = GetRaidRosterInfo( component, i )
		if name then table.insert( result, name ) end
	end

	return result
end	
	
function ModUi.Utils.TableContainsValue( t, value )
	if not t then return false end

	for _, v in pairs( t ) do
		if v == value then return true end
	end

	return false
end

function ModUi.Utils.TableContainsValueIgnoreCase( t, value )
	if not t then return false end

	for _, v in pairs( t ) do
		if string.lower( v ) == string.lower( value ) then return true end
	end

	return false
end

function ModUi.Utils.TableContainsOneOf( t, ... )
	if not t then return false end
	local values = { ... }

	for _, v in pairs( t ) do
		for _, value in pairs( values ) do
			if v == value then return true end
		end
	end

	return false
end

function ModUi.Utils.CountElements( t, f )
    local result = 0
    
    for _, v in pairs( t ) do
        if f and f( v ) or not f then
            result = result + 1
        end
    end

    return result
end

function ModUi.Utils.CloneTable( t )
	local result = {}

	if not t then return result end

	for k, v in pairs( t ) do
		result[ k ] = v
	end

	return result
end

function ModUi.Utils.RemoveValueFromTableIgnoreCase( t, value )
    for k, v in pairs( t ) do
        if string.lower( v ) == string.lower( value ) then
            t[ k ] = nil
            return
        end
    end
end

function ModUi.Utils.GetKeyByValue( t, f )
	for k, v in pairs( t ) do
		if f( v ) then return k end
	end

	return nil
end

local function IsInParty()
	return IsInGroup() and not IsInRaid()
end

local function IsInCombat( combatParams )
	return function() return combatParams.combat end
end

local function IsRegenEnabled( combatParams )
	return function() return combatParams.regenEnabled end
end

local function IsTargetting()
	return UnitName( "target" )
end

local function IsTargetOfTarget()
	return UnitName( "targettarget" )
end

local function ClearAllPoints( frame )
	if frame.HiddenClearAllPoints then
		frame:HiddenClearAllPoints()
	else
		frame:ClearAllPoints()
	end
end

local function SetPoint( frame, point, relativeTo, relativePoint, x, y )
	if frame.HiddenSetPoint then
		frame:HiddenSetPoint( point, relativeTo, relativePoint, x, y )
	else
		frame:SetPoint( point, relativeTo, relativePoint, x, y )
	end
end

local function MoveFrameByPoint( frame, pointTable )
    if not frame or not pointTable then return end
	if InCombatLockdown() then return end

    local point, relativeTo, relativePoint, x, y = unpack( pointTable )

	ClearAllPoints( frame )
	SetPoint( frame, point, relativeTo, relativePoint, x, y )
end

local function MoveFrameHorizontally( frame, x )
    if not frame then return end
	if InCombatLockdown() then return end

    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()

	ClearAllPoints( frame )
	SetPoint( frame, point, relativeTo, relativePoint, x, yOfs )
end

local function MoveFrameVertically( frame, y )
    if not frame then return end
	if InCombatLockdown() then return end

    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()

	ClearAllPoints( frame )
	SetPoint( frame, point, relativeTo, relativePoint, xOfs, y )
end

local function SetWidth( frame, width )
    if not frame then return end
	if InCombatLockdown() then return end

	if frame.HiddenSetWidth then
		frame:HiddenSetWidth( width )
	else
		frame:SetWidth( width )
	end
end

local function SetHeight( frame, height )
    if not frame then return end
	if InCombatLockdown() then return end

	if frame.HiddenSetHeight then
		frame:HiddenSetHeight( height )
	else
		frame:SetHeight( height )
	end
end

local function SetSize( frame, width, height )
	if not frame then return end
	if InCombatLockdown() then return end
	
	frame:SetWidth( width )
	frame:SetHeight( height )
end

local function SetScale( frame, scale )
	if not frame then return end
	if InCombatLockdown() then return end

	frame:SetScale( scale )
end

local function HideFunction( frame, method )
	if not frame then return end

	local hiddenFunction = "Hidden" .. method
	if frame[ hiddenFunction ] then return end

	frame[ hiddenFunction ] = frame[ method ]
	frame[ method ] = function() end
end

local function UnhideFunction( frame, method )
	if not frame then return end

	local hiddenFunction = "Hidden" .. method
	if not frame[ hiddenFunction ] then return end

	frame[ method ] = frame[ hiddenFunction ]
	frame[ hiddenFunction ] = nil
end

local function Show( frame )
	if not frame then return end

	if not frame.HiddenShow then
		HideFunction( frame, "Show" )
	end

	frame:HiddenShow()
end

local function Hide( frame )
	if not frame then return end

	if not frame.HiddenHide then
		HideFunction( frame, "Hide" )
	end

	frame:HiddenHide()
end

local function ScheduleTimer( ... )
	ModUi:ScheduleTimer( ... )
end

local function ScheduleRepeatingTimer( ... )
	ModUi:ScheduleRepeatingTimer( ... )
end

local function CancelTimer( ... )
	ModUi:CancelTimer( ... )
end

local function DisplayAndFadeOut( frame )
	if not frame or ( frame.fadeInfo and frame.fadeInfo.finishedFunc ) then return end

	frame:SetAlpha( 1 )
	frame:Show()
	ScheduleTimer( function()
		UIFrameFadeOut( frame, 2, 1, 0 )
		frame.fadeInfo.finishedFunc = function() frame:Hide() end
	end, 1 )
end

local function decorateWithEnabledCheck( func )
	return function( component, ... )
		if component.enabled then
			return func( ... )
		end
	end
end

local function decorateWithEnabledCheckAndComponent( func )
	return function( component, ... )
		if component.enabled then
			return func( component, ... )
		end
	end
end

local function EmitExternalEvent( eventName )
	ModUi:SendMessage( eventName )
end

local function IsPlayerName( name )
	if string.lower( UnitName( "player" ) ) == string.lower( name ) then
		return true
	end

	return false
end

local function GetDb( component, ... )
	local db = ModUi.db

	if not db[ component.name ] then
		db[ component.name ] = {}
	end

	return db[ component.name ];
end

local function IsPlayerInMyGroup( component, playerName )
	local playersInMyGroup = component:GetAllPlayersInMyGroup()

	for _, player in pairs( playersInMyGroup ) do
        if string.lower( player ) == string.lower( playerName ) then return true, name end
    end

    return false, nil
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
local function EncodeBase64( data )
    return ( ( data:gsub( '.', function( x ) 
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. ( b % 2 ^ i - b % 2 ^ ( i - 1 ) > 0 and '1' or '0' ) end
        return r
    end ) .. '0000' ):gsub( '%d%d%d?%d?%d?%d?', function( x )
        if ( #x < 6 ) then return '' end
        local c = 0
        for i = 1, 6 do c = c + ( x:sub( i, i ) == '1' and 2 ^ ( 6 - i ) or 0 ) end
        return b:sub( c + 1, c + 1 )
    end ) .. ( { '', '==', '=' } ) [ #data % 3 + 1 ] )
end

local function DecodeBase64( data )
    data = string.gsub( data, '[^' .. b .. '=]', '' )
    return ( data:gsub( '.', function( x )
        if ( x == '=' ) then return '' end
        local r, f = '', ( b:find( x ) - 1 )
        for i = 6, 1, -1 do r = r .. ( f % 2 ^ i - f % 2 ^ ( i - 1 ) > 0 and '1' or '0' ) end
        return r;
    end):gsub( '%d%d%d?%d?%d?%d?%d?%d?', function( x )
        if ( #x ~= 8 ) then return '' end
        local c = 0
        for i = 1, 8 do c = c + ( x:sub( i, i ) == '1' and 2 ^ ( 8 - i ) or 0 ) end
        return string.char( c )
    end ) )
end

local function GetItemLink( item )
    local _, itemLink = GetItemInfo( tonumber( item ) )
    return itemLink
end

local function TableToCommifiedString( t, f )
    local result = ""

    for k, v in pairs( t ) do
        if result ~= "" then
            result = result .. ", "
        end

        result = result .. ( f and f( k, v ) or v )
    end

    return result
end

local function TableToCommifiedPrettyString( t, f )
    local result = ""

	if #t == 0 then
		return result
	end

	if #t == 1 then
		return ( f and f( t[ 1 ] ) or t[ 1 ] )
	end

    for i = 1, #t - 1 do
        if result ~= "" then
            result = result .. ", "
        end

        result = result .. ( f and f( t[ i ] ) or t[ i ] )
    end

    result = result .. " and " .. ( f and f( t[ #t ] ) or t[ #t ] )
    return result
end


local function GetGroupMemberNames()
    local result = {}

    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo( nil, i )
        table.insert( result, name )
    end

	if #result == 0 then
        local myName = MyName()
        table.insert( result, myName )
    end

    return result
end


local function JoinTables( t1, t2 )
    local result = {}
    local n = 0

    for _, v in ipairs( t1 ) do n = n + 1; result[ n ] = v end
    for _, v in ipairs( t2 ) do n = n + 1; result[ n ] = v end

    return result
end

local function GetKeyByIndex( t, index, f )
    local i = 1

    for k, v in pairs( t ) do
        if f and f( v ) or not f then
            if i == index then
                return k
            end

            i = i + 1
        end
    end

    return nil
end

local function IsTrue( v )
    return v and v == true or false
end

local function ValueIsTrue( _, v )
	return v and v == true or false
end

local function GetGroupChatType()
    return IsInRaid() and "RAID" or "PARTY"
end

local function GetItemId( item )
    for itemId in (item):gmatch "|%w+|Hitem:(%d+):.+|r" do
        return tonumber( itemId )
    end

    return nil
end

local function filter( t, f )
	if not t then return nil end
	if not f then return t end

	local result = {}

	for k, v in pairs( t ) do
		if f( k, v ) then result[ k ] = v end
	end

	return result
end

local function keys( t )
	local result = {}

	for k, v in pairs( t ) do
		table.insert( result, k )
	end

	return result
end

local function values( t )
	local result = {}

	for k, v in pairs( t ) do
		table.insert( result, v )
	end

	return result
end

function ModUi.AddUtilityFunctionsToModule( combatParams, mod )
	local wrap = decorateWithEnabledCheck
	local wrapWithComponent = decorateWithEnabledCheckAndComponent

	mod.MyName = wrap( MyName )
	mod.MySex = wrap( MySex )
	mod.MyRaidRank = wrap( MyRaidRank )
	mod.IsInParty = wrap( IsInParty )
	mod.IsInRaid = wrap( IsInRaid )
	mod.IsInGroup = wrap( IsInGroup )
	mod.GetNumGroupMembers = wrap( GetNumGroupMembers )
	mod.IsInCombat = wrap( IsInCombat( combatParams ) )
	mod.IsRegenEnabled = wrap( IsRegenEnabled( combatParams ) )
	mod.IsTargetting = wrap( IsTargetting )
	mod.IsTargetOfTarget = wrap( IsTargetOfTarget )
    mod.MoveFrameByPoint = wrap( MoveFrameByPoint )
	mod.MoveFrameHorizontally = wrap( MoveFrameHorizontally )
	mod.MoveFrameVertically = wrap( MoveFrameVertically )
	mod.SetWidth = wrap( SetWidth )
	mod.SetHeight = wrap( SetHeight )
	mod.SetSize = wrap( SetSize )
	mod.SetScale = wrap( SetScale )
	mod.Show = wrap( Show )
	mod.Hide = wrap( Hide )
	mod.HideFunction = wrap( HideFunction )
	mod.UnhideFunction = wrap( UnhideFunction )
	mod.Print = function( _, message ) ChatFrame1:AddMessage( message ) end
	mod.ScheduleTimer = wrap( ScheduleTimer )
	mod.ScheduleRepeatingTimer = wrap( ScheduleRepeatingTimer )
	mod.CancelTimer = wrap( CancelTimer )
	mod.DisplayAndFadeOut = wrap( DisplayAndFadeOut )
	mod.EmitExternalEvent = wrap( EmitExternalEvent )
	mod.TableContainsValue = wrap( ModUi.Utils.TableContainsValue )
	mod.TableContainsValueIgnoreCase = wrap( ModUi.Utils.TableContainsValueIgnoreCase )
	mod.TableContainsOneOf = wrap( ModUi.Utils.TableContainsOneOf )
	mod.CountElements = wrap( ModUi.Utils.CountElements )
	mod.CloneTable = wrap( ModUi.Utils.CloneTable )
	mod.GetKeyByValue = wrap( ModUi.Utils.GetKeyByValue )
	mod.RemoveValueFromTableIgnoreCase = wrap( ModUi.Utils.RemoveValueFromTableIgnoreCase )
	mod.IsPlayerName = wrap( IsPlayerName )
	mod.IsPlayerInMyGroup = IsPlayerInMyGroup
	mod.GetDb = wrapWithComponent( GetDb )
	mod.EncodeBase64 = wrap( EncodeBase64 )
	mod.DecodeBase64 = wrap( DecodeBase64 )
	mod.GetItemLink = wrap( GetItemLink )
	mod.TableToCommifiedString = wrap( TableToCommifiedString )
	mod.TableToCommifiedPrettyString = wrap( TableToCommifiedPrettyString )
	mod.GetGroupMemberNames = wrap( GetGroupMemberNames )
	mod.JoinTables = wrap( JoinTables )
	mod.GetKeyByIndex = wrap( GetKeyByIndex )
	mod.IsTrue = IsTrue
	mod.ValueIsTrue = ValueIsTrue
	mod.GetGroupChatType = wrap( GetGroupChatType )
	mod.GetItemId = wrap( GetItemId )
	mod.filter = wrap( filter )
	mod.keys = wrap( keys )
	mod.values = wrap( values )
	mod.GetAllPlayersInMyGroup = GetAllPlayersInMyGroup
end

Move = MoveFrameByPoint
