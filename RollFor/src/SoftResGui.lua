local modules = LibStub( "RollFor-Modules" )
if modules.SoftResGui then return end

local M                = {}

---@diagnostic disable-next-line: undefined-global
local UIParent         = UIParent
---@diagnostic disable-next-line: undefined-global
local ChatFontNormal   = ChatFontNormal

local frame_backdrop   = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

local control_backdrop = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local function create_frame( api, on_close )
  local frame = api().CreateFrame( "Frame", "RollForSoftResLootFrame", UIParent )
  frame:SetWidth( 565 )
  frame:SetHeight( 300 )
  frame:SetPoint( "CENTER", UIParent, "CENTER", 0, 0 )
  frame:EnableMouse()
  frame:SetMovable( true )
  frame:SetResizable( true )
  frame:SetFrameStrata( "DIALOG" )
  --frame:SetScript( "OnMouseDown", frameOnMouseDown )

  frame:SetBackdrop( frame_backdrop )
  frame:SetBackdropColor( 0, 0, 0, 1 )
  frame:SetScript( "OnHide", on_close )
  frame:SetMinResize( 400, 200 )
  frame:SetToplevel( true )

  local backdrop = api().CreateFrame( "Frame", nil, frame )
  backdrop:SetBackdrop( control_backdrop )
  backdrop:SetBackdropColor( 0, 0, 0 )
  backdrop:SetBackdropBorderColor( 0.4, 0.4, 0.4 )

  --backdrop:SetPoint( "TOPLEFT", frame, "TOPLEFT", 0, -20 )
  --backdrop:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 22 )
  backdrop:SetPoint( "TOPLEFT", frame, "TOPLEFT", 17, -27 )
  backdrop:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 40 )

  local scrollframe = api().CreateFrame( "ScrollFrame", "a@ScrollFrame@c", backdrop, "UIPanelScrollFrameTemplate" )
  scrollframe:SetPoint( "TOPLEFT", 5, -6 )
  scrollframe:SetPoint( "BOTTOMRIGHT", -28, 6 )

  local scrollchild = api().CreateFrame( "Frame", nil, scrollframe )
  scrollframe:SetScrollChild( scrollchild )
  scrollchild:SetHeight( 2 )
  scrollchild:SetWidth( 2 )

  local label = frame:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
  label:SetPoint( "TOPLEFT", frame, "TOPLEFT", 0, -2 )
  label:SetPoint( "TOPRIGHT", frame, "TOPRIGHT", 0, -2 )
  label:SetJustifyH( "LEFT" )
  label:SetHeight( 18 )

  local editbox = api().CreateFrame( "EditBox", nil, scrollchild )
  editbox:SetPoint( "TOPLEFT" )
  editbox:SetHeight( 50 )
  editbox:SetWidth( 50 )
  editbox:SetMultiLine( true )
  -- editbox:SetMaxLetters(7500)
  editbox:SetTextInsets( 5, 5, 3, 3 )
  editbox:EnableMouse( true )
  editbox:SetAutoFocus( false )
  editbox:SetFontObject( ChatFontNormal )

  local function fix_size()
    scrollchild:SetHeight( scrollframe:GetHeight() )
    scrollchild:SetWidth( scrollframe:GetWidth() )
    editbox:SetWidth( scrollframe:GetWidth() )
  end

  scrollframe:SetScript( "OnShow", fix_size )
  scrollframe:SetScript( "OnSizeChanged", fix_size )

  local close_button = api().CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  close_button:SetScript( "OnClick", function() frame:Hide() end )
  close_button:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -27, 17 )
  close_button:SetHeight( 20 )
  close_button:SetWidth( 100 )
  close_button:SetText( "Close" )

  return frame
end

function M.new( api, import_encoded_softres_data, softres_check )
  local softres_data
  local softres_data_dirty = false
  local softres_frame = nil
  local frame

  local function on_close()
    if softres_data_dirty and softres_data then
      softres_data_dirty = false
      import_encoded_softres_data( softres_data, function()
        softres_check.check_softres()
      end )
    end
  end

  local function show()
    if not frame then frame = create_frame( api, on_close ) end
    frame:Show()
    --local importEditBox = ace_gui:Create( "MultiLineEditBox" )
    --importEditBox:SetFullWidth( true )
    --importEditBox:SetFullHeight( true )
    --importEditBox:ShowButton( false )
    --importEditBox:SetLabel( "SoftRes.it data" )

    --if softres_data then
    --importEditBox:SetText( softres_data )
    --end

    --importEditBox:SetCallback( "OnTextChanged", function()
    --softres_data_dirty = true
    --softres_data = importEditBox:GetText()
    --end )

    --softres_frame:AddChild( importEditBox )
  end

  local function load( data )
    softres_data = data
  end

  local function clear()
    softres_data = nil
  end

  return {
    show = show,
    load = load,
    clear = clear
  }
end

modules.SoftResGui = M
return M
