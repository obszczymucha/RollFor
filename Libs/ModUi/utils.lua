ModUi = LibStub:GetLibrary( "ModUi-1.0", true )

ModUi.utils = ModUi.utils or {}
local M = ModUi.utils

M.highlight = function( word )
  return format( "|cffff9f69%s|r", word )
end

M.systemColor = function( word )
  return format( "|cffffff08%s|r", word )
end

M.MyName = function()
  return UnitName( "player" )
end

M.MySex = function()
  return UnitSex( "player" )
end

M.MyRaidRank = function()
  for i = 1, 40 do
    local name, rank = GetRaidRosterInfo( i )

    if name and name == M.MyName() then
      return rank
    end
  end

  return 0
end

M.IsPlayerMasterLooter = function()
  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, _, isMasterLooter = GetRaidRosterInfo( i )

    if name and name == M.MyName() then
      return isMasterLooter
    end
  end

  return false
end

M.TableContainsValue = function( t, value, f )
  if not t then return false end

  for _, v in pairs( t ) do
    local val = type( f ) == "function" and f( v ) or v
    if val == value then return true end
  end

  return false
end

M.TableContainsValueIgnoreCase = function( t, value )
  if not t then return false end

  for _, v in pairs( t ) do
    if string.lower( v ) == string.lower( value ) then return true end
  end

  return false
end

M.TableContainsOneOf = function( t, ... )
  if not t then return false end
  local values = { ... }

  for _, v in pairs( t ) do
    for _, value in pairs( values ) do
      if v == value then return true end
    end
  end

  return false
end

M.CountElements = function( t, f )
  local result = 0

  for _, v in pairs( t ) do
    if f and f( v ) or not f then
      result = result + 1
    end
  end

  return result
end

M.CloneTable = function( t )
  local result = {}

  if not t then return result end

  for k, v in pairs( t ) do
    result[ k ] = v
  end

  return result
end

M.RemoveValueFromTableIgnoreCase = function( t, value )
  for k, v in pairs( t ) do
    if string.lower( v ) == string.lower( value ) then
      t[ k ] = nil
      return
    end
  end
end

M.GetKeyByValue = function( t, f )
  for k, v in pairs( t ) do
    if f( v ) then return k end
  end

  return nil
end

M.IsInParty = function()
  return IsInGroup() and not IsInRaid()
end

M.IsInCombat = function( combatParams )
  return function() return combatParams.combat end
end

M.IsRegenEnabled = function( combatParams )
  return function() return combatParams.regenEnabled end
end

M.IsTargetting = function()
  return UnitName( "target" )
end

M.IsTargetOfTarget = function()
  return UnitName( "targettarget" )
end

M.ClearAllPoints = function( frame )
  if frame.HiddenClearAllPoints then
    frame:HiddenClearAllPoints()
  else
    frame:ClearAllPoints()
  end
end

M.SetPoint = function( frame, point, relativeTo, relativePoint, x, y )
  if frame.HiddenSetPoint then
    frame:HiddenSetPoint( point, relativeTo, relativePoint, x, y )
  else
    frame:SetPoint( point, relativeTo, relativePoint, x, y )
  end
end

M.MoveFrameByPoint = function( frame, pointTable )
  if not frame or not pointTable then return end
  if InCombatLockdown() then return end

  local point, relativeTo, relativePoint, x, y = unpack( pointTable )

  M.ClearAllPoints( frame )
  M.SetPoint( frame, point, relativeTo, relativePoint, x, y )
end

M.MoveFrameHorizontally = function( frame, x )
  if not frame then return end
  if InCombatLockdown() then return end

  local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()

  M.ClearAllPoints( frame )
  M.SetPoint( frame, point, relativeTo, relativePoint, x, yOfs )
end

M.MoveFrameVertically = function( frame, y )
  if not frame or InCombatLockdown() then return end

  local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()

  M.ClearAllPoints( frame )
  M.SetPoint( frame, point, relativeTo, relativePoint, xOfs, y )
end

M.SetWidth = function( frame, width )
  if not frame or InCombatLockdown() then return end

  if frame.HiddenSetWidth then
    frame:HiddenSetWidth( width )
  else
    frame:SetWidth( width )
  end
end

M.SetHeight = function( frame, height )
  if not frame or InCombatLockdown() then return end

  if frame.HiddenSetHeight then
    frame:HiddenSetHeight( height )
  else
    frame:SetHeight( height )
  end
