local version = 4
---@diagnostic disable-next-line: undefined-global
local libStub = LibStub

local M = libStub:NewLibrary( "ModUi-1.0", version )
if not M then return end

ModUi = M
ModUi.version = version
local facade = libStub( "ModUiFacade-1.0" )
ModUi.facade = facade
local api = facade.api

local aceConsole = libStub( "AceConsole-3.0" )
local aceEvent = libStub( "AceEvent-3.0" )
local aceTimer = libStub( "AceTimer-3.0" )
local aceComm = libStub( "AceComm-3.0" )

ModUi.callbacks = ModUi.callbacks or {}
local m_callbacks = ModUi.callbacks
ModUi.modules = ModUi.modules or {}
local modules = ModUi.modules
ModUi.extensions = ModUi.extensions or {}
local extensions = ModUi.extensions

---@diagnostic disable-next-line: undefined-global
local mainFrame = ChatFrame1
---@diagnostic disable-next-line: undefined-global
local debugFrame = ChatFrame3
local debug = false
local suspended = false
local m_firstEnterWorld = false
local m_initialized = false

local combatParams = {
  combat = false,
  regenEnabled = true
}

function ModUi:Print( ... )
  return aceConsole:Print( ... )
end

function ModUi:PrettyPrint( message )
  ModUi:Print( string.format( "[|cff33ff99ModUi|r]: %s", message ) )
end

function ModUi:ScheduleTimer( ... )
  return aceTimer:ScheduleTimer( ... )
end

function ModUi:ScheduleRepeatingTimer( ... )
  return aceTimer:ScheduleRepeatingTimer( ... )
end

function ModUi:CancelTimer( ... )
  return aceTimer:CancelTimer( ... )
end

function ModUi:RegisterComm( ... )
  return aceComm:RegisterComm( ... )
end

function ModUi:SendMessage( ... )
  return aceEvent:SendMessage( ... )
end

function ModUi:SendCommMessage( ... )
  return aceComm:SendCommMessage( ... )
end

local function OnEvent( callbacks, combatLockCheck, componentName, ... )
  for _, entry in ipairs( callbacks ) do
    if not componentName or entry.component.name == componentName then
      if not suspended and entry.component.enabled and not entry.component.suspended and (not combatLockCheck or not api.InCombatLockdown()) then
        --				entry.component:DebugMsg( format( "event: %s", entry.name ) )
        entry.callback( ... )
      end
    end
  end
end

local function RegisterCallback( callbackName )
  if not m_callbacks[ callbackName ] then m_callbacks[ callbackName ] = {} end

  return function( component, callback, dependencies )
    if not component then
      error( string.format( "No self provided in %s event callback. Hint: use : insted of .", callbackName ) )
      return
    end

    if not callback then
      error( string.format( "No callback provided for %s event in %s component.", callbackName, component.name ) )
      return
    end

    local callbacks = m_callbacks[ callbackName ]
    local newEntry = { name = callbackName, component = component, callback = callback, dependencies = dependencies }

    for index, entry in ipairs( callbacks ) do
      if ModUi.utils.TableContainsValue( entry.dependencies, component.name ) then
        table.insert( callbacks, index, newEntry )
        return
      end
    end

    table.insert( callbacks, newEntry )
  end,
      function( ... )
        OnEvent( m_callbacks[ callbackName ], true, nil, ... )
      end
end

