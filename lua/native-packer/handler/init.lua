local M = {}

local ft = require("native-packer.handler.ft")
local cmd = require("native-packer.handler.cmd")
local colorscheme = require("native-packer.handler.colorscheme")
local key = require("native-packer.handler.key")
local event = require("native-packer.handler.event")

--- @param spec NativePacker.Plugin.Spec
--- @return NativePacker.Plugin.Data.Handlers
function M.normalize(spec)
  --- @type NativePacker.Plugin.Data.Handlers
  local handlers = {
    ft = ft.normalize(spec),
    key = key.normalize(spec.key),
    cmd = cmd.normalize(spec),
    event = event.normalize(spec),
    colorscheme = colorscheme.normalize(spec),
  }
  return handlers
end

--- @param data NativePacker.Plugin.Data
--- @param loader fun(data: NativePacker.Plugin.Data)
function M.register(data, loader)
  if not data.lazy then
    require("native-packer.key").add(data.key)
    return
  end
  cmd.register(data, loader)
  ft.register(data, loader)
  colorscheme.register(data, loader)
  event.register(data, loader)
  key.register(data, loader)
end

function M.clean(data)
  cmd.clean(data)
  ft.clean(data)
  colorscheme.clean(data)
  event.clean(data)
  key.clean(data)
end

--- @param handlers NativePacker.Plugin.Data.Handlers
--- @return boolean
function M.has(handlers)
  return ft.has(handlers.ft)
    or cmd.has(handlers.cmd)
    or colorscheme.has(handlers.colorscheme)
    or event.has(handlers.event)
    or key.has(handlers.key)
end

return M
