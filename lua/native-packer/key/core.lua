local M = {
  keymaps = {},
  del_keymaps = {},
  filetypes = {},
  exclude_filetypes = {},
  --- @type table<string, fun()[]>
  events = {
    FileType = {},
  },
  --- @type table<string, integer>
  autcmds = {},
}
local EVENT_GROUP_NAME = "NativePacker.key:event"
local IGNORE_FILETYPES = { "blink-cmp-menu", "fzf" }

-- stylua: ignore
local KEYMAP_SET_OPTS = { noremap = true, nowait = true, silent = true, script = true, expr = true, unique = true, callback = true, desc = true, replace_keycodes = true, buf = true, remap = true, }
-- stylua: ignore
local KEYMAP_DEL_OPTS = { buf = true, }

--- @param where table
--- @param lhs any
local function echo_add_lhs_type_invalid(where, lhs)
  vim.api.nvim_echo({
    {
      "NativePackerError: native-packer.key.add(keymaps): keymaps = { [lhs] = config }: lhs expected string, but got "
        .. type(lhs)
        .. "\n",
      "ErrorMsg",
    },
    {
      "source: " .. vim.inspect(where) .. "\n",
      "ErrorMsg",
    },
  }, true)
end

--- @param where table
--- @param rhs any
local function echo_rhs_type_invalid(where, rhs)
  vim.api.nvim_echo({
    {
      "NativePackerError: native-packer.key.add(keymaps): keymaps = { [lhs] = config }: rhs = config[1]: rhs expected string|function, but got "
        .. type(rhs)
        .. "\n",
      "ErrorMsg",
    },
    {
      "source: " .. vim.inspect(where) .. "\n",
      "ErrorMsg",
    },
  }, true)
end

--- @param where table
--- @param lhs any
local function echo_del_lhs_type_invalid(where, lhs)
  vim.api.nvim_echo({
    {
      "NativePackerError: native-packer.key.del(keymaps): keymaps = { [lhs] = config }: lhs expected string, but got "
        .. type(lhs)
        .. "\n",
      "ErrorMsg",
    },
    {
      "source: " .. vim.inspect(where) .. "\n",
      "ErrorMsg",
    },
  }, true)
end

--- @param where table
--- @param config any
local function echo_add_config_type_invalid(where, config)
  vim.api.nvim_echo({
    {
      "NativePackerError: native-packer.key.add(keymaps): keymaps = { [lhs] = config }: config expected table, but got "
        .. type(config)
        .. "\n",
      "ErrorMsg",
    },
    {
      "source: " .. vim.inspect(where) .. "\n",
      "ErrorMsg",
    },
  }, true)
end

--- @param where table
--- @param mode any
local function echo_add_mode_type_invalid(where, mode)
  vim.api.nvim_echo({
    {
      "NativePackerError: native-packer.key.add(keymaps): mode expected string, but got " .. type(mode) .. "\n",
      "ErrorMsg",
    },
    {
      "source: " .. vim.inspect(where) .. "\n",
      "ErrorMsg",
    },
  }, true)
end

--- @param where table
--- @param mode any
local function echo_del_mode_type_invalid(where, mode)
  vim.api.nvim_echo({
    {
      "NativePackerError: native-packer.key.del(keymaps): mode expected string, but got " .. type(mode) .. "\n",
      "ErrorMsg",
    },
    {
      "source: " .. vim.inspect(where) .. "\n",
      "ErrorMsg",
    },
  }, true)
end

--- @param lhs string
--- @param rhs string|fun()
--- @param mode string
--- @param extra NativePacker.Key.Options
local function collect_keymap(lhs, rhs, mode, extra)
  if not M.keymaps[lhs] then
    M.keymaps[lhs] = {
      [mode] = {
        rhs = rhs,
      },
    }
  else
    M.keymaps[lhs][mode] = {
      rhs = rhs,
    }
  end
  M.keymaps[lhs][mode] = vim.tbl_extend("force", M.keymaps[lhs][mode], extra)
end

local function normalize_ft(where, field, ft)
  if ft == nil then
    return {}
  end
  local filetypes = type(ft) == "table" and ft or { ft }
  for _, f in ipairs(filetypes) do
    if type(f) ~= "string" then
      vim.api.nvim_echo({
        {
          "NativePackerError: native-packer.key.add(keymaps): keymaps[lhs]."
            .. field
            .. " expected string, but got "
            .. type(f)
            .. "\n",
          "ErrorMsg",
        },
        {
          "source: " .. vim.inspect(where) .. "\n",
        },
      }, true)
    end
  end
  return filetypes
end

