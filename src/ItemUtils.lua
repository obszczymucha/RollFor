---@diagnostic disable-next-line: undefined-global
local libStub = LibStub
local M = libStub:NewLibrary( "ItemUtils", 1 )
if not M then return end

function M.get_item_id( item_link )
  for item_id in (item_link):gmatch "|c%x%x%x%x%x%x%x%x|Hitem:(%d+):.+|r" do
    return tonumber( item_id )
  end

  return nil
end

function M.get_item_name( item_link )
  return string.gsub( item_link, "|c%x%x%x%x%x%x%x%x|Hitem:%d+.*|h%[(.*)%]|h|r", "%1" )
end

function M.parse_all_links( item_links )
  local result = {}
  if not item_links then return result end

  for item_link in (item_links):gmatch "|c%x%x%x%x%x%x%x%x|Hitem:[^%]]+%]|h|r" do
    table.insert(result, item_link)
  end

  return result
end

return M
