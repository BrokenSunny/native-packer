---@class NativePacker.KeySpec.Options: vim.keymap.set.Opts
---@field ft? string|string[]
---@field exclude_ft? string|string[]
---@field event? string|string[]
---@field context? any

---@class NativePacker.KeySpec.ModeBase: NativePacker.KeySpec.Options
---@field [integer] string|NativePacker.KeySpec.ModeBase

---@alias NativePacker.KeySpec.Mode
---|string
---|NativePacker.KeySpec.ModeBase

---@alias NativePacker.KeySpec.Rhs string|fun()

---@class NativePacker.KeySpec.SingleConfig: NativePacker.KeySpec.Options
---@field [1] NativePacker.KeySpec.Rhs
---@field [2] NativePacker.KeySpec.Mode

---@class NativePacker.KeySpec.MultiConfig: NativePacker.KeySpec.Options
---@field [integer] NativePacker.KeySpec.SingleConfig

---@alias NativePacker.KeySpec.Config
---| NativePacker.KeySpec.SingleConfig
---| NativePacker.KeySpec.MultiConfig

---@alias NativePacker.KeySpec table<string, NativePacker.KeySpec.Config>

local M = {}

function M.add(source, set)
	require("native-packer.key.core").add(source, set)
end

return M
