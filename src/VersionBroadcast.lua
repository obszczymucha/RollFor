local lib_stub = LibStub
local modules = lib_stub( "RollFor-Modules" )
if modules.VersionBroadcast then return end

local M = {}

local ace_comm = lib_stub( "AceComm-3.0" )
local comm_prefix = "RollFor"

local function version_recently_reminded()
  if not RollForDb.rollfor.last_new_version_reminder_timestamp then return false end

  local time = modules.lua.time()

  -- Only remind once a day
  if time - RollForDb.rollfor.last_new_version_reminder_timestamp > 3600 * 24 then
    return false
  else
    return true
  end
end

local function strip_dots( v )
  local result, _ = v:gsub( "%.", "" )
  return result
end

function M.new( version )
  local was_in_group = false

  local function update_group_status()
    was_in_group = modules.api.IsInGroup() or modules.api.IsInRaid()
  end

  local function broadcast_version( target )
    ace_comm:SendCommMessage( comm_prefix, "VERSION::" .. version, target )
  end

  local function broadcast_version_to_the_guild()
    if not modules.api.IsInGuild() then return end
    broadcast_version( "GUILD" )
  end

  local function is_new_version( v )
    local myVersion = tonumber( strip_dots( version ) )
    local theirVersion = tonumber( strip_dots( v ) )

    return theirVersion > myVersion
  end

  local function broadcast_version_to_the_group()
    if not modules.api.IsInGroup() and not modules.api.IsInRaid() then return end
    broadcast_version( modules.api.IsInRaid() and "RAID" or "PARTY" )
  end

  local function on_joined_group()
    if not was_in_group then
      broadcast_version_to_the_group()
    end

    update_group_status()
  end

  local function on_left_group()
    update_group_status()
  end

  -- OnComm(prefix, message, distribution, sender)
  local function on_comm( prefix, message, _, _ )
    if prefix ~= comm_prefix then return end

    local cmd, value = modules.lua.strmatch( message, "^(.*)::(.*)$" )

    if cmd == "VERSION" and is_new_version( value ) and not version_recently_reminded() then
      RollForDb.rollfor.last_new_version_reminder_timestamp = modules.lua.time()
      modules.pretty_print( string.format( "New version (%s) is available!", modules.highlight( string.format( "v%s", value ) ) ) )
    end
  end

  local function broadcast()
    broadcast_version_to_the_guild()
    broadcast_version_to_the_group()
    update_group_status()
  end

  ace_comm:RegisterComm( comm_prefix, on_comm )

  return {
    on_joined_group = on_joined_group,
    on_left_group = on_left_group,
    broadcast = broadcast
  }
end

modules.VersionBroadcast = M
return M
