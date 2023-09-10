local modules = LibStub( "RollFor-Modules" )
if modules.SoftResGui then return end

local M                = {}

--local softres_data     = "eNqllE1r4zAQhv/LnH1wXMuOfWt7WhaaQndPJYfBmsQishRG0i5syH9fmVBQoZVbfJwPzzyaeT0XmMijRI/QX0BJ6MGLcBA1FKCM82gGir4TMkbPqKQkA/0BtaMCBib0JO899Jumq6u6KzdVAeEs37lFVZdNAYxKvnhk7+aICVoXoO1wumXebKncYFn+Zh2bxobG+rk9XAtw9uCZHPEfctC/XoCt1g/WhGiVBZx1cDtDN8PgNH+2G0dUE/IpVho0uhiEv8isLCe140M9Tbea8wCqbVt3aTgCEce61+Itoak2HyRsrvs5ZZnrB1tzCJxQSQ6xcoapa8U2y9S1zSqmFzJuDAnSmRU5n52TKNv8nNq2XMP0k4NEfr+8WTFZqKa9y0N9TP1lqMdRHY8J0xiMpwU9iaU51at296zJn/E7cvpkMylS06yaEtt/qBOkCY+0IPBmQeCiW0P0K7h0RG7ECU1eSWX2DNyV9XaVvJ8GCj7941CjVHkmUW0XTlMrPmHax/uNLJMbur/+B/fD0T0="

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

local function create_frame( api, on_close, on_dirty )
  local frame = api().CreateFrame( "Frame", "RollForSoftResLootFrame", UIParent )
  frame:SetWidth( 565 )
  frame:SetHeight( 300 )
  frame:SetPoint( "CENTER", UIParent, "CENTER", 0, 0 )
  frame:EnableMouse()
  frame:SetMovable( true )
  frame:SetResizable( true )
  frame:SetFrameStrata( "DIALOG" )

  frame:SetBackdrop( frame_backdrop )
  frame:SetBackdropColor( 0, 0, 0, 1 )
  frame:SetScript( "OnHide", on_close )
  frame:SetMinResize( 400, 200 )
  frame:SetToplevel( true )

  local backdrop = api().CreateFrame( "Frame", nil, frame )
  backdrop:SetBackdrop( control_backdrop )
  backdrop:SetBackdropColor( 0, 0, 0 )
  backdrop:SetBackdropBorderColor( 0.4, 0.4, 0.4 )

  backdrop:SetPoint( "TOPLEFT", frame, "TOPLEFT", 17, -18 )
  backdrop:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 43 )

  local scroll_frame = api().CreateFrame( "ScrollFrame", "a@ScrollFrame@c", backdrop, "UIPanelScrollFrameTemplate" )
  scroll_frame:SetPoint( "TOPLEFT", 5, -6 )
  scroll_frame:SetPoint( "BOTTOMRIGHT", -28, 6 )
  scroll_frame:EnableMouse( true )

  local scroll_child = api().CreateFrame( "Frame", nil, scroll_frame )
  scroll_frame:SetScrollChild( scroll_child )
  scroll_child:SetHeight( 2 )
  scroll_child:SetWidth( 2 )

  local editbox = api().CreateFrame( "EditBox", nil, scroll_child )
  editbox:SetPoint( "TOPLEFT" )
  editbox:SetHeight( 50 )
  editbox:SetWidth( 50 )
  editbox:SetMultiLine( true )
  editbox:SetTextInsets( 5, 5, 3, 3 )
  editbox:EnableMouse( true )
  editbox:SetAutoFocus( false )
  editbox:SetFontObject( ChatFontNormal )
  frame.editbox = editbox

  editbox:SetScript( "OnEscapePressed", editbox.ClearFocus )
  scroll_frame:SetScript( "OnMouseUp", function() editbox:SetFocus() end )

  editbox:SetScript( "OnTextChanged", function( _, ... )
    scroll_frame:UpdateScrollChildRect()
    on_dirty()
  end )

  local function fix_size()
    scroll_child:SetHeight( scroll_frame:GetHeight() )
    scroll_child:SetWidth( scroll_frame:GetWidth() )
    editbox:SetWidth( scroll_frame:GetWidth() )
  end

  scroll_frame:SetScript( "OnShow", fix_size )
  scroll_frame:SetScript( "OnSizeChanged", fix_size )

  local close_button = api().CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  close_button:SetScript( "OnClick", function() frame:Hide() end )
  close_button:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -27, 17 )
  close_button:SetHeight( 20 )
  close_button:SetWidth( 100 )
  close_button:SetText( "Close" )

  do
    local cursor_offset, cursor_height
    local idle_time

    local function fix_scroll( _, elapsed )
      if cursor_offset and cursor_height then
        idle_time = 0
        local height = scroll_frame:GetHeight()
        local range = scroll_frame:GetVerticalScrollRange()
        local scroll = scroll_frame:GetVerticalScroll()
        cursor_offset = -cursor_offset

        while cursor_offset < scroll do
          scroll = scroll - (height / 2)
          if scroll < 0 then scroll = 0 end
          scroll_frame:SetVerticalScroll( scroll )
        end

        while cursor_offset + cursor_height > scroll + height and scroll < range do
          scroll = scroll + (height / 2)
          if scroll > range then scroll = range end
          scroll_frame:SetVerticalScroll( scroll )
        end
      elseif not idle_time or idle_time > 2 then
        frame:SetScript( "OnUpdate", nil )
        idle_time = nil
      else
        idle_time = idle_time + elapsed
      end

      cursor_offset = nil
    end

    editbox:SetScript( "OnCursorChanged", function( _, _, y, _, h )
      cursor_offset, cursor_height = y, h
      if not idle_time then
        frame:SetScript( "OnUpdate", fix_scroll )
      end
    end )
  end

  local label = frame:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  label:SetPoint( "BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 22 )
  label:SetTextColor( 1, 1, 1, 1 )
  label:SetText( string.format( "%s  %s", modules.colors.blue( "RollFor" ), "Soft-Res data import" ) )

  return frame
end

function M.new( api, import_encoded_softres_data, softres_check )
  local softres_data
  local dirty = false
  local frame

  local function on_close()
    if dirty and softres_data then
      dirty = false
      import_encoded_softres_data( softres_data, function()
        softres_check.check_softres()
      end )
    end
  end

  local function on_dirty()
    if dirty then
      softres_data = frame.editbox:GetText()
      return
    end

    local text = frame.editbox:GetText()
    if text == "" then text = nil end

    if softres_data ~= text then
      dirty = true
      softres_data = text
    end
  end

  local function show()
    if not frame then frame = create_frame( api, on_close, on_dirty ) end
    frame.editbox:SetText( softres_data or "" )
    frame:Show()
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
