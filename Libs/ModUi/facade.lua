---@diagnostic disable: undefined-global
ModUi.facade = ModUi.facade or {}
local M = ModUi.facade

M.api = {
  GetMacroIndexByName = GetMacroIndexByName,
  CreateMacro = CreateMacro,
  EditMacro = EditMacro,
  DeleteMacro = DeleteMacro,
  InCombatLockdown = InCombatLockdown,
  GetZoneText = GetZoneText,
  GetSubZoneText = GetSubZoneText,
  GetRealZoneText = GetRealZoneText,
  UnitName = UnitName,
  ChatFrame1 = ChatFrame1,
  ChatFrame4 = ChatFrame4,
  GetSpellLink = GetSpellLink,
  SlashCmdList = SlashCmdList,
  GetTalentInfo = GetTalentInfo,
  UnitIsDead = UnitIsDead,
  UnitIsPlayer = UnitIsPlayer,
  UnitIsFriend = UnitIsFriend,
  UnitLevel = UnitLevel,
  StopMusic = StopMusic,
  PlayMusic = PlayMusic,
  IsInGroup = IsInGroup,
  IsInRaid = IsInRaid,
  IsInGuild = IsInGuild,
  SendChatMessage = SendChatMessage,
  GetNumLootItems = GetNumLootItems,
  GetLootSlotInfo = GetLootSlotInfo,
  GetLootSlotLink = GetLootSlotLink,
  GetLootSlotType = GetLootSlotType,
  GetLootSourceInfo = GetLootSourceInfo
}

M.lua = {
  format = format,
  time = time,
  strmatch = strmatch
}
