local M = {}

function M.normalize(data)
  local colorscheme = data.colorscheme
  local colorschemes = {}

  if type(colorscheme) == "string" then
    colorscheme = { colorscheme }
  elseif type(colorscheme) == "table" then
    colorscheme = colorscheme
  else
    colorscheme = {}
  end

  for _, d in ipairs(colorscheme) do
    if type(d) == "string" then
      colorschemes[#colorschemes + 1] = d
    end
  end
  data.colorscheme = colorschemes
end

function M.register(plugin)
  local colorschemes = plugin.colorscheme
  if #colorschemes == 0 then
    return
  end

  local group = vim.api.nvim_create_augroup(plugin.name .. ":colorscheme", { clear = true })
  vim.api.nvim_create_autocmd("ColorSchemePre", {
    group = group,
    callback = function(e)
      local colorscheme = e.match
      if vim.list_contains(colorschemes, colorscheme) then
        require("native-packer.core").load({ plugin.name })
        return true
      end
    end,
    nested = true,
  })
end

function M.clean(plugin)
  if #plugin.colorscheme == 0 then
    return
  end
  pcall(vim.api.nvim_del_augroup_by_name, plugin.name .. ":colorscheme")
end

return M
