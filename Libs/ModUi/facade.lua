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
  UnitName = UnitName,
  ChatFrame1 = ChatFrame1,
  ChatFrame4 = ChatFrame4,
  GetSpellLink = GetSpellLink,
  SlashCmdList = SlashCmdList
}

M.lua = {
  format = format
}