--- @param where table
--- @param extra NativePacker.Key.Options
--- @param callback fun(buf: integer)
local function collect_filetype_keymap(where, extra, callback)
  local _fts = normalize_ft(where, "ft", extra.ft)
  local _exclude_fts = normalize_ft(where, "exclude_ft", extra.exclude_ft)
  local fts = {}
  local exclude_fts = {}
  local conflict_fts = {}
  for _, ft in ipairs(_fts) do
    if vim.tbl_contains(_exclude_fts, ft) then
      conflict_fts[ft] = true
      vim.schedule(function()
        vim.api.nvim_echo({
          {
            "NativePackerError: native-packer.key.add(keymaps): keymaps[lhs].ft and keymaps[lhs].exclude_ft specified the same ft: "
              .. ft
              .. ", this ft will be ignored!"
              .. "\n",
            "ErrorMsg",
          },
          {
            "source: " .. vim.inspect(where) .. "\n",
          },
        }, true)
      end)
    else
      table.insert(fts, ft)
    end
  end
  for _, ft in ipairs(_exclude_fts) do
    if not conflict_fts[ft] then
      table.insert(exclude_fts, ft)
    end
  end
  for _, ft in ipairs(fts) do
    M.filetypes[ft] = M.filetypes[ft] or {}
    table.insert(M.filetypes[ft], callback)
  end
  table.insert(M.exclude_filetypes, { callback = callback, filetypes = exclude_fts })
end

--- @param where table
--- @param event any
--- @param callback fun()
local function collect_event_keymap(where, event, callback)
  if event == nil then
    return
  end

  if type(event) ~= "table" then
    event = { event }
  end

  for _, e in ipairs(event) do
    if type(e) == "string" then
      M.events[e] = M.events[e] or {}
      table.insert(M.events[e], callback)
    else
      vim.api.nvim_echo({
        {
          "NativePackerError: native-packer.key.add(keymaps): keymaps[lhs].event expected string, but got "
            .. type(e)
            .. "\n",
          "ErrorMsg",
        },
        {
          "source: " .. vim.inspect(where) .. "\n",
          "ErrorMsg",
        },
      }, true)
    end
  end
end

--- @param opts table
--- @param parent_opts table|nil
--- @return table
local function filter_opts(opts, parent_opts)
  local final_opts = {}
  for key, value in pairs(opts) do
    if type(key) == "string" then
      final_opts[key] = value
    end
  end
  final_opts = vim.tbl_extend("force", parent_opts or {}, final_opts)
  return final_opts
end

--- @param map table
--- @param opts NativePacker.Key.Options
--- @return vim.keymap.set.Opts| vim.keymap.del.Opts
local function filter_keymap_options(map, opts)
  local keymap_opts = {}
  for key, value in pairs(opts) do
    if map[key] then
      keymap_opts[key] = value
    end
  end
  return keymap_opts
end

--- @param rhs any
--- @return boolean
local function is_rhs(rhs)
  return type(rhs) == "string" or type(rhs) == "function"
end

local function _set(mode, lhs, rhs, opts, extra)
  local _rhs = rhs
  if not opts.expr and type(rhs) == "function" then
    rhs = function()
      _rhs(extra)
    end
  end
  local ok, err = pcall(vim.keymap.set, mode, lhs, rhs, opts)
  if not ok then
    vim.api.nvim_echo({ { "NativePackerError: vim.keymap.set: " .. vim.inspect(err), "ErrorMsg" } }, true)
  end
end

--- @param where table
--- @param lhs string
--- @param rhs string|fun()
--- @param mode string
--- @param opts vim.keymap.set.Opts
--- @param extra NativePacker.Key.Options
--- @param set? fun()
local function set_keymap(where, lhs, rhs, mode, opts, extra, set)
  set = set or _set
  collect_keymap(lhs, rhs, mode, extra)
  if not extra.ft and not extra.event and not extra.exclude_ft then
    set(mode, lhs, rhs, opts, extra)
    return
  end
  collect_filetype_keymap(where, extra, function(buf)
    set(mode, lhs, rhs, vim.tbl_extend("force", opts, { buf = buf }), extra)
  end)
  collect_event_keymap(where, extra.event, function()
    set(mode, lhs, rhs, opts, extra)
  end)
end

--- @param where table
--- @param lhs string
--- @param rhs NativePacker.Key.Rhs
--- @param mode NativePacker.Key.Mode
--- @param opts NativePacker.Key.Options
--- @param set? fun()
local function set_mode_keymap(where, lhs, rhs, mode, opts, set)
  if type(mode) == "string" then
    set_keymap(
      where,
      lhs,
      rhs,
      mode,
      filter_keymap_options(KEYMAP_SET_OPTS, opts) --[[@as vim.keymap.set.Opts]],
      opts,
      set
    )
  elseif type(mode) == "table" then
    local modes = mode --[[@as NativePacker.Key.Modes]]
    for _, md in ipairs(modes) do
      set_mode_keymap(where, lhs, rhs, md, filter_opts(modes, opts), set)
    end
  else
    echo_add_mode_type_invalid(where, mode)
  end
