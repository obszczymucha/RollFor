---@diagnostic disable-next-line: undefined-global
local facade = LibStub( "ModUiFacade-1.0" )
local api = facade.api
local lua = facade.lua

local get_index = api.GetMacroIndexByName

local create = function( name, body, global, icon )
  local index = get_index( name )
  if index ~= 0 then return end

  api.CreateMacro( name, icon or "INV_MISC_QUESTIONMARK", body or "", not global and 1 or nil )
end

local edit = function( name, body, global, icon )
  local index = get_index( name )
  if index == 0 then return end

  api.EditMacro( index, nil, icon, body, true, not global and 1 or nil )
end

local builder = function( macro )
  local function group_consecutive_entries( commands )
    local result = {}
    local current_command = nil
    local current_list = {}

    local function should_group( command )
      return command == "use" or command == "cast"
    end

    local function flush()
      if #current_list > 0 then
        table.insert( result, { command = current_command, values = current_list } )
        current_command = nil
        current_list = {}
      end
    end

    if #commands == 0 then
      return {}
    end

    for _, v in ipairs( commands ) do
      if should_group( v.command ) then
        if current_command == v.command then
          table.insert( current_list, v )
        else
          flush()

          current_command = v.command
          current_list = {}
          table.insert( current_list, v )
        end
      else
        flush()
        table.insert( result, v )
      end
    end

    flush()
    return result
  end

  local function transform_command( command, values )
    local result = lua.format( "/%s ", command )

    for i, v in ipairs( values ) do
      if i > 1 then result = result .. ";" end

      result = result .. lua.format( "%s%s", v.modifiers and lua.format( "[%s]", v.modifiers ) or "", v.spell )
    end

    return result
  end

  return {
    _tooltip = "",
    _commands = {},
    tooltip = function( self, modifiers )
      self._tooltip = lua.format( "#showtooltip%s\n", modifiers and lua.format( " %s", modifiers ) or "" )
      return self
    end,
    startattack = function( self, modifiers )
      table.insert( self._commands, { command = "startattack", modifiers = modifiers } )
      return self
    end,
    castsequence = function( self, spells, modifiers )
      if not spells then return self end

      table.insert( self._commands, { command = "castsequence", spells = spells, modifiers = modifiers } )
      return self
    end,
    use = function( self, spell, modifiers )
      if not spell then return self end

      table.insert( self._commands, { command = "use", spell = spell, modifiers = modifiers } )
      return self
    end,
    cast = function( self, spell, modifiers )
      if not spell then return self end

      table.insert( self._commands, { command = "cast", spell = spell, modifiers = modifiers } )
      return self
    end,
    dismount = function( self, modifiers )
      table.insert( self._commands, { command = "dismount", modifiers = modifiers } )
      return self
    end,
    cancelform = function( self, modifiers )
      table.insert( self._commands, { command = "cancelform", modifiers = modifiers } )
      return self
    end,
    build = function( self, macro_name )
      self._grouped_commands = group_consecutive_entries( self._commands )

      local body = self._tooltip or ""

      for i, v in ipairs( self._grouped_commands ) do
        if i > 1 then body = body .. "\n" end

        if v.command == "startattack" then
          body = body .. lua.format( "/startattack%s", v.modifiers and lua.format( " [%s]", v.modifiers ) or "" )
        elseif v.command == "castsequence" then
          body = body .. lua.format( "/castsequence %s%s", v.modifiers and lua.format( "[%s]", v.modifiers ) or "", v.spells )
        elseif v.command == "dismount" then
          body = body .. lua.format( "/dismount%s", v.modifiers and lua.format( " [%s]", v.modifiers ) or "" )
        elseif v.command == "cancelform" then
          body = body .. lua.format( "/cancelform%s", v.modifiers and lua.format( " [%s]", v.modifiers ) or "" )
        elseif v.command == "use" or v.command == "cast" then
          body = body .. transform_command( v.command, v.values )
        else
          ModUi:PrettyPrint( lua.format( "Cannot create macro. Command \"%s\" is not implemented.", v.command ) )
        end
      end

      if string.len( body ) > 255 then
        ModUi:PrettyPrint( lua.format( "Macro \"%s\" is too long!", macro_name ) )
      elseif macro_name then
        macro.edit( macro_name, body )
      end

      return self
    end
  }
end

facade.macro = {
  create = create,
  edit = function( name, body, global, icon )
    create( name, nil, global, icon )
    edit( name, body, global, icon )
  end,
  delete = function( name )
    local index = get_index( name )
    if index == 0 then return end

    api.DeleteMacro( index )
  end,
  tooltip = function( self, modifiers ) return builder( self ):tooltip( modifiers ) end
}

return facade.macro
