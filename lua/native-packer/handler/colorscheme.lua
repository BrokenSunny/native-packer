local M = {}

--- @param spec NativePacker.Plugin.Spec
--- @return string[]
function M.normalize(spec)
  local plugin_name = spec[1] or spec.name
  local source = spec.colorscheme
  --- @type string[]
  local colorscheme = {}
  if type(source) ~= "table" then
    source = { source }
  end

  for _, value in ipairs(source) do
    if type(value) == "string" then
      colorscheme[#colorscheme + 1] = value
    else
      vim.api.nvim_echo({
        {
          "NativePackerWarn: [" .. plugin_name .. "].colorscheme expected string, but got " .. type(value) .. "!!!",
          "WarningMsg",
        },
      }, true)
    end
  end

  return colorscheme
end

--- @param data NativePacker.Plugin.Data
--- @param load fun()
function M.register(data, load)
  local colorschemes = data.colorscheme
  if #colorschemes == 0 then
    return
  end

  local group = vim.api.nvim_create_augroup("NativePacker:colorscheme", { clear = false })
  vim.api.nvim_create_autocmd("ColorSchemePre", {
    group = group,
    callback = function(e)
      local colorscheme = e.match
      if vim.list_contains(colorschemes, colorscheme) then
        -- vim.print(colorscheme .. ": load " .. data.name)
        load()
        return true
      end
    end,
    nested = true,
  })
end

--- @param data NativePacker.Plugin.Data
function M.clean(data)
  if #data.colorscheme == 0 then
    return
  end
  pcall(vim.api.nvim_del_augroup_by_name, "NativePacker:colorscheme")
end

--- @param colorscheme string[]
--- @return boolean
function M.has(colorscheme)
  return #colorscheme > 0
end

return M
