local modules = LibStub( "RollFor-Modules" )
if modules.SoftResGui then return end

local M = {}

local ace_gui = LibStub( "AceGUI-3.0" )
local pretty_print = modules.pretty_print

local m_softres_frame = nil
local m_softres_data = nil
local m_softres_data_dirty = false

function M.show( origin )
  m_softres_frame = ace_gui:Create( "Frame" )
  m_softres_frame.frame:SetFrameStrata( "DIALOG" )
  m_softres_frame:SetTitle( "SoftResLoot" )
  m_softres_frame:SetLayout( "Fill" )
  m_softres_frame:SetWidth( 565 )
  m_softres_frame:SetHeight( 300 )
  m_softres_frame:SetCallback( "OnClose",
    function( widget )
      if not m_softres_data_dirty then
        if not m_softres_data then
          pretty_print( "Invalid or no soft-res data found." )
        else
          origin.check_softres()
        end
      else
        origin.update_softres_data( m_softres_data )
        m_softres_data_dirty = false
        origin.check_softres()
      end

      ace_gui:Release( widget )
    end
  )

  m_softres_frame:SetStatusText( "" )

  local importEditBox = ace_gui:Create( "MultiLineEditBox" )
  importEditBox:SetFullWidth( true )
  importEditBox:SetFullHeight( true )
  importEditBox:DisableButton( true )
  importEditBox:SetLabel( "SoftRes.it data" )

  if m_softres_data then
    importEditBox:SetText( m_softres_data )
  end

  importEditBox:SetCallback( "OnTextChanged", function()
    m_softres_data_dirty = true
    m_softres_data = importEditBox:GetText()
  end )

  m_softres_frame:AddChild( importEditBox )
end

modules.SoftResGui = M
return M
