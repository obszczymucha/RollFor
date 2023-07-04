---@diagnostic disable: undefined-global
function IsInParty() return GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 end

function IsInRaid() return GetNumRaidMembers() > 0 end

function IsInGroup() return IsInParty() or IsInRaid() end
