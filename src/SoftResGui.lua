local modules = LibStub( "RollFor-Modules" )
if modules.SoftResGui then return end

local M = {}

local ace_gui = LibStub( "AceGUI-3.0" )
local pretty_print = modules.pretty_print

function M.new( origin )
  local softres_data
  local softres_data_dirty = false
  local softres_frame = nil

  local function show()
    softres_frame = ace_gui:Create( "Frame" )
    softres_frame.frame:SetFrameStrata( "DIALOG" )
    softres_frame:SetTitle( "SoftResLoot" )
    softres_frame:SetLayout( "Fill" )
    softres_frame:SetWidth( 565 )
    softres_frame:SetHeight( 300 )
    softres_frame:SetCallback( "OnClose",
      function( widget )
        if not softres_data_dirty then
          if not softres_data then
            pretty_print( "Invalid or no soft-res data found." )
          else
            origin.check_softres()
          end
        else
          origin.update_softres_data( softres_data )
          softres_data_dirty = false
          origin.check_softres()
        end

        ace_gui:Release( widget )
      end
    )

    softres_frame:SetStatusText( "" )

    local importEditBox = ace_gui:Create( "MultiLineEditBox" )
    importEditBox:SetFullWidth( true )
    importEditBox:SetFullHeight( true )
    importEditBox:DisableButton( true )
    importEditBox:SetLabel( "SoftRes.it data" )

    if softres_data then
      importEditBox:SetText( softres_data )
    end

    importEditBox:SetCallback( "OnTextChanged", function()
      softres_data_dirty = true
      softres_data = importEditBox:GetText()
    end )

    softres_frame:AddChild( importEditBox )
  end

  local function load( data )
    softres_data = data
  end

  return {
    show = show,
    load = load
  }
end

modules.SoftResGui = M
return M
