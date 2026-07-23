local M = {}

--- @param spec NativePacker.Plugin.Spec
--- @return string[]
function M.normalize(spec)
  local plugin_name = spec[1] or spec.name
  local source = spec.ft
  --- @type string[]
  local ft = {}
  if type(source) ~= "table" then
    source = { source }
  end
  for _, value in ipairs(source) do
    if type(value) == "string" then
      ft[#ft + 1] = value
    else
      vim.api.nvim_echo({
        {
          "NativePackerWarn: [" .. plugin_name .. "].ft[integer] expected string, but got " .. type(value) .. "!!!",
          "WarningMsg",
        },
      }, true)
    end
  end
  return ft
end

--- @param data NativePacker.Plugin.Data
--- @param loader fun(data: NativePacker.Plugin.Data)
function M.register(data, loader)
  if #data.ft == 0 then
    return
  end

  local group = vim.api.nvim_create_augroup("NativePacker:ft", { clear = false })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function()
      local ft = vim.o.ft
      if vim.list_contains(data.ft, ft) then
        -- vim.print(ft .. " filetype: load " .. data.name)
        loader(data)
        return true
      end
    end,
  })
end

--- @param data NativePacker.Plugin.Data
function M.clean(data)
  if #data.ft == 0 then
    return
  end
  pcall(vim.api.nvim_del_augroup_by_name, "NativePacker:ft")
end

--- @param ft string[]
--- @return boolean
function M.has(ft)
  return #ft > 0
end

return M