end

--- @param where table
--- @param lhs string
--- @param config NativePacker.Key.SingleModeConfig
--- @param parent_opts NativePacker.Key.Options
--- @param set? fun()
local function parse_one_rhs(where, lhs, config, parent_opts, set)
  local rhs = config[1]
  local mode = config[2]
  set_mode_keymap(where, lhs, rhs, mode, filter_opts(config, parent_opts), set)
end

--- @param where table
--- @param lhs string
--- @param config NativePacker.Key.MultiModeConfig
--- @param parent_opts NativePacker.Key.Options
--- @param set? fun()
local function parse_more_rhs(where, lhs, config, parent_opts, set)
  for _, cfg in ipairs(config) do
    parse_one_rhs(where, lhs, cfg, filter_opts(config, parent_opts), set)
  end
end

--- @param where table
--- @param lhs string
--- @param config NativePacker.Key.Config
--- @param set? fun()
local function parse_keymap_add(where, lhs, config, set)
  if type(config) ~= "table" then
    echo_add_config_type_invalid(where, config)
    return
  end

  local opts = filter_opts(config) --[[@as NativePacker.Key.Options]]

  if is_rhs(config[1]) then
    parse_one_rhs(where, lhs, config --[[@as NativePacker.Key.SingleModeConfig]], opts, set)
  elseif type(config[1]) == "table" then
    parse_more_rhs(where, lhs, config --[[@as NativePacker.Key.MultiModeConfig]], opts, set)
  else
    echo_rhs_type_invalid(where, config[1])
  end
end

local function create_hook()
  local group = vim.api.nvim_create_augroup(EVENT_GROUP_NAME, { clear = false })
  for event, callbacks in pairs(M.events) do
    if not M.autcmds[event] then
      local opts = {
        group = group,
      }
      if event == "FileType" then
        opts.pattern = "*"
        opts.callback = function(ev)
          local filetype = vim.bo.filetype
          for _, data in ipairs(M.exclude_filetypes) do
            if not vim.tbl_contains(data.filetypes, filetype) and not vim.tbl_contains(IGNORE_FILETYPES, filetype) then
              data.callback(ev.buf)
            end
          end
          for _, cb in ipairs(M.filetypes[filetype] or {}) do
            cb(ev.buf)
          end
        end
      else
        opts.callback = function()
          for _, cb in ipairs(callbacks) do
            cb()
          end
        end
      end
      M.autcmds[event] = vim.api.nvim_create_autocmd(event, opts)
    end
  end
end

--- @param lhs string
--- @param mode string
--- @param opts table
local function del_keymap(lhs, mode, opts)
  M.del_keymaps[lhs] = M.del_keymaps[lhs] or {}
  M.del_keymaps[lhs][mode] = opts
  return pcall(vim.keymap.del, mode, lhs, filter_keymap_options(KEYMAP_DEL_OPTS, opts) --[[@as vim.keymap.del.Opts]])
end

--- @param where table
--- @param lhs string
--- @param mode any
--- @param opts table
local function pending_del_keymap(where, lhs, mode, opts)
  if type(mode) ~= "string" then
    echo_del_mode_type_invalid(where, mode)
  end
  local ok = del_keymap(lhs, mode, opts)
  if not ok then
    collect_event_keymap(where, "BufReadPre", function()
      del_keymap(lhs, mode, opts)
    end)
  end
end

--- @param where table
--- @param lhs string
--- @param config NativePacker.DelKey.Config
local function parse_keymap_del(where, lhs, config)
  if type(config) ~= "table" then
    config = { config }
  end

  local opts = filter_opts(config --[[@as NativePacker.DelKey.MultiModeConfig]])
  for _, mode in ipairs(config) do
    if type(mode) ~= "table" then
      pending_del_keymap(where, lhs, mode, opts)
    else
      parse_keymap_del(where, lhs, vim.tbl_extend("force", opts, mode))
    end
  end
end

--- @param keymaps NativePacker.Key
--- @param set? fun()
function M.add(keymaps, set)
  for lhs, config in pairs(keymaps) do
    local where = { [lhs] = config }
    if type(lhs) == "string" then
      parse_keymap_add(where, lhs, config, set)
    else
      echo_add_lhs_type_invalid(where, lhs)
    end
  end
  create_hook()
end

--- @param keymaps NativePacker.DelKey
function M.del(keymaps)
  for lhs, config in pairs(keymaps) do
    local where = { [lhs] = config }
    if type(lhs) == "string" then
      parse_keymap_del(where, lhs, config)
    else
      echo_del_lhs_type_invalid(where, lhs)
    end
  end
  create_hook()
end

--- @param lhs string|nil
function M.get(lhs)
  return M.keymaps[lhs] or M.keymaps
end

return M
