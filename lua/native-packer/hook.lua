local M = {}

--- @param source NativePacker.Plugin.Spec
--- @return NativePacker.Plugin.Spec.Hooks
function M.normalize(source)
  local plugin_name = source[1] or source.name
  --- @type NativePacker.Plugin.Spec.Hooks
  local hooks = {}
  if type(source.run) == "function" or source.run == nil then
    hooks.run = source.run
  else
    vim.api.nvim_echo({
      {
        "NativePackerWarn: [" .. plugin_name .. "].run expected function, but got " .. type(source.run) .. "\n",
        "WarningMsg",
      },
    }, true)
  end
  if type(source.config) == "function" or source.config == nil then
    hooks.config = source.config
  else
    vim.api.nvim_echo({
      {
        "NativePackerWarn: [" .. plugin_name .. "].config expected function, but got " .. type(source.config) .. "\n",
        "WarningMsg",
      },
    }, true)
  end
  if type(source.before) == "function" or source.before == nil then
    hooks.before = source.before
  else
    vim.api.nvim_echo({
      {
        "NativePackerWarn: [" .. plugin_name .. "].before expected function, but got " .. type(source.before) .. "\n",
        "WarningMsg",
      },
    }, true)
  end
  return hooks
end

return M
