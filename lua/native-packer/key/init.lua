--- @class NativePacker.Key.Options: vim.keymap.set.Opts
--- @field ft? string|string[]
--- @field exclude_ft? string|string[]
--- @field event? NativePacker.Plugin.Spec.Event
--- @field depend? string|string[]

--- @class NativePacker.DelKey.Options: vim.keymap.del.Opts

--- @class NativePacker.Key.Modes: NativePacker.Key.Options
--- @field [integer] NativePacker.Key.Mode

--- @alias NativePacker.Key.Rhs string|fun()

--- @alias NativePacker.Key.Mode
--- |string
--- |NativePacker.Key.Modes

--- @class NativePacker.Key.SingleModeConfig: NativePacker.Key.Options
--- @field [1] NativePacker.Key.Rhs
--- @field [2] NativePacker.Key.Mode

--- @class NativePacker.Key.MultiModeConfig: NativePacker.Key.Options
--- @field [integer] NativePacker.Key.SingleModeConfig

--- @alias NativePacker.Key.Config
--- |NativePacker.Key.SingleModeConfig
--- |NativePacker.Key.MultiModeConfig

--- @class NativePacker.DelKey.MultiModeConfig: vim.keymap.del.Opts
--- @field [integer] NativePacker.DelKey.Config

--- @alias NativePacker.DelKey.Config
--- |string
--- |NativePacker.DelKey.MultiModeConfig

--- @alias NativePacker.Key table<string, NativePacker.Key.Config>

--- @alias NativePacker.DelKey table<string, NativePacker.DelKey.Config>

local M = {}

--- @param source NativePacker.Key
function M.add(source, set)
  require("native-packer.key.core").add(source, set)
end

--- @param source NativePacker.DelKey
function M.del(source)
  require("native-packer.key.core").del(source)
end

--- @param lhs string|"ALL"
function M.get(lhs)
  require("native-packer.key.core").get(lhs)
end

return M
