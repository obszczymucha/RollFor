local M = {}

function M.mock_api( ... )
  local result = {}

  for _, v in pairs( { ... } ) do
    -- Returning a function allows us to group multiple entries together.
    -- We then ungroup them and add them 1 by 1.
    if type( v ) == "function" then
      local values = v()

      for _, value in pairs( values ) do
        if value.smart_table then
          result[ value.function_name ] = function( key ) return value.value[ key ] end
        else
          result[ value.function_name ] = function() return value.value end
        end
      end
    elseif v.smart_table then
      result[ v.function_name ] = function( key ) return v.value[ key ] end
    else
      result[ v.function_name ] = function() return v.value end
    end
  end

  return function() return result end
end

function M.mock( function_name, ... )
  local values = { ... }

  if #values == 0 then
    return { function_name = function_name }
  end

  if #values > 1 and type( values[ 1 ] ) then
    return { function_name = function_name, value = values, smart_table = true }
  end

  local value = values[ 1 ]

  if type( value ) == "table" then
    return { function_name = function_name, value = value, smart_table = true }
  end

  return { function_name = function_name, value = value }
end

return M
