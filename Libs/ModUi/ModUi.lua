local version = 3
local M = LibStub:NewLibrary( "ModUi-1.0", version )

if not M then
	return
end

ModUi = M
ModUi.version = version

local console = LibStub( "AceConsole-3.0" )
local event = LibStub( "AceEvent-3.0" )
local timer = LibStub( "AceTimer-3.0" )
local comm = LibStub( "AceComm-3.0" )

ModUi.callbacks = ModUi.callbacks or {}
local callbacks = ModUi.callbacks
ModUi.modules = ModUi.modules or {}
local modules = ModUi.modules
ModUi.extensions = ModUi.extensions or {}
local extensions = ModUi.extensions

local debugFrame = ChatFrame3
local debug = false
local suspended = false

local combatParams = {
	combat = false,
	regenEnabled = true
}

function ModUi:Print( ... )
	return console:Print( ... )
end

function ModUi:PrettyPrint( message )
	ModUi:Print( format( "[|cff33ff99ModUi|r]: %s", message ) )
end

function ModUi:ScheduleTimer( ... )
	return timer:ScheduleTimer( ... )
end

function ModUi:ScheduleRepeatingTimer( ... )
	return timer:ScheduleRepeatingTimer( ... )
end

function ModUi:CancelTimer( ... )
	return timer:CancelTimer( ... )
end

function ModUi:RegisterComm( ... )
	return comm:RegisterComm( ... )
end

function ModUi:SendMessage( ... )
	return event:SendMessage( ... )
end

function ModUi:SendCommMessage( ... )
	return comm:SendCommMessage( ... )
end

local function OnEvent( callbacks, combatLockCheck, componentName, ... )
	for _, entry in ipairs( callbacks ) do
		if not componentName or entry.component.name == componentName then
			if not suspended and entry.component.enabled and not entry.component.suspended and ( not combatLockCheck or not InCombatLockdown() ) then
--				entry.component:DebugMsg( format( "event: %s", entry.name ) )
				entry.callback( ... )
			end
		end
	end
end

function ModUi:OnInitialize()
	self.db = LibStub( "AceDB-3.0" ):New( "ModUiDb" )
	event:RegisterMessage( "HERB_COUNT_HERBS_AVAILABLE", function() OnEvent( callbacks.herbsAvailable, true ) end )
end

local function RegisterCallback( callbackName )
	if not callbacks[ callbackName ] then callbacks[ callbackName ] = {} end

	return
	function( component, callback, dependencies )
		if not component then
			error( format( "No self provided in %s event callback. Hint: use : insted of .", callbackName ) )
			return
		end

		if not callback then
			error( format( "No callback provided for %s event in %s component.", callbackName, component.name ) )
			return
		end

		local callbacks = callbacks[ callbackName ]
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
		OnEvent( callbacks[ callbackName ], true, nil, ... )
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
end

local function DebugMsg( message )
	if not debug then return end
	debugFrame:AddMessage( format( "|cff33ff99ModUi|r: %s", message ) )
end

