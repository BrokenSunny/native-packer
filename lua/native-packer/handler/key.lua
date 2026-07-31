local M = {
  resets = {},
}

--- @param source any
--- @return table
function M.normalize(source)
  return source or {}
end

--- @param data NativePacker.Plugin.Data
--- @param load fun()
function M.register(data, load)
  --- @type fun()[]
  local resets = {}
  M.resets[data.repo or data.name] = resets
  require("native-packer.key").add(data.key, function(mode, lhs, rhs, opts, extra)
    local reset = function()
      local _rhs = rhs
      if not extra.expr and type(rhs) == "function" then
        rhs = function()
          _rhs(extra)
        end
      end
      pcall(vim.keymap.set, mode, lhs, rhs, opts)
    end
    table.insert(resets, reset)
    local handle = function()
      load()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Ignore>" .. lhs, true, true, true), "i", false)
    end
    pcall(vim.keymap.set, mode, lhs, handle, vim.tbl_extend("force", opts, { expr = true }))
  end)
end

--- @param data NativePacker.Plugin.Data
function M.clean(data)
  local resets = M.resets[data.repo or data.name]
  for _, callback in ipairs(resets or {}) do
    callback()
  end
  M.resets[data.repo or data.name] = nil
end

--- @param key NativePacker.Key
--- @return boolean
function M.has(key)
  return vim.tbl_count(key) > 0
end

return M
