ModUi.facade = ModUi.facade or {}
local M = ModUi.facade
local api = M.api

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

M.macro = {
  create = create,
  edit = function( name, body, global, icon )
    create( name, nil, global, icon )
    edit( name, body, global, icon )
  end,
  delete = function( name )
    local index = get_index( name )
    if index == 0 then return end

    api.DeleteMacro( index )
  end
}

