ModUi = LibStub:NewLibrary( "ModUi-1.0", 2 )

if not ModUi then
	return
end

local console = LibStub( "AceConsole-3.0" )
local event = LibStub( "AceEvent-3.0" )
local timer = LibStub( "AceTimer-3.0" )
local comm = LibStub( "AceComm-3.0" )

function ModUi:OnInitialize()
	self.db = LibStub( "AceDB-3.0" ):New( "ModUiDb" )
	event:RegisterMessage( "HERB_COUNT_HERBS_AVAILABLE", function() OnEvent( callbacks.herbsAvailable, true ) end )
end

local callbacks = {}
local modules = {}
local extensions = {}
local debugFrame = ChatFrame3
local debug = true
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
				entry.component:DebugMsg( format( "event: %s", entry.name ) )
				entry.callback( ... )
			end
		end
	end
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
			if ModUi.Utils.TableContainsValue( entry.dependencies, component.name ) then
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
		DebugMsg = function( extension, message )
			if extension.debugFrame and ( debug or extension.debug ) then
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
		debugFrame = ModUiDebugFrame,
		DebugMsg = function( mod, message )
			if mod.debug and mod.debugFrame then mod.debugFrame:AddMessage( format( "|cff33ff99ModUi [|r|cffff9f69%s|r|cff33ff99]|r: %s", mod.name, message or "nil" ) ) end
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
		if extension.enabled and ModUi.Utils.TableContainsValue( component.requiredExtensions, extension.name ) and extension.ExtendComponent then
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

local function OnChatMsgOpening( message )
	if string.match( message, "You perform Herb Gathering on" ) then
		OnEvent( callbacks.herbGathered, true )
	end
end

local function OnUnitSpellcastChannelStop( unit, spell, something )
	if unit == "player" and spell == "Extract Gas" then
		OnEvent( callbacks[ "gasExtracted" ], false )
	end
end

local frame = CreateFrame( "FRAME", "ModUiFramesFrame" )

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
	elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		OnEvent( callbacks[ "groupChanged" ], true )
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
	elseif event == "CHAT_MSG_OPENING" then
		OnChatMsgOpening( ... )
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
		OnEvent( callbacks[ "combatLogEventUnfiltered" ], false, nil, ... )
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
	end
end

frame:RegisterEvent( "PLAYER_LOGIN" )
frame:RegisterEvent( "PLAYER_ENTERING_WORLD" )
frame:RegisterEvent( "PLAYER_REGEN_ENABLED" )
frame:RegisterEvent( "PLAYER_REGEN_DISABLED" )
frame:RegisterEvent( "PLAYER_ENTER_COMBAT" )
frame:RegisterEvent( "PLAYER_LEAVE_COMBAT" )
frame:RegisterEvent( "RAID_ROSTER_UPDATE" )
frame:RegisterEvent( "GROUP_JOINED" )
frame:RegisterEvent( "GROUP_LEFT" )
frame:RegisterEvent( "ZONE_CHANGED" )
frame:RegisterEvent( "ZONE_CHANGED_INDOORS" )
frame:RegisterEvent( "ZONE_CHANGED_NEW_AREA" )
frame:RegisterEvent( "CHAT_MSG_OPENING" )
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
	else
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
end

SLASH_MODUI1 = "/modui"
SlashCmdList[ "MODUI" ] = ProcessSlashCommand
