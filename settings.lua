---@diagnostic disable-next-line: undefined-global
if RollFor and RollFor.settings then return RollFor.settings end
local M = {}

M.lootQualityThreshold = 4
M.tradeTrackerDebug = false

RollFor = RollFor or {}
RollFor.settings = M
return M
