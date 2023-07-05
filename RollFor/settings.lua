if RollFor and RollFor.settings then return RollFor.settings end
local M = {}

M.announce_loot_quality_threshold = 4 -- 2: Uncommon, 3: Rare, 4: Epic
M.trade_tracker_debug = false

RollFor = RollFor or {}
RollFor.settings = M

return M
