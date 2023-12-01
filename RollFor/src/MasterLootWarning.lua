local modules = LibStub( "RollFor-Modules" )
if modules.MasterLootWarning then return end

local M                    = {}
local red                  = modules.colors.red
local table_contains_value = modules.table_contains_value

---@diagnostic disable-next-line: undefined-global
local UIParent             = UIParent

local zones                = {
  "Blade's Edge Mountains",
  "Karazhan",
  "Gruul's Lair",
  "Magtheridon's Lair",
  "Serpentshrine Cavern",
  "Tempest Keep",
  "Black Temple",
  "Sunwell Plateau"
}

local function create_frame( api )
  local frame = api().CreateFrame( "FRAME", "RollForMasterLootWarning", UIParent )
  frame:Hide()

  local label = frame:CreateFontString( nil, "OVERLAY" )
  label:SetFont( "FONTS\\FRIZQT__.TTF", 24, "OUTLINE" )
  label:SetPoint( "TOPLEFT", 0, 0 )
  label:SetText( string.format( "No %s!", red( "Master Loot" ) ) )

  frame:SetWidth( label:GetWidth() )
  frame:SetHeight( label:GetHeight() )
  frame:SetPoint( "TOPLEFT", UIParent, "TOPLEFT", (UIParent:GetWidth() / 2) - (frame:GetWidth() / 2), -270 )

  return frame
end

function M.new( api, ace_timer )
  local frame

  local function show_and_fade_outn( seconds )
    if not frame or (frame.fadeInfo and frame.fadeInfo.finishedFunc) then return end

    frame:SetAlpha( 1 )
    frame:Show()

    ace_timer:ScheduleTimer( function()
      api().UIFrameFadeOut( frame, 2, 1, 0 )
      frame.fadeInfo.finishedFunc = function() frame:Hide() end
    end, seconds or 1 )
  end

  local function on_player_regen_disabled()
    local zone_name = api().GetRealZoneText()
    if not table_contains_value( zones, zone_name ) or not api().IsInRaid() or api().GetLootMethod() == "master" then return end

    if not frame then frame = create_frame( api ) end
    show_and_fade_outn( 10 )
  end

  return {
    on_player_regen_disabled = on_player_regen_disabled
  }
end

modules.MasterLootWarning = M
return M
