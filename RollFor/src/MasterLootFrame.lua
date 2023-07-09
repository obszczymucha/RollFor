local libStub = LibStub
local modules = libStub( "RollFor-Modules" )
if modules.MasterLootFrame then return end

local M = {}
local confirmation_dialog_key = "ROLLFOR_MASTER_LOOT_CONFIRMATION_DIALOG"

local button_width = 85
local button_height = 16
local horizontal_padding = 3
local vertical_padding = 5
local rows = 5

local function highlight( frame )
  frame:SetBackdropColor( frame.color.r, frame.color.g, frame.color.b, 0.3 )
end

local function dim( frame )
  frame:SetBackdropColor( 0.5, 0.5, 0.5, 0.1 )
end

local function press( frame )
  frame:SetBackdropColor( frame.color.r, frame.color.g, frame.color.b, 0.7 )
end

local function create_main_frame()
  local frame = modules.api.CreateFrame( "Frame", "RollForLootFrame" )
  frame:Hide()
  frame:SetBackdrop( {
    bgFile = "Interface\\Tooltips\\UI-tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  } )
  frame:SetBackdropColor( 0, 0, 0, 1 )
  frame:SetFrameStrata( "DIALOG" )
  frame:SetWidth( 100 )
  frame:SetHeight( 100 )
  frame:SetPoint( "CENTER", modules.api.UIParent, "Center" )
  frame:EnableMouse( true )
  frame:SetScript( "OnLeave",
    function( self )
      local mouse_x, mouse_y = modules.api.GetCursorPosition()
      local x, y = self:GetCenter()
      local width = self:GetWidth()
      local height = self:GetHeight()

      local is_over = mouse_x >= x - width / 2 and mouse_x <= x + width / 2 and mouse_y >= y - height / 2 and
          mouse_y <= y + height / 2

      if not is_over then self:Hide() end
    end )

  return frame
end

local function get_candidates( group_roster )
  local result = {}
  local players = group_roster.get_all_players_in_my_group()

  for i = 1, 40 do
    local name = modules.api.GetMasterLootCandidate( i )

    for _, p in ipairs( players ) do
      if name == p.name then
        table.insert( result, { name = name, class = p.class, value = i } )
      end
    end
  end

  return result
end

---@diagnostic disable-next-line: unused-function, unused-local
local function get_dummy_candidates()
  return {
    { name = "Ohhaimark",    class = "Warrior", value = 1 },
    { name = "Obszczymucha", class = "Druid",   value = 2 },
    { name = "Jogobobek",    class = "Hunter",  value = 3 },
    { name = "Xiaorotflmao", class = "Shaman",  value = 4 },
    { name = "Kacprawcze",   class = "Priest",  value = 5 },
    { name = "Psikutas",     class = "Paladin", value = 6 },
    { name = "Motoko",       class = "Rogue",   value = 7 },
    { name = "Blanchot",     class = "Warrior", value = 8 },
    { name = "Adamsandler",  class = "Druid",   value = 9 },
    { name = "Johnstamos",   class = "Hunter",  value = 10 },
    { name = "Xiaolmao",     class = "Shaman",  value = 11 },
    { name = "Ronaldtramp",  class = "Priest",  value = 12 },
    { name = "Psikuta",      class = "Paladin", value = 13 },
    { name = "Kusanagi",     class = "Rogue",   value = 14 },
    { name = "Chuj",         class = "Priest",  value = 15 },
  }
end

local function create_button( parent, index )
  local frame = modules.api.CreateFrame( "Button", "RollForLootFrameButton" .. index, parent )
  frame:SetWidth( button_width )
  frame:SetHeight( button_height )
  frame:SetPoint( "TOPLEFT", parent, "TOPLEFT", 5 + horizontal_padding + modules.api.math.floor( (index - 1) / rows ) * (button_width + horizontal_padding),
    -5 - vertical_padding - ((index - 1) % rows) * (button_height + vertical_padding) )
  frame:SetBackdrop( {
    bgFile = "Interface\\Buttons\\WHITE8x8"
  } )
  --dim( button )
  frame:SetNormalTexture( "" )
  frame.parent = parent

  local text = frame:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
  text:SetPoint( "CENTER", frame, "CENTER" )
  text:SetText( "" )
  frame.text = text

  frame:SetScript( "OnEnter", function( self ) highlight( self ) end )
  frame:SetScript( "OnLeave", function( self ) dim( self ) end )
  frame:SetScript( "OnMouseDown", function( self, button )
    if button == "LeftButton" then press( self ) end
  end )
  frame:SetScript( "OnMouseUp", function( self, button )
    if button == "LeftButton" then
      if modules.api.MouseIsOver( self ) then
        highlight( self )
      else
        dim( self )
      end
    end
  end )

  return frame
end

local function show_confirmation_dialog( item_name, item_quality, player_name )
  local colored_item_name = modules.colorize_item_by_quality( item_name, item_quality )
  return modules.api.StaticPopup_Show( confirmation_dialog_key, colored_item_name, player_name );
end

local function create_custom_confirmation_dialog_data( on_confirm )
  modules.api.StaticPopupDialogs[ confirmation_dialog_key ] = {
    text = "Are you sure you want to give %s to %s?",
    button1 = modules.api.YES,
    button2 = modules.api.NO,
    OnAccept = function( data )
      on_confirm( modules.api.LootFrame.selectedSlot, data )
    end,
    timeout = 0,
    hideOnEscape = 1,
  };
end

local function sort( candidates )
  table.sort( candidates,
    function( lhs, rhs )
      if lhs.class < rhs.class then
        return true
      elseif lhs.class > rhs.class then
        return false
      end

      return lhs.name < rhs.name
    end
  )
end

function M.new( group_roster )
  local m_frame
  local m_buttons = {}
  local m_dialog

  local function create( on_confirm )
    if m_frame then return end
    m_frame = create_main_frame()
    create_custom_confirmation_dialog_data( on_confirm )
  end

  local function hide_dialog()
    if m_dialog and m_dialog:IsVisible() then
      modules.api.StaticPopup_Hide( confirmation_dialog_key )
    end
  end

  local function create_candidate_frames()
    local candidates = get_candidates( group_roster )
    sort( candidates )
    local total = #candidates

    if total == 0 then
      return false
    end

    local columns = modules.api.math.ceil( total / rows )
    local total_rows = total < 5 and total or rows

    m_frame:SetWidth( (button_width + horizontal_padding) * columns + horizontal_padding + 11 )
    m_frame:SetHeight( (button_height + vertical_padding) * total_rows + vertical_padding + 11 )

    for i = 1, 40 do
      if i > total then
        if m_buttons[ i ] then m_buttons[ i ]:Hide() end
      else
        local candidate = candidates[ i ]

        if not m_buttons[ i ] then
          m_buttons[ i ] = create_button( m_frame, i )
        end

        local button = m_buttons[ i ]
        button.text:SetText( candidate.name )
        local color = modules.api.RAID_CLASS_COLORS[ candidate.class:upper() ]
        button.color = color
        button.value = candidate.value
        button.player_name = candidate.name

        if color then
          button.text:SetTextColor( color.r, color.g, color.b )
          dim( button )
        else
          button.text:SetTextColor( 1, 1, 1 )
        end

        button:SetScript( "OnClick", function( self )
          local item_name = modules.api.LootFrame.selectedItemName
          local item_quality = modules.api.LootFrame.selectedQuality

          hide_dialog()
          m_dialog = show_confirmation_dialog( item_name, item_quality, self.player_name )

          if (m_dialog) then
            m_dialog.data = { name = self.player_name, index = self.value }
          end
        end )

        button:Show()
      end
    end

    return true
  end

  local function show()
    if m_frame then m_frame:Show() end
  end

  local function hide()
    if m_frame then m_frame:Hide() end
    hide_dialog()
  end

  local function anchor( frame )
    m_frame:SetPoint( "TOPLEFT", frame, "BOTTOMLEFT", 0, 0 )
  end

  return {
    create = create,
    create_candidate_frames = create_candidate_frames,
    show = show,
    hide = hide,
    anchor = anchor
  }
end

modules.MasterLootFrame = M
return M
