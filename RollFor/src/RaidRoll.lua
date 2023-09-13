local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.RaidRoll then return end

local M = {}
local pretty_print = modules.pretty_print
local hl = modules.colors.hl

modules.RaidRoll = M
return M