local function AddBlizzEventCallbackFunctionsToComponent( component )
  component.OnLogin = RegisterCallback( "login" )
  component.OnFirstEnterWorld = RegisterCallback( "firstEnterWorld" )
  component.OnEnterWorld = RegisterCallback( "enterWorld" )
  component.OnEnterCombat = RegisterCallback( "enterCombat" )
  component.OnLeaveCombat = RegisterCallback( "leaveCombat" )
  component.OnRegenEnabled = RegisterCallback( "regenEnabled" )
  component.OnRegenDisabled = RegisterCallback( "regenDisabled" )
  component.OnGroupChanged = RegisterCallback( "groupChanged" )
  component.OnGroupFormed = RegisterCallback( "groupFormed" )
  component.OnJoinedGroup = RegisterCallback( "joinedGroup" )
  component.OnLeftGroup = RegisterCallback( "leftGroup" )
  component.OnZoneChanged = RegisterCallback( "zoneChanged" )
  component.OnAreaChanged = RegisterCallback( "areaChanged" )
  component.OnWorldStatesUpdated = RegisterCallback( "worldStatesUpdated" )
  component.OnHerbsAvailable = RegisterCallback( "herbsAvailable" )
  component.OnHerbGathered = RegisterCallback( "herbGathered" )
  component.OnGasExtracted = RegisterCallback( "gasExtracted" )
  component.OnPartyInviteRequest = RegisterCallback( "partyInviteRequest" )
  component.OnChatMsgSystem = RegisterCallback( "chatMsgSystem" )
  component.OnReadyCheck = RegisterCallback( "readyCheck" )
  component.OnTargetChanged = RegisterCallback( "targetChanged" )
  component.OnActionBarSlotChanged = RegisterCallback( "actionBarSlotChanged" )
  component.OnCombatLogEventUnfiltered = RegisterCallback( "combatLogEventUnfiltered" )
  component.OnPendingMail = RegisterCallback( "pendingMail" )
  component.OnBagUpdate = RegisterCallback( "bagUpdate" )
  component.OnWhisper = RegisterCallback( "whisper" )
  component.OnPartyMessage = RegisterCallback( "partyMessage" )
  component.OnPartyLeaderMessage = RegisterCallback( "partyLeaderMessage" )
  component.OnSkillIncreased = RegisterCallback( "skillIncreased" )
  component.OnHonorGain = RegisterCallback( "honorGain" )
  component.OnAreaPoisUpdated = RegisterCallback( "areaPoisUpdated" )
  component.OnGossipShow = RegisterCallback( "gossipShow" )
  component.OnMerchantShow = RegisterCallback( "merchantShow" )
  component.OnSpecChanged = RegisterCallback( "specChanged" )
  component.OnLootReady = RegisterCallback( "lootReady" )
  component.OnOpenMasterLootList = RegisterCallback( "openMasterLootList" )
  component.OnLootSlotCleared = RegisterCallback( "lootSlotCleared" )
  component.OnTradeShow = RegisterCallback( "tradeShow" )
  component.OnTradePlayerItemChanged = RegisterCallback( "tradePlayerItemChanged" )
  component.OnTradeTargetItemChanged = RegisterCallback( "tradeTargetItemChanged" )
  component.OnTradeClosed = RegisterCallback( "tradeClosed" )
  component.OnTradeAcceptUpdate = RegisterCallback( "tradeAcceptUpdate" )
  component.OnTradeRequestCancel = RegisterCallback( "tradeRequestCancel" )
end

local function DebugMsg( message )
  if not debug then return end
  debugFrame:AddMessage( string.format( "|cff33ff99ModUi|r: %s", message ) )
end

function ModUi.NewExtension( _, extensionName, requiredExtensions )
  if not extensionName then
    error( "No extension name provided." )
    return
  end

  if extensions[ extensionName ] then
    error( string.format( "Extension %s is already defined.", extensionName ) )
    return
  end

  local extension = {
    name = extensionName,
    requiredExtensions = requiredExtensions,
    enabled = true,
    suspended = false,
    debug = false,
    debugFrame = debugFrame,
    DebugMsg = function( extension, message, force )
      if extension.debugFrame and (debug or extension.debug or force) then
        extension.debugFrame:AddMessage( string.format( "|cff33ff99ModUi [|r|cff209ff9%s|r|cff33ff99]|r: %s", extension.name, message ) )
      end
    end,
    RegisterCallback = function( extension, callbackName )
      if extension.enabled then
        return RegisterCallback( callbackName )
      else
        return function( ext ) ext:DebugMsg( "Extension disabled." ) end, function( ext ) ext:DebugMsg( "Extension disabled." ) end
      end
    end,
    PrettyPrint = function( mod, message ) mainFrame:AddMessage( string.format( "|cff33ff99ModUi [|r|cff209ff9%s|r|cff33ff99]|r: %s", mod.name, message ) ) end
  }

  AddBlizzEventCallbackFunctionsToComponent( extension )
  ModUi.AddUtilityFunctionsToModule( combatParams, extension )
  extensions[ extensionName ] = extension

  return extension
end

function ModUi.GetExtension( _, extensionName )
  return extensions[ extensionName ]
end

function ModUi.GetModule( _, moduleName )
  return modules[ moduleName ]
end

local function ExtendComponent( component )
  for _, extension in pairs( extensions ) do
    if extension.enabled and ModUi.utils.TableContainsValue( component.requiredExtensions, extension.name ) and extension.ExtendComponent then
      component:DebugMsg( string.format( "Extending with |cff209ff9%s|r", extension.name ) )
      extension.ExtendComponent( component )
    end
  end
end