function ModUi.NewExtension( _, extensionName, requiredExtensions )
	if not extensionName then
		error( "No extension name provided." )
		return
	end

	if extensions[ extensionName ] then
		error( format( "Extension %s is already defined.", extensionName ) )
		return
	end

	local extension = {
		name = extensionName,
		requiredExtensions = requiredExtensions,
		enabled = true,
		suspended = false,
		debug = false,
		debugFrame = ChatFrame3,
		DebugMsg = function( extension, message, force )
			if extension.debugFrame and ( debug or extension.debug or force ) then
				extension.debugFrame:AddMessage( format( "|cff33ff99ModUi [|r|cff209ff9%s|r|cff33ff99]|r: %s", extension.name, message ) )
			end
		end,
		RegisterCallback = function( extension, callbackName )
			if extension.enabled then
				return RegisterCallback( callbackName )
			else
				return function( extension ) extension:DebugMsg( "Extension disabled.") end, function( extension ) extension:DebugMsg( "Extension disabled.") end
			end
		end,
		PrettyPrint = function( mod, message ) ChatFrame1:AddMessage( format( "|cff33ff99ModUi [|r|cff209ff9%s|r|cff33ff99]|r: %s", mod.name, message ) ) end
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

function ModUi.NewModule( _, moduleName, requiredExtensions )
	if not moduleName then
		error( "No module name provided." )
		return
	end

	if modules[ moduleName ] then
		error( format( "Module %s is already defined.", moduleName ) )
		return
	end

	local mod = {
		name = moduleName,
		requiredExtensions = requiredExtensions,
		enabled = true,
		suspended = false,
		debug = debug,
		debugFrame = ChatFrame3,
		DebugMsg = function( mod, message, force )
			if mod.debugFrame and ( mod.debug or force ) then mod.debugFrame:AddMessage( format( "|cff33ff99ModUi [|r|cffff9f69%s|r|cff33ff99]|r: %s", mod.name, message or "nil" ) ) end
		end,
		Initialize = function( mod ) mod:DebugMsg( "No Initialize() found." ) end, -- Override in a module
		PrettyPrint = function( mod, message ) ModUi:Print( format( "|cff33ff99ModUi [|r|cffff9f69%s|r|cff33ff99]|r: %s", mod.name, message ) ) end
	}

	AddBlizzEventCallbackFunctionsToComponent( mod )
	ModUi.AddUtilityFunctionsToModule( combatParams, mod )
	modules[ moduleName ] = mod

	return mod
end

local function ExtendComponent( component )
	for _, extension in pairs( extensions ) do
		if extension.enabled and ModUi.utils.TableContainsValue( component.requiredExtensions, extension.name ) and extension.ExtendComponent then
			component:DebugMsg( format( "Extending with |cff209ff9%s|r", extension.name ) )
			extension.ExtendComponent( component )
		end
	end
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
					mod:DebugMsg( format( "Disabled: Extension |cff209ff9%s|r not available", extensionName ) )
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
		OnEvent( callbacks[ "gasExtracted" ], false )
	end
end

local function OnUnitSpellcastStart( who, id, spellId )
	if spellId == 2366 then
		OnEvent( callbacks.herbGathered, true )
		return
	end
end

local function eventHandler( frame, event, ... )
    if event == "PLAYER_LOGIN" then
		ModUi:OnInitialize()
		ExtendExtensions()
		InitializeComponents( extensions )
		ExtendModules()
		DisableModulesWithoutExtensions()
		InitializeComponents( modules )
		OnEvent( callbacks[ "login" ], false )
    elseif event == "PLAYER_ENTERING_WORLD" then
		if not firstEnterWorld then
			OnEvent( callbacks[ "firstEnterWorld" ], false )
			firstEnterWorld = true
		end
		OnEvent( callbacks[ "enterWorld" ], false )
    elseif event == "PLAYER_REGEN_ENABLED" then
		combatParams.regenEnabled = true
		OnEvent( callbacks[ "regenEnabled" ], true )
	elseif event == "PLAYER_REGEN_DISABLED" then
		combatParams.regenEnabled = false
		OnEvent( callbacks[ "regenDisabled" ], true )
	elseif event == "PLAYER_ENTER_COMBAT" then
		combatParams.combat = true
		OnEvent( callbacks[ "enterCombat" ], true )
	elseif event == "PLAYER_LEAVE_COMBAT" then
		combatParams.combat = false
		OnEvent( callbacks[ "leaveCombat" ], true )
	elseif event == "RAID_ROSTER_UPDATE" then
		OnEvent( callbacks[ "groupChanged" ], true )
	elseif event == "GROUP_ROSTER_UPDATE" then
		OnEvent( callbacks[ "groupChanged" ], true )
	elseif event == "GROUP_FORMED" then
		OnEvent( callbacks[ "groupFormed" ], true )
	elseif event == "GROUP_JOINED" then
		OnEvent( callbacks[ "joinedGroup" ], true )
	elseif event == "GROUP_LEFT" then
		OnEvent( callbacks[ "leftGroup" ], true )
	elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
		OnEvent( callbacks[ "zoneChanged" ], true )
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		OnEvent( callbacks[ "areaChanged" ], true )
	elseif event == "UPDATE_WORLD_STATES" then
		OnEvent( callbacks[ "worldStatesUpdated" ], true )
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		OnUnitSpellcastChannelStop( ... )
	elseif event == "PARTY_INVITE_REQUEST" then
		OnEvent( callbacks[ "partyInviteRequest" ], false, nil, ... )
	elseif event == "CHAT_MSG_SYSTEM" then
		OnEvent( callbacks[ "chatMsgSystem" ], false, nil, ... )
	elseif event == "READY_CHECK" then
		OnEvent( callbacks[ "readyCheck" ], false )
	elseif event == "PLAYER_TARGET_CHANGED" then
		OnEvent( callbacks[ "targetChanged" ], true )
	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		OnEvent( callbacks[ "actionBarSlotChanged" ], true )
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		OnEvent( callbacks[ "combatLogEventUnfiltered" ], false, nil, CombatLogGetCurrentEventInfo() )
	elseif event == "UPDATE_PENDING_MAIL" then
		OnEvent( callbacks[ "pendingMail" ], false, nil, ... )
	elseif event == "BAG_UPDATE" then
		OnEvent( callbacks[ "bagUpdate" ], false, nil, ... )
	elseif event == "CHAT_MSG_WHISPER" then
		OnEvent( callbacks[ "whisper" ], false, nil, ... )
	elseif event == "CHAT_MSG_PARTY" then
		OnEvent( callbacks[ "partyMessage" ], false, nil, ... )
	elseif event == "CHAT_MSG_PARTY_LEADER" then
		OnEvent( callbacks[ "partyLeaderMessage" ], false, nil, ... )
	elseif event == "CHAT_MSG_SKILL" then
		OnEvent( callbacks[ "skillIncreased" ], false, nil, ... )
	elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
		OnEvent( callbacks[ "honorGain" ], false, nil, ... )
	elseif event == "UNIT_SPELLCAST_START" then
		OnUnitSpellcastStart( ... )
	elseif event == "AREA_POIS_UPDATED" then
		OnEvent( callbacks[ "areaPoisUpdated" ], false, nil, ... )
	elseif event == "GOSSIP_SHOW" then
		OnEvent( callbacks[ "gossipShow" ], false, nil, ... )
	elseif event == "MERCHANT_SHOW" then
		OnEvent( callbacks[ "merchantShow" ], false, nil, ... )
  elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
    OnEvent( callbacks[ "specChanged" ], false, nil, ... )
  elseif event == "LOOT_READY" then
    OnEvent( callbacks[ "lootReady" ], false, nil, ... )
	end
end

ModUi.frame = ModUi.frame or CreateFrame( "FRAME", "ModUiFrame" )
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
frame:SetScript( "OnEvent", eventHandler )

function ModUi.SimulateEvent( _, eventName )
	if not callbacks[ eventName ] then
		DebugMsg( format( "Event %s not found." ), eventName )
		return
	end

	OnEvent( callbacks[ eventName ], false )
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
		ModUi:PrettyPrint( format( "Version: %s", ModUi.utils.highlight( ModUi.version ) ) )
		return
	end

	local extension = ModUi:GetExtension( component )
	local mod = ModUi:GetModule( component )

	if not extension and not mod then
		ModUi:PrettyPrint( format( "Unknown component: |cffff9f69%s|r", component ) )
		return
	end

	local component
	if extension then component = extension end
	if mod then component = mod end

	component.suspended = not component.suspended

	if component.suspended then
		component:PrettyPrint( "suspended" )
	else
		component:PrettyPrint( "resumed" )
	end
end

SLASH_MODUI1 = "/modui"
SlashCmdList[ "MODUI" ] = ProcessSlashCommand