end

M.SetSize = function( frame, width, height )
  if not frame or InCombatLockdown() then return end

  frame:SetWidth( width )
  frame:SetHeight( height )
end

M.SetScale = function( frame, scale )
  if not frame or InCombatLockdown() then return end

  frame:SetScale( scale )
end

M.HideFunction = function( frame, method )
  if not frame then return end

  local hiddenFunction = "Hidden" .. method
  if frame[ hiddenFunction ] then return end

  frame[ hiddenFunction ] = frame[ method ]
  frame[ method ] = function() end
end

M.UnhideFunction = function( frame, method )
  if not frame then return end

  local hiddenFunction = "Hidden" .. method
  if not frame[ hiddenFunction ] then return end

  frame[ method ] = frame[ hiddenFunction ]
  frame[ hiddenFunction ] = nil
end

M.Show = function( frame )
  if not frame then return end

  if not frame.HiddenShow then
    M.HideFunction( frame, "Show" )
  end

  frame:HiddenShow()
end

M.Hide = function( frame )
  if not frame then return end

  if not frame.HiddenHide then
    M.HideFunction( frame, "Hide" )
  end

  frame:HiddenHide()
end

M.ScheduleTimer = function( ... )
  ModUi:ScheduleTimer( ... )
end

M.ScheduleRepeatingTimer = function( ... )
  ModUi:ScheduleRepeatingTimer( ... )
end

M.CancelTimer = function( ... )
  ModUi:CancelTimer( ... )
end

M.DisplayAndFadeOut = function( frame )
  if not frame or (frame.fadeInfo and frame.fadeInfo.finishedFunc) then return end

  frame:SetAlpha( 1 )
  frame:Show()
  ModUi:ScheduleTimer( function()
    UIFrameFadeOut( frame, 2, 1, 0 )
    frame.fadeInfo.finishedFunc = function() frame:Hide() end
  end, 1 )
end

M.EmitExternalEvent = function( eventName )
  ModUi:SendMessage( eventName )
end

M.IsMyName = function( name )
  if string.lower( UnitName( "player" ) ) == string.lower( name ) then
    return true
  end

  return false
end