function ModUi.NewModule( _, moduleName, requiredExtensions )
  if not moduleName then
    error( "No module name provided." )
    return
  end

  if modules[ moduleName ] then
    error( string.format( "Module %s is already defined.", moduleName ) )
    return
  end

  local mod = {
    name = moduleName,
    requiredExtensions = requiredExtensions,
    enabled = true,
    suspended = false,
    debug = debug,
    debugFrame = debugFrame,
    DebugMsg = function( mod, message, force )
      if mod.debugFrame and (mod.debug or force) then mod.debugFrame:AddMessage( string.format( "|cff33ff99ModUi [|r|cffff9f69%s|r|cff33ff99]|r: %s", mod.name,
          message or "nil" ) )
      end
    end,
    Initialize = function( mod ) mod:DebugMsg( "No Initialize() found." ) end, -- Override in a module
    PrettyPrint = function( mod, message ) ModUi:Print( string.format( "|cff33ff99ModUi [|r|cffff9f69%s|r|cff33ff99]|r: %s", mod.name, message ) ) end
  }

  AddBlizzEventCallbackFunctionsToComponent( mod )
  ModUi.AddUtilityFunctionsToModule( combatParams, mod )
  modules[ moduleName ] = mod

  if m_initialized then
    ExtendComponent( mod )
  end

  return mod
end

local function ExtendExtensions()
  for _, extension in pairs( extensions ) do
    ExtendComponent( extension )
  end
end

local function ExtendModules()
  for _, mod in pairs( modules ) do
    ExtendComponent( mod )
  end
end

local function DisableModulesWithoutExtensions()
  for _, mod in pairs( modules ) do
    if mod.requiredExtensions then
      for _, extensionName in ipairs( mod.requiredExtensions ) do
        local extension = extensions[ extensionName ]

        if not extension or not extension.enabled then
          mod.enabled = false
          mod:DebugMsg( string.format( "Disabled: Extension |cff209ff9%s|r not available", extensionName ) )
        end
      end
    end
  end
end

local function InitializeComponents( components )
  for _, component in pairs( components ) do
    if component.enabled and component.Initialize then
      component:DebugMsg( "Initializing" )
      component:Initialize()
    end
  end
end

local function OnUnitSpellcastChannelStop( unit, _, spellId )
  if unit == "player" and spellId == 30427 then
    OnEvent( m_callbacks[ "gasExtracted" ], false )
  end
end

-- OnUnitSpellcastStart( who, id, spellId )
local function OnUnitSpellcastStart( _, _, spellId )
  if spellId == 2366 then
    OnEvent( m_callbacks.herbGathered, true )
    return
  end
end

