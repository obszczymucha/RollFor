local function SoftResPlayerNameOverride( args )
  if not softResPlayerNameOverrideOptions or not args or args == "" then
    CreateSoftResPlayerNameOverrideOptions()
    ShowSoftResPlayerNameOverrideOptions()
    return
  end

  local count = M:CountElements( softResPlayerNameOverrideOptions )
  local matched = false
  local target = api.UnitName( "target" )

  if target and IsPlayerAlreadyOverridingAName( target ) then
    softResPlayerNameOverrideOptions = nil
    local f = function( value )
      return function( v )
        return v[ "override" ] == value
      end
    end

    M:PrettyPrint( string.format( "Player |cffff2f2f%s|r is already overriding |cffff9f69%s|r!", target,
      M:GetKeyByValue( softResPlayerNameOverrides, f( target ) ) ) )
    return
  end

  for i in (args):gmatch "(%d+)" do
    if not matched then
      local index = tonumber( i )

      if index > 0 and index <= count and target then
        matched = true
        local player = softResPlayerNameOverrideOptions[ index ]
        softResPlayerNameOverrides[ player ] = { [ "override" ] = target, [ "similarity" ] = 0 }
        ModUiDb.rollfor.softResPlayerNameOverrides = softResPlayerNameOverrides

        M:PrettyPrint( string.format( "|cffff9f69%s|r is now soft-ressing as |cffff9f69%s|r.", target, player ) )
        local count = M:CountElements( softResPlayerNameOverrideOptions )

        if count == 0 then
          ReportSoftResReady()
        end
      end
    end
  end

  if matched then
    softResPlayerNameOverrideOptions = nil
  else
    CreateSoftResPlayerNameOverrideOptions()
    ShowSoftResPlayerNameOverrideOptions()
  end
end

