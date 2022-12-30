---@diagnostic disable: undefined-global
local M = LibStub:NewLibrary( "ModUiFacade-1.0", 1 )
if not M then return end

M.api = {
  ChatFrame1 = ChatFrame1,
  ChatFrame4 = ChatFrame4,
  CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo,
  CreateFrame = CreateFrame,
  CreateMacro = CreateMacro,
  DeleteMacro = DeleteMacro,
  EditMacro = EditMacro,
  GetLootSlotInfo = GetLootSlotInfo,
  GetLootSlotLink = GetLootSlotLink,
  GetLootSlotType = GetLootSlotType,
  GetLootSourceInfo = GetLootSourceInfo,
  GetMacroIndexByName = GetMacroIndexByName,
  GetNumLootItems = GetNumLootItems,
  GetRaidRosterInfo = GetRaidRosterInfo,
  GetRealZoneText = GetRealZoneText,
  GetSpellLink = GetSpellLink,
  GetSubZoneText = GetSubZoneText,
  GetTalentInfo = GetTalentInfo,
  GetZoneText = GetZoneText,
  InCombatLockdown = InCombatLockdown,
  IsInGroup = IsInGroup,
  IsInGuild = IsInGuild,
  IsInRaid = IsInRaid,
  PlayMusic = PlayMusic,
  SendChatMessage = SendChatMessage,
  SlashCmdList = SlashCmdList,
  StopMusic = StopMusic,
  UnitIsDead = UnitIsDead,
  UnitIsFriend = UnitIsFriend,
  UnitIsPlayer = UnitIsPlayer,
  UnitLevel = UnitLevel,
  UnitName = UnitName
}

M.lua = {
  format = format,
  time = time,
  strmatch = strmatch
}