--eventHandler( frame, event, ... )
local function eventHandler( _, event, ... )
  if event == "PLAYER_LOGIN" then
    m_firstEnterWorld = false
    if m_initialized then return end
    ModUi:OnInitialize()
    ExtendExtensions()
    InitializeComponents( extensions )
    ExtendModules()
    DisableModulesWithoutExtensions()
    InitializeComponents( modules )
    OnEvent( m_callbacks[ "login" ], false )
  elseif event == "PLAYER_ENTERING_WORLD" then
    if not m_firstEnterWorld then
      OnEvent( m_callbacks[ "firstEnterWorld" ], false )
      m_firstEnterWorld = true
    end
    OnEvent( m_callbacks[ "enterWorld" ], false )
  elseif event == "PLAYER_REGEN_ENABLED" then
    combatParams.regenEnabled = true
    OnEvent( m_callbacks[ "regenEnabled" ], true )
  elseif event == "PLAYER_REGEN_DISABLED" then
    combatParams.regenEnabled = false
    OnEvent( m_callbacks[ "regenDisabled" ], true )
  elseif event == "PLAYER_ENTER_COMBAT" then
    combatParams.combat = true
    OnEvent( m_callbacks[ "enterCombat" ], true )
  elseif event == "PLAYER_LEAVE_COMBAT" then
    combatParams.combat = false
    OnEvent( m_callbacks[ "leaveCombat" ], true )
  elseif event == "RAID_ROSTER_UPDATE" then
    OnEvent( m_callbacks[ "groupChanged" ], true )
  elseif event == "GROUP_ROSTER_UPDATE" then
    OnEvent( m_callbacks[ "groupChanged" ], true )
  elseif event == "GROUP_FORMED" then
    OnEvent( m_callbacks[ "groupFormed" ], true )
  elseif event == "GROUP_JOINED" then
    OnEvent( m_callbacks[ "joinedGroup" ], true )
  elseif event == "GROUP_LEFT" then
    OnEvent( m_callbacks[ "leftGroup" ], true )
  elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
    OnEvent( m_callbacks[ "zoneChanged" ], true )
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    OnEvent( m_callbacks[ "areaChanged" ], true )
  elseif event == "UPDATE_WORLD_STATES" then
    OnEvent( m_callbacks[ "worldStatesUpdated" ], true )
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    OnUnitSpellcastChannelStop( ... )
  elseif event == "PARTY_INVITE_REQUEST" then
    OnEvent( m_callbacks[ "partyInviteRequest" ], false, nil, ... )
  elseif event == "CHAT_MSG_SYSTEM" then
    OnEvent( m_callbacks[ "chatMsgSystem" ], false, nil, ... )
  elseif event == "READY_CHECK" then
    OnEvent( m_callbacks[ "readyCheck" ], false )
  elseif event == "PLAYER_TARGET_CHANGED" then
    OnEvent( m_callbacks[ "targetChanged" ], true )
  elseif event == "ACTIONBAR_SLOT_CHANGED" then
    OnEvent( m_callbacks[ "actionBarSlotChanged" ], true )
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    OnEvent( m_callbacks[ "combatLogEventUnfiltered" ], false, nil, api.CombatLogGetCurrentEventInfo() )
  elseif event == "UPDATE_PENDING_MAIL" then
    OnEvent( m_callbacks[ "pendingMail" ], false, nil, ... )
  elseif event == "BAG_UPDATE" then
    OnEvent( m_callbacks[ "bagUpdate" ], false, nil, ... )
  elseif event == "CHAT_MSG_WHISPER" then
    OnEvent( m_callbacks[ "whisper" ], false, nil, ... )
  elseif event == "CHAT_MSG_PARTY" then
    OnEvent( m_callbacks[ "partyMessage" ], false, nil, ... )
  elseif event == "CHAT_MSG_PARTY_LEADER" then
    OnEvent( m_callbacks[ "partyLeaderMessage" ], false, nil, ... )
  elseif event == "CHAT_MSG_SKILL" then
    OnEvent( m_callbacks[ "skillIncreased" ], false, nil, ... )
  elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
    OnEvent( m_callbacks[ "honorGain" ], false, nil, ... )
  elseif event == "UNIT_SPELLCAST_START" then
    OnUnitSpellcastStart( ... )
  elseif event == "AREA_POIS_UPDATED" then
    OnEvent( m_callbacks[ "areaPoisUpdated" ], false, nil, ... )
  elseif event == "GOSSIP_SHOW" then
    OnEvent( m_callbacks[ "gossipShow" ], false, nil, ... )
  elseif event == "MERCHANT_SHOW" then
    OnEvent( m_callbacks[ "merchantShow" ], false, nil, ... )
  elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
    OnEvent( m_callbacks[ "specChanged" ], false, nil, ... )
  elseif event == "LOOT_READY" then
    OnEvent( m_callbacks[ "lootReady" ], false, nil, ... )
  elseif event == "OPEN_MASTER_LOOT_LIST" then
    OnEvent( m_callbacks[ "openMasterLootList" ], false, nil, ... )
  elseif event == "LOOT_SLOT_CLEARED" then
    OnEvent( m_callbacks[ "lootSlotCleared" ], false, nil, ... )
  elseif event == "TRADE_SHOW" then
    OnEvent( m_callbacks[ "tradeShow" ], false, nil, ... )
  elseif event == "TRADE_PLAYER_ITEM_CHANGED" then
    OnEvent( m_callbacks[ "tradePlayerItemChanged" ], false, nil, ... )
  elseif event == "TRADE_TARGET_ITEM_CHANGED" then
    OnEvent( m_callbacks[ "tradeTargetItemChanged" ], false, nil, ... )
  elseif event == "TRADE_CLOSED" then
    OnEvent( m_callbacks[ "tradeClosed" ], false, nil, ... )
  elseif event == "TRADE_ACCEPT_UPDATE" then
    OnEvent( m_callbacks[ "tradeAcceptUpdate" ], false, nil, ... )
  elseif event == "TRADE_REQUEST_CANCEL" then
    OnEvent( m_callbacks[ "tradeRequestCancel" ], false, nil, ... )
  end
end

ModUi.frame = ModUi.frame or api.CreateFrame( "FRAME", "ModUiFrame" )
local frame = ModUi.frame