-- To be deprecated
M.IsPlayerName = M.IsMyName

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
M.EncodeBase64 = function( data )
  return ((data:gsub( '.', function( x )
    local r, b = '', x:byte()
    for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r
  end ) .. '0000'):gsub( '%d%d%d?%d?%d?%d?', function( x )
    if (#x < 6) then return '' end
    local c = 0
    for i = 1, 6 do c = c + (x:sub( i, i ) == '1' and 2 ^ (6 - i) or 0) end
    return b:sub( c + 1, c + 1 )
  end ) .. ({ '', '==', '=' })[ #data % 3 + 1 ])
end

M.DecodeBase64 = function( data )
  data = string.gsub( data, '[^' .. b .. '=]', '' )
  return (data:gsub( '.', function( x )
    if (x == '=') then return '' end
    local r, f = '', (b:find( x ) - 1)
    for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r;
  end ):gsub( '%d%d%d?%d?%d?%d?%d?%d?', function( x )
    if (#x ~= 8) then return '' end
    local c = 0
    for i = 1, 8 do c = c + (x:sub( i, i ) == '1' and 2 ^ (8 - i) or 0) end
    return string.char( c )
  end ))
end

M.GetItemLink = function( item )
  local _, itemLink = GetItemInfo( tonumber( item ) )
  return itemLink
end

M.TableToCommifiedString = function( t, f )
  local result = ""

  for k, v in pairs( t ) do
    if result ~= "" then
      result = result .. ", "
    end

    result = result .. (f and f( k, v ) or v)
  end

  return result
end

M.TableToCommifiedPrettyString = function( t, f )
  local result = ""

  if #t == 0 then
    return result
  end

  if #t == 1 then
    return (f and f( t[ 1 ] ) or t[ 1 ])
  end

  for i = 1, #t - 1 do
    if result ~= "" then
      result = result .. ", "
    end

    result = result .. (f and f( t[ i ] ) or t[ i ])
  end

  result = result .. " and " .. (f and f( t[ #t ] ) or t[ #t ])
  return result
end

M.GetGroupMemberNames = function()
  local result = {}

  for i = 1, GetNumGroupMembers() do
    local name = GetRaidRosterInfo( i )
    table.insert( result, name )
  end

  if #result == 0 then
    local myName = M.MyName()
    table.insert( result, myName )
  end

  return result
end

M.OnlineClassCountInGroup = function( className )
  if not IsInGroup() then
    return UnitClass( "player" ) == className and 1 or 0
  end

  local classCountPerGroup = {}
  local mySubGroup = nil
  local myName = M.MyName()

  for i = 1, 40 do
    local name, _, subGroup, _, class, _, _, online = GetRaidRosterInfo( i )

    if name == myName then
      mySubGroup = subGroup
    end

    if name and class == className and online then
      if not classCountPerGroup[ subGroup ] then
        classCountPerGroup[ subGroup ] = 0
      end

      classCountPerGroup[ subGroup ] = classCountPerGroup[ subGroup ] + 1
    end
  end

  return classCountPerGroup[ mySubGroup ]
end

M.OnlineClassCountInRaid = function( className )
  if not IsInGroup() then
    return UnitClass( "player" ) == className and 1 or 0
  end

  local warriorCount = 0

  for i = 1, 40 do
    local name, _, _, _, class, _, _, online = GetRaidRosterInfo( i )

    if name and class == className and online then
      warriorCount = warriorCount + 1
    end
  end

  return warriorCount
end

M.JoinTables = function( t1, t2 )
  local result = {}
  local n = 0

  for _, v in ipairs( t1 ) do n = n + 1;
    result[ n ] = v
  end
  for _, v in ipairs( t2 ) do n = n + 1;
    result[ n ] = v
  end

  return result
end

M.GetKeyByIndex = function( t, index, f )
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

M.IsTrue = function( v )
  return v and v == true or false
end

M.ValueIsTrue = function( _, v )
  return v and v == true or false
end

M.GetGroupChatType = function()
  return IsInRaid() and "RAID" or "PARTY"
end

M.GetItemId = function( item )
  for itemId in (item):gmatch "|%w+|Hitem:(%d+):.+|r" do
    return tonumber( itemId )
  end

  return nil
end

M.filter = function( t, f )
  if not t then return nil end
  if type( f ) ~= "function" then return t end

  local result = {}

  for k, v in pairs( t ) do
    if f( k, v ) then result[ k ] = v end
  end

  return result
end

M.keys = function( t )
  local result = {}

  for k, v in pairs( t ) do
    table.insert( result, k )
  end

  return result
end

M.values = function( t )
  local result = {}

  for k, v in pairs( t ) do
    table.insert( result, v )
  end

  return result
end

local function GetDb( component, ... )
  local db = ModUi.db

  if not db[ component.name ] then
    db[ component.name ] = {}
  end

  return db[ component.name ];
end

M.GetAllPlayersInMyGroup = function()
  local result = {}

  if not (IsInGroup() or IsInRaid()) then
    local myName = M.MyName()
    table.insert( result, myName )
    return result
  end

  for i = 1, 40 do
    local name = GetRaidRosterInfo( i )
    if name then table.insert( result, name ) end
  end

  return result
end

M.IsPlayerInMyGroup = function( playerName )
  local playersInMyGroup = M.GetAllPlayersInMyGroup()

  for _, player in pairs( playersInMyGroup ) do
    if string.lower( player ) == string.lower( playerName ) then return true, name end
  end

  return false, nil
end

M.HasProfession = function( professionName )
  for i = 1, GetNumSkillLines() do
    local skillName, isHeader, _, skillRank, _, _, skillMaxRank, _, _, _, _, _, _ = GetSkillLineInfo( i )
    if string.lower( skillName ) == string.lower( professionName ) then return true end
  end

  return false
end

M.CountItemsById = function( itemId )
  local _, link = GetItemInfo( itemId )
  return M.CountItemsByLink( link )
end

M.CountItemsByLink = function( itemLink )
  local total = 0

  for bag = 0, NUM_BAG_SLOTS do
    for slot = 1, GetContainerNumSlots( bag ) do
      if (GetContainerItemLink( bag, slot ) == itemLink) then
        if select( 2, GetContainerItemInfo( bag, slot ) ) then
          total = total + select( 2, GetContainerItemInfo( bag, slot ) )
        end
      end
    end
  end

  return total
end

M.IsPrimarySpec = function()
  return GetActiveTalentGroup() == 1
end

function ModUi.AddUtilityFunctionsToModule( combatParams, mod )
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

  local wrap = decorateWithEnabledCheck
  local wrapWithComponent = decorateWithEnabledCheckAndComponent

  mod.Print = function( _, message ) ChatFrame1:AddMessage( message ) end
  mod.highlight = M.highlight
  mod.systemColor = M.systemColor
  mod.MyName = wrap( M.MyName )
  mod.MySex = wrap( M.MySex )
  mod.MyRaidRank = wrap( M.MyRaidRank )
  mod.IsInParty = wrap( M.IsInParty )
  mod.IsInCombat = wrap( M.IsInCombat( combatParams ) )
  mod.IsRegenEnabled = wrap( M.IsRegenEnabled( combatParams ) )
  mod.IsTargetting = wrap( M.IsTargetting )
  mod.IsTargetOfTarget = wrap( M.IsTargetOfTarget )
  mod.MoveFrameByPoint = wrap( M.MoveFrameByPoint )
  mod.MoveFrameHorizontally = wrap( M.MoveFrameHorizontally )
  mod.MoveFrameVertically = wrap( M.MoveFrameVertically )
  mod.SetWidth = wrap( M.SetWidth )
  mod.SetHeight = wrap( M.SetHeight )
  mod.SetSize = wrap( M.SetSize )
  mod.SetScale = wrap( M.SetScale )
  mod.Show = wrap( M.Show )
  mod.Hide = wrap( M.Hide )
  mod.HideFunction = wrap( M.HideFunction )
  mod.UnhideFunction = wrap( M.UnhideFunction )
  mod.ScheduleTimer = wrap( M.ScheduleTimer )
  mod.ScheduleRepeatingTimer = wrap( M.ScheduleRepeatingTimer )
  mod.CancelTimer = wrap( M.CancelTimer )
  mod.DisplayAndFadeOut = wrap( M.DisplayAndFadeOut )
  mod.EmitExternalEvent = wrap( M.EmitExternalEvent )
  mod.TableContainsValue = wrap( M.TableContainsValue )
  mod.TableContainsValueIgnoreCase = wrap( M.TableContainsValueIgnoreCase )
  mod.TableContainsOneOf = wrap( M.TableContainsOneOf )
  mod.CountElements = wrap( M.CountElements )
  mod.CloneTable = wrap( M.CloneTable )
  mod.GetKeyByValue = wrap( M.GetKeyByValue )
  mod.RemoveValueFromTableIgnoreCase = wrap( M.RemoveValueFromTableIgnoreCase )
  mod.IsMyName = wrap( M.IsMyName )
  mod.IsPlayerName = wrap( M.IsMyName )
  mod.EncodeBase64 = wrap( M.EncodeBase64 )
  mod.DecodeBase64 = wrap( M.DecodeBase64 )
  mod.GetItemLink = wrap( M.GetItemLink )
  mod.TableToCommifiedString = wrap( M.TableToCommifiedString )
  mod.TableToCommifiedPrettyString = wrap( M.TableToCommifiedPrettyString )
  mod.GetGroupMemberNames = wrap( M.GetGroupMemberNames )
  mod.OnlineClassCountInGroup = wrap( M.OnlineClassCountInGroup )
  mod.OnlineClassCountInRaid = wrap( M.OnlineClassCountInRaid )
  mod.JoinTables = wrap( M.JoinTables )
  mod.GetKeyByIndex = wrap( M.GetKeyByIndex )
  mod.IsTrue = M.IsTrue
  mod.ValueIsTrue = M.ValueIsTrue
  mod.GetGroupChatType = wrap( M.GetGroupChatType )
  mod.GetItemId = wrap( M.GetItemId )
  mod.filter = wrap( M.filter )
  mod.keys = wrap( M.keys )
  mod.values = wrap( M.values )
  mod.IsPlayerInMyGroup = wrap( M.IsPlayerInMyGroup )
  mod.GetAllPlayersInMyGroup = wrap( M.GetAllPlayersInMyGroup )
  mod.HasProfession = wrap( M.HasProfession )
  mod.CountItemsById = wrap( M.CountItemsById )
  mod.CountItemsByLink = wrap( M.CountItemsByLink )
  mod.IsPrimarySpec = wrap( M.IsPrimarySpec )
  mod.IsPlayerMasterLooter = wrap( M.IsPlayerMasterLooter )

  -- Component specific
  mod.GetDb = wrapWithComponent( GetDb )
end

function ModUi.trim( s )
  return s:gsub( "^%s*(.-)%s*$", "%1" )
end

Move = MoveFrameByPoint
