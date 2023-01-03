---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local M = libStub:NewLibrary( "RollFor-Settings", 1 )
if not M then return end

M.lootQualityThreshold = 4

return M