frame:RegisterEvent( "PLAYER_LOGIN" )
frame:RegisterEvent( "PLAYER_ENTERING_WORLD" )
frame:RegisterEvent( "PLAYER_REGEN_ENABLED" )
frame:RegisterEvent( "PLAYER_REGEN_DISABLED" )
frame:RegisterEvent( "PLAYER_ENTER_COMBAT" )
frame:RegisterEvent( "PLAYER_LEAVE_COMBAT" )
frame:RegisterEvent( "RAID_ROSTER_UPDATE" )
frame:RegisterEvent( "GROUP_ROSTER_UPDATE" )
frame:RegisterEvent( "GROUP_JOINED" )
frame:RegisterEvent( "GROUP_LEFT" )
frame:RegisterEvent( "GROUP_FORMED" )
frame:RegisterEvent( "ZONE_CHANGED" )
frame:RegisterEvent( "ZONE_CHANGED_INDOORS" )
frame:RegisterEvent( "ZONE_CHANGED_NEW_AREA" )
frame:RegisterEvent( "UNIT_SPELLCAST_CHANNEL_STOP" )
frame:RegisterEvent( "PARTY_INVITE_REQUEST" )
frame:RegisterEvent( "CHAT_MSG_SYSTEM" )
frame:RegisterEvent( "READY_CHECK" )
frame:RegisterEvent( "PLAYER_TARGET_CHANGED" )
frame:RegisterEvent( "ACTIONBAR_SLOT_CHANGED" )
frame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED" )
frame:RegisterEvent( "UPDATE_PENDING_MAIL" )
frame:RegisterEvent( "BAG_UPDATE" )
frame:RegisterEvent( "CHAT_MSG_WHISPER" )
frame:RegisterEvent( "CHAT_MSG_PARTY" )
frame:RegisterEvent( "CHAT_MSG_PARTY_LEADER" )
frame:RegisterEvent( "CHAT_MSG_SKILL" )
frame:RegisterEvent( "CHAT_MSG_COMBAT_HONOR_GAIN" )
frame:RegisterEvent( "UNIT_SPELLCAST_START" )
frame:RegisterEvent( "AREA_POIS_UPDATED" )
frame:RegisterEvent( "GOSSIP_SHOW" )
frame:RegisterEvent( "MERCHANT_SHOW" )
frame:RegisterEvent( "ACTIVE_TALENT_GROUP_CHANGED" )
frame:RegisterEvent( "LOOT_READY" )
frame:RegisterEvent( "OPEN_MASTER_LOOT_LIST" )
frame:RegisterEvent( "LOOT_SLOT_CLEARED" )
frame:RegisterEvent( "TRADE_SHOW" )
frame:RegisterEvent( "TRADE_PLAYER_ITEM_CHANGED" )
frame:RegisterEvent( "TRADE_TARGET_ITEM_CHANGED" )
frame:RegisterEvent( "TRADE_CLOSED" )
frame:RegisterEvent( "TRADE_ACCEPT_UPDATE" )
frame:RegisterEvent( "TRADE_REQUEST_CANCEL" )
frame:SetScript( "OnEvent", eventHandler )

function ModUi.SimulateEvent( _, eventName )
  if not m_callbacks[ eventName ] then
    DebugMsg( string.format( "Event %s not found.", eventName or "N/A" ) )
    return
  end

  OnEvent( m_callbacks[ eventName ], false )
end

local function ProcessSlashCommand( component )
  if not component or component == "" then
    suspended = not suspended

    if suspended then
      ModUi:PrettyPrint( "suspended" )
    else
      ModUi:PrettyPrint( "resumed" )
    end

    return
  end

  if component == "version" then
    ModUi:PrettyPrint( string.format( "Version: %s", ModUi.utils.highlight( ModUi.version ) ) )
    return
  end

  local extension = ModUi:GetExtension( component )
  local mod = ModUi:GetModule( component )

  if not extension and not mod then
    ModUi:PrettyPrint( string.format( "Unknown component: |cffff9f69%s|r", component ) )
    return
  end

  local comp
  if extension then comp = extension end
  if mod then comp = mod end

  comp.suspended = not comp.suspended

  if comp.suspended then
    comp:PrettyPrint( "suspended" )
  else
    comp:PrettyPrint( "resumed" )
  end
end

function ModUi:OnInitialize()
  SLASH_MODUI1 = "/modui"
  api.SlashCmdList[ "MODUI" ] = ProcessSlashCommand

  self.db = libStub( "AceDB-3.0" ):New( "ModUiDb" )
  aceEvent:RegisterMessage( "HERB_COUNT_HERBS_AVAILABLE", function() OnEvent( m_callbacks.herbsAvailable, true ) end )
  m_initialized = true
end
