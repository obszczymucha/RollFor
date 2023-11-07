local modules = LibStub( "RollFor-Modules" )
if modules.MinimapButton then return end

local M = {}
local hl = modules.colors.hl
local blue = modules.colors.blue
local grey = modules.colors.grey
local white = modules.colors.white
local green = modules.colors.green
local red = modules.colors.red
local pretty_print = modules.pretty_print

local ColorType = {
  White = "White",
  Green = "Green",
  Orange = "Orange",
  Red = "Red"
}

function M.new( api, db, manage_softres_fn )
  local icon_color

  local function persist_angle( angle )
    db.char.minimap_angle = angle
  end

  local function get_angle()
    return db.char.minimap_angle
  end

  local function is_locked()
    return db.char.minimap_locked
  end

  local function is_hidden()
    return db.char.minimap_hidden
  end

  local function create()
    local frame = api().CreateFrame( "Button", "RollForMinimapButton", api().Minimap )

    function frame:OnClick()
      manage_softres_fn()
      self:OnEnter()
    end

    function frame:OnMouseDown()
      self.icon:SetTexCoord( 0, 1, 0, 1 )
    end

    function frame:OnMouseUp()
      self.icon:SetTexCoord( 0.05, 0.95, 0.05, 0.95 )
    end

    function frame:OnEnter()
      if not self.dragging then
        api().GameTooltip:SetOwner( self, "ANCHOR_LEFT" )
        api().GameTooltip:SetText( blue( "RollFor" ) )

        api().GameTooltip:AddLine( " " )
        api().GameTooltip:AddLine( string.format( "%s - show how to roll", hl( "/htr" ) ) )
        api().GameTooltip:AddLine( string.format( "%s %s - roll for", hl( "/rf" ), grey( "<item>" ) ) )
        api().GameTooltip:AddLine( string.format( "%s %s - raid roll", hl( "/rr" ), grey( "<item>" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - manage softres", hl( "/sr" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - fix player softres name", hl( "/sro" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - check softres status", hl( "/src" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - show softres items", hl( "/srs" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - toggle minimap button", hl( "/rfm" ) ) )
        api().GameTooltip:AddLine( string.format( "%s - lock/unlock minimap button", hl( "/rfl" ) ) )
        api().GameTooltip:AddLine( " " )
        api().GameTooltip:AddLine( white( "Click to manage softres." ) )

        if icon_color == ColorType.Green then
          api().GameTooltip:AddLine( " " )
          api().GameTooltip:AddLine( string.format( "%s %s", white( "Softres status:" ), green( "OK" ) ) )
        elseif icon_color == ColorType.Orange then
          api().GameTooltip:AddLine( " " )
          api().GameTooltip:AddLine( white( "Softres status:" ) )
          api().GameTooltip:AddLine( hl( "Not everyone is softressing!" ) )
        elseif icon_color == ColorType.Red then
          api().GameTooltip:AddLine( " " )
          api().GameTooltip:AddLine( white( "Softres status:" ) )
          api().GameTooltip:AddLine( red( "Found outdated softres data!" ) )
        end

        api().GameTooltip:Show()
      end
    end

    function frame:OnLeave()
      api().GameTooltip:Hide()
    end

    function frame:OnDragStart()
      self.dragging = true
      self:LockHighlight()
      self.icon:SetTexCoord( 0, 1, 0, 1 )
      self:SetScript( "OnUpdate", self.OnUpdate )
      api().GameTooltip:Hide()
    end

    function frame:OnDragStop()
      self.dragging = nil
      self:SetScript( "OnUpdate", nil )
      self.icon:SetTexCoord( 0.05, 0.95, 0.05, 0.95 )
      self:UnlockHighlight()
    end

    function frame:OnUpdate()
      local mx, my = api().Minimap:GetCenter()
      local px, py = api().GetCursorPosition()
      local scale = api().Minimap:GetEffectiveScale()

      px, py = px / scale, py / scale

      persist_angle( math.deg( math.atan2( py - my, px - mx ) ) % 360 )
      self:UpdatePosition()
    end

    -- Copy pasted from Bongos.
    --magic fubar code for updating the minimap button"s position
    --I suck at trig, so I"m not going to bother figuring it out
    function frame:UpdatePosition()
      local angle = math.rad( get_angle() or modules.lua.random( 0, 360 ) )
      local cos = math.cos( angle )
      local sin = math.sin( angle )
      local minimapShape = api().GetMinimapShape and api().GetMinimapShape() or "ROUND"

      local round = false
      if minimapShape == "ROUND" then
        round = true
      elseif minimapShape == "SQUARE" then
        round = false
      elseif minimapShape == "CORNER-TOPRIGHT" then
        round = not (cos < 0 or sin < 0)
      elseif minimapShape == "CORNER-TOPLEFT" then
        round = not (cos > 0 or sin < 0)
      elseif minimapShape == "CORNER-BOTTOMRIGHT" then
        round = not (cos < 0 or sin > 0)
      elseif minimapShape == "CORNER-BOTTOMLEFT" then
        round = not (cos > 0 or sin > 0)
      elseif minimapShape == "SIDE-LEFT" then
        round = cos <= 0
      elseif minimapShape == "SIDE-RIGHT" then
        round = cos >= 0
      elseif minimapShape == "SIDE-TOP" then
        round = sin <= 0
      elseif minimapShape == "SIDE-BOTTOM" then
        round = sin >= 0
      elseif minimapShape == "TRICORNER-TOPRIGHT" then
        round = not (cos < 0 and sin > 0)
      elseif minimapShape == "TRICORNER-TOPLEFT" then
        round = not (cos > 0 and sin > 0)
      elseif minimapShape == "TRICORNER-BOTTOMRIGHT" then
        round = not (cos < 0 and sin < 0)
      elseif minimapShape == "TRICORNER-BOTTOMLEFT" then
        round = not (cos > 0 and sin < 0)
      end

      local x, y
      if round then
        x = cos * 80
        y = sin * 80
      else
        x = math.max( -82, math.min( 110 * cos, 84 ) )
        y = math.max( -86, math.min( 110 * sin, 82 ) )
      end

      self:SetPoint( "CENTER", x, y )
    end

    frame:SetFrameStrata( "MEDIUM" )
    frame:SetWidth( 31 )
    frame:SetHeight( 31 )
    frame:SetFrameLevel( 8 )
    frame:RegisterForClicks( "anyUp" )
    frame:RegisterForDrag( "LeftButton" )
    frame:SetHighlightTexture( "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight" )

    local overlay = frame:CreateTexture( nil, "OVERLAY" )
    overlay:SetWidth( 53 )
    overlay:SetHeight( 53 )
    overlay:SetTexture( "Interface\\Minimap\\MiniMap-TrackingBorder" )
    overlay:SetPoint( "TOPLEFT" )

    local icon = frame:CreateTexture( nil, "BACKGROUND" )
    icon:SetWidth( 20 )
    icon:SetHeight( 20 )
    icon:SetTexCoord( 0.05, 0.95, 0.05, 0.95 )
    icon:SetPoint( "TOPLEFT", 7, -5 )
    frame.icon = icon

    frame:SetScript( "OnEnter", frame.OnEnter )
    frame:SetScript( "OnLeave", frame.OnLeave )
    frame:SetScript( "OnClick", frame.OnClick )

    frame:SetScript( "OnMouseDown", frame.OnMouseDown )
    frame:SetScript( "OnMouseUp", frame.OnMouseUp )

    frame:UpdatePosition()

    return frame
  end

  local frame = create()

  local function show()
    if is_hidden() then
      frame:Hide()
      pretty_print( string.format( "Minimap button is hidden. Type %s to show.", hl( "/rfm" ) ) )
    else
      frame:Show()
    end
  end

  local function lock()
    if is_locked() then
      frame:SetScript( "OnDragStart", nil )
      frame:SetScript( "OnDragStop", nil )
    else
      frame:SetScript( "OnDragStart", frame.OnDragStart )
      frame:SetScript( "OnDragStop", frame.OnDragStop )
    end
  end

  local function set_icon( color )
    frame.icon:SetTexture( string.format( "Interface\\AddOns\\RollFor\\assets\\icon-%s.tga", string.lower( color ) ) )
    icon_color = color
  end

  show()
  lock()
  set_icon( ColorType.Red )

  local function toggle()
    if is_hidden() then
      db.char.minimap_hidden = nil
    else
      db.char.minimap_hidden = true
    end

    show()
  end

  local function toggle_lock()
    if is_locked() then
      db.char.minimap_locked = nil
      pretty_print( "Minimap button unlocked." )
    else
      db.char.minimap_locked = true
      pretty_print( "Minimap button locked." )
    end

    lock()
  end

  return {
    toggle = toggle,
    toggle_lock = toggle_lock,
    set_icon = set_icon,
    ColorType = ColorType
  }
end

modules.MinimapButton = M
return M
