local M = {}
local GITHUB_URL = "https://github.com/"
local Handler = require("native-packer.handler")
local Hook = require("native-packer.hook")

-- Use a short src to record source plugin spec to find depend spec, for sorting
--- @type table<string, vim.pack.Spec>
M.plugin_specs_by_short_src = {}
-- Use a short src to record plugin spec data to find depend spec data, for loading
--- @type table<string, NativePacker.Plugin.Data>
M.plugin_spec_datas_by_short_src = {}
-- Use plugin name to record plugin spec data for loading
--- @type table<string, NativePacker.Plugin.Data>
M.plugin_spec_datas_by_plugin_name = {}

local repo_plugin_keymaps = {}

--- @class NativePacker.Plugin.Spec.Hooks
--- @field config? fun()
--- @field run? fun(data: vim.event.packchanged.data)
--- @field before? fun()

--- @class NativePacker.Plugin.Data.Hooks
--- @field config? fun()
--- @field before? fun()
--- @field run? fun(data: vim.event.packchanged.data)

--- @class NativePacker.Plugin.Spec.Event.Spec
--- @field [integer] vim.api.keyset.events|NativePacker.Plugin.Spec.Event.Spec
--- @field condition? fun(): boolean
--- @field pattern? string|string[]

--- @class NativePacker.Plugin.Data.Event.Spec
--- @field [1] vim.api.keyset.events
--- @field condition? fun():boolean
--- @field pattern? string|string[]

--- @alias NativePacker.Plugin.Spec.Event string|NativePacker.Plugin.Spec.Event.Spec
--- @alias NativePacker.Plugin.Data.Event NativePacker.Plugin.Data.Event.Spec[]

--- @class NativePacker.Plugin.Spec.Handlers
--- @field event? NativePacker.Plugin.Spec.Event
--- @field cmd? string|string[]
--- @field ft? string|string[]
--- @field colorscheme? string|string[]
--- @field key? NativePacker.Key

--- @class NativePacker.Plugin.Data.Handlers
--- @field event NativePacker.Plugin.Data.Event
--- @field cmd string[]
--- @field ft string[]
--- @field colorscheme string[]
--- @field key NativePacker.Key

--- @class NativePacker.Plugin.Spec.Base
--- @field name? string
--- @field depend? string|string[]
--- @field enabled? boolean|fun():boolean
--- @field lazy? boolean
--- @field priority? integer
--- @field version? string|vim.VersionRange
--- @field condition? fun():boolean

--- @class NativePacker.Plugin.Data.Base
--- @field name? string
--- @field depend string[]
--- @field enabled boolean|fun():boolean
--- @field lazy boolean
--- @field priority integer
--- @field version? string|vim.VersionRange
--- @field condition? fun():boolean
--- @field loaded? boolean
--- @field packadded? boolean

--- @class NativePacker.Plugin.LocalSpec: NativePacker.Plugin.Spec.Base, NativePacker.Plugin.Spec.Hooks, NativePacker.Plugin.Spec.Handlers
--- @class NativePacker.Plugin.LocalData: NativePacker.Plugin.Data.Base, NativePacker.Plugin.Data.Hooks, NativePacker.Plugin.Data.Handlers

--- @class NativePacker.Plugin.RepoSpec: NativePacker.Plugin.LocalSpec
--- @field [1] string

--- @class NativePacker.Plugin.RepoData: NativePacker.Plugin.LocalData
--- @field repo string

--- @alias NativePacker.Plugin.Data NativePacker.Plugin.LocalData|NativePacker.Plugin.RepoData
--- @alias NativePacker.Plugin.Spec string|NativePacker.Plugin.RepoSpec|NativePacker.Plugin.LocalSpec
--- @alias NativePacker.Plugin (NativePacker.Plugin.Spec[]|NativePacker.Plugin.Spec)[]

--- @param source any
--- @param plugin_name string
--- @return string[]
local function normalize_depend(source, plugin_name)
  --- @type string[]
  local depend = {}
  if type(source) ~= "table" then
    source = { source }
  end
  for _, value in ipairs(source) do
    if type(value) == "string" then
      depend[#depend + 1] = value
    else
      vim.api.nvim_echo({
        {
          "NativePackerWarn: [" .. plugin_name .. "].depend[integer] expected string, but got" .. type("value") .. "\n",
          "WarningMsg",
        },
      }, true)
    end
  end

  return depend
end

--- @param lazy boolean|nil
--- @param has_handler boolean
--- @param plugin_name string
--- @return boolean
local function normalize_lazy(lazy, has_handler, plugin_name)
  if lazy ~= nil and type(lazy) ~= "boolean" then
    vim.api.nvim_echo({
      {
        "NativePackerWarn: [" .. plugin_name .. "].lazy expected boolen, but got " .. type(lazy) .. "\n",
        "WarningMsg",
      },
    }, true)
    lazy = false
  elseif lazy == nil then
    if has_handler then
      lazy = true
    else
      lazy = false
    end
  end

  return lazy
end

--- @param priority any
--- @param plugin_name string
--- @return integer
local function normalize_priority(priority, plugin_name)
  if type(priority) == "number" or priority == nil then
    return priority or 100
  end
  vim.api.nvim_echo({
    {
      "NativePackerWarn: [" .. plugin_name .. "].priority expected integer, but got " .. type(priority) .. "\n",
      "WarningMsg",
    },
  }, true)
  return 100
end

--- @param enabled any
--- @param plugin_name string
--- @return boolean|fun():boolean
local function normalize_enabled(enabled, plugin_name)
  if type(enabled) ~= "boolean" and type(enabled) ~= "function" and enabled ~= nil then
    vim.api.nvim_echo({
      {
        "NativePackerWarn: ["
          .. plugin_name
          .. "].enabled expected boolean|fun():boolean, but got "
          .. type(enabled)
          .. "\n",
        "WarningMsg",
      },
    }, true)
    enabled = true
  end
  return enabled == nil and true or enabled
end

--- @param name any
--- @param plugin_name string
--- @return string|nil
local function normalize_name(name, plugin_name)
  if type(name) == "string" or name == nil then
    return name
  end
  vim.api.nvim_echo({
    {
      "NativePackerWarn: [" .. plugin_name .. "].name expected string, but got " .. type(name) .. "\n",
      "WarningMsg",
    },
  }, true)
  return nil
end

--- @param version any
--- @param plugin_name string
--- @return nil|string|vim.VersionRange
local function normalize_version(version, plugin_name)
  if (type(version) == "table" and version.from and version.has) or type(version) == "string" or version == nil then
    return version
  end
  vim.api.nvim_echo({
    {
      "NativePackerWarn: ["
        .. plugin_name
        .. "].version expected vim.VersionRange|string, but got "
        .. type(version)
        .. "\n",
      "WarningMsg",
    },
  }, true)
  return nil
end

--- @param condition any
--- @param plugin_name string
--- @return nil|fun():boolean
local function normalize_condition(condition, plugin_name)
  if type(condition) == "function" or condition == nil then
    return condition
  end
  vim.api.nvim_echo({
    {
      "NativePackerWarn: [" .. plugin_name .. "].condition expected function, but got " .. type(condition) .. "\n",
      "WarningMsg",
    },
  }, true)
  return nil
end

--- @param plugin_spec NativePacker.Plugin.RepoSpec|NativePacker.Plugin.LocalSpec
--- @return vim.pack.Spec?
local function normalize_spec(plugin_spec)
  if plugin_spec[1] and type(plugin_spec[1]) ~= "string" then
    vim.api.nvim_echo({
      {
        "NativePackerWarn: Remote Plugin: src = plugin[1]: 'src' is not a string, this remote plugin will be ignore!!!\n",
        "WarningMsg",
      },
      {
        "source: " .. vim.inspect(plugin_spec),
        "WarningMsg",
      },
    }, true)
    return
  end

  if #plugin_spec == 0 and type(plugin_spec.name) ~= "string" then
    vim.api.nvim_echo({
      {
        "NativePackerWarn: Local Plugin: name = plugin.name, 'name' is not a string, this local plugin will be ignore!!!\n",
        "WarningMsg",
      },
      {
        "source: " .. vim.inspect(plugin_spec)("WarningMsg"),
      },
    }, true)
    return
  end
  local plugin_name = plugin_spec[1] or plugin_spec.name
  local enabled = normalize_enabled(plugin_spec.enabled, plugin_name)
  if not enabled then
    return
  end

  local hooks = Hook.normalize(plugin_spec)
  local handlers = Handler.normalize(plugin_spec)
  --- @type NativePacker.Plugin.Data.Base
  local base = {
    priority = normalize_priority(plugin_spec.priority, plugin_name),
    enabled = enabled,
    depend = normalize_depend(plugin_spec.depend, plugin_name),
    name = normalize_name(plugin_spec.name, plugin_name),
    version = normalize_version(plugin_spec.version, plugin_name),
    condition = normalize_condition(plugin_spec.condition, plugin_name),
    lazy = normalize_lazy(plugin_spec.lazy, Handler.has(handlers), plugin_name),
  }

  local data = vim.tbl_deep_extend("force", base, hooks, handlers) --[[@as NativePacker.Plugin.Data]]

  --- @type vim.pack.Spec
  ---@diagnostic disable-next-line: missing-fields
  local spec = {
    version = data.version,
    name = data.name,
    data = data,
  }

  if plugin_spec[1] then
    local repo = plugin_spec[1]
    local src = GITHUB_URL .. repo
    spec.src = src
    data.repo = repo
  end

  return spec
end

--- @param source NativePacker.Plugin
--- @return vim.pack.Spec[]
local function normalize_specs(source)
  --- @type vim.pack.Spec[]
  local specs = {}

  --- @type table<string, vim.pack.Spec>
  local lazy_specs = {}
  --- @type table<string, boolean>
  local marked_startups = {}

  --- @param data NativePacker.Plugin.Data
  local function mark_depend_startup(data)
    for _, dp in ipairs(data.depend) do
      if lazy_specs[dp] then
        local depend_spec = lazy_specs[dp]
        depend_spec.data.lazy = false
        mark_depend_startup(depend_spec.data)
      else
        marked_startups[dp] = true
      end
    end
  end

  --- @param plugin_spec NativePacker.Plugin.RepoSpec|NativePacker.Plugin.LocalSpec
  local function normalize(plugin_spec)
    local spec = normalize_spec(plugin_spec)
    if not spec then
      return
    end
    local data = spec.data --[[@as NativePacker.Plugin.Data]]
    local id = data.repo or data.name

    if marked_startups[id] then
      data.lazy = false
    end

    if data.lazy then
      lazy_specs[data.repo or data.name] = spec
    else
      mark_depend_startup(data)
    end

    specs[#specs + 1] = spec
    M.plugin_specs_by_short_src[spec.data.repo or spec.data.name] = spec
  end

  --- @param s NativePacker.Plugin
  local function iter(s)
    for _, value in ipairs(s) do
      if type(value) == "table" then
        if #value == 1 then
          if type(value[1]) ~= "table" then
            normalize(value)
          end
        elseif #value == 0 then
          if value.name then
            normalize(value)
          else
          end
        else
          iter(value)
        end
      else
        local repo = value --[[@as string]]
        normalize({ repo })
      end
    end
  end
  iter(source)
  return specs
end

--- @param spec vim.pack.Spec
--- @return vim.pack.Spec[]
local function sort_depend_specs(spec)
  local data = spec.data --[[@as NativePacker.Plugin.Data]]
  --- @type vim.pack.Spec[]
  local depend_specs = {}
  for _, name in ipairs(data.depend) do
    local depend_spec = M.plugin_specs_by_short_src[name]
    if depend_spec then
      table.insert(depend_specs, depend_spec)
    end
  end
  table.sort(depend_specs, function(a, b)
    return a.data.priority < b.data.priority
  end)
  data.depend = {}
  for _, depend_spec in ipairs(depend_specs) do
    table.insert(data.depend, 1, depend_spec.data.repo or depend_spec.data.name)
  end
  return depend_specs
end

--- @param specs vim.pack.Spec[]
--- @return vim.pack.Spec[]
local function sort_specs(specs)
  table.sort(specs, function(a, b)
    return a.data.priority > b.data.priority
  end)

  --- @type table<string, boolean>
  local sorted_spec_map = {}
  --- @type vim.pack.Spec[]
  local sorted_specs = {}

  --- @param spec vim.pack.Spec
  --- @param start integer
  local function promote_depend_spec(spec, start)
    local depend_specs = sort_depend_specs(spec)
    for _, depend_spec in ipairs(depend_specs) do
      local key = depend_spec.data.repo or depend_spec.data.name
      if not sorted_spec_map[key] then
        sorted_spec_map[key] = true
        table.insert(sorted_specs, start, depend_spec)
        promote_depend_spec(depend_spec, start)
      end
    end
  end

  local start = 1
  for _, spec in ipairs(specs) do
    local data = spec.data --[[@as NativePacker.Plugin.Data]]
    local key = data.repo or data.name
    if not sorted_spec_map[key] then
      sorted_spec_map[key] = true
      table.insert(sorted_specs, start, spec)
      if not spec.data.lazy then
        promote_depend_spec(spec, start)
      end
      start = #sorted_specs + 1
    end
  end

  return sorted_specs
end

--- @param source NativePacker.Plugin
--- @return vim.pack.Spec[]
local function build_specs(source)
  return sort_specs(normalize_specs(source))
end

--- @param data NativePacker.Plugin.Data
local function is_local_spec(data)
  return not data.repo and type(data.name) == "string"
end

--- @param specs vim.pack.Spec[]
--- @return vim.pack.Spec[], table<string, vim.pack.Spec[]>, table<string, vim.pack.Spec[]>
local function filter_repo_specs(specs)
  --- @type vim.pack.Spec[]
  local repo_specs = {}
  --- @type vim.pack.Spec[]
  local local_specs_segment = {}
  --- @type table<string, vim.pack.Spec[]>
  local skipped_local_spec_map = {}
  --- @type table<string, vim.pack.Spec[]>
  local remaining_local_spec_map = {}

  --- @param map table<string, vim.pack.Spec[]>
  --- @param name string
  local function track(map, name)
    map[name] = local_specs_segment
    local_specs_segment = {}
  end

  --- @type vim.pack.Spec|nil
  local pre
  for i, spec in ipairs(specs) do
    if is_local_spec(spec.data) then
      local_specs_segment[#local_specs_segment + 1] = spec
      if i == #specs then
        local last_repo_spec_data = repo_specs[#repo_specs].data --[[@as NativePacker.Plugin.Data]]
        track(remaining_local_spec_map, last_repo_spec_data.repo)
      end
    else
      if pre and is_local_spec(pre.data) then
        track(skipped_local_spec_map, spec.data.repo)
      end
      repo_specs[#repo_specs + 1] = spec
      repo_plugin_keymaps[spec.data.repo] = spec.data.key
      spec.data.key = nil
    end
    pre = spec
  end

  return repo_specs, skipped_local_spec_map, remaining_local_spec_map
end

--- @param data NativePacker.Plugin.Data
local function packadd(data)
  if data.packadded then
    return
  end
  vim.cmd.packadd(data.name)
  data.packadded = true
end

--- @param data NativePacker.Plugin.Data
local function load(data)
  if data.loaded then
    return
  end

  --- @param d NativePacker.Plugin.Data
  local function load_depend(d)
    for _, depend in ipairs(d.depend) do
      local depend_spec_data = M.plugin_spec_datas_by_short_src[depend]
      if depend_spec_data then
        load(depend_spec_data)
      else
        vim.api.nvim_echo({
          {
            "NativePackerError: Loading ["
              .. (d.repo or d.name)
              .. "] plugin depend error: Can't find ["
              .. depend
              .. "] spec!!!\n",
            "ErrorMsg",
          },
        }, true)
      end
    end
  end
  load_depend(data)
  Handler.clean(data)
  if data.before then
    data.before()
  end
  packadd(data)
  if data.config then
    data.config()
  end
  data.loaded = true
end

--- @param data NativePacker.Plugin.Data
local function register(data)
  M.plugin_spec_datas_by_short_src[data.repo or data.name] = data
  M.plugin_spec_datas_by_plugin_name[data.name] = data
  Handler.register(data, function()
    load(data)
  end)
end

local function on_pack_changed()
  vim.api.nvim_create_autocmd("PackChanged", {
    pattern = "*",
    callback = function(e)
      local p = e.data --[[@as vim.event.packchanged.data]]
      local run = (p.spec.data or {}).run
      if p.kind ~= "delete" and type(run) == "function" then
        run(p)
      end
    end,
  })
end

--- @param data NativePacker.Plugin.Data
local function init(data)
  register(data)
  if not data.lazy then
    load(data)
  end
end

--- @param source NativePacker.Plugin
function M.add(source)
  local specs = build_specs(source or {})
  local repo_specs, skipped_local_spec_map, remain_local_spec_map = filter_repo_specs(specs)
  on_pack_changed()
  vim.pack.add(repo_specs, {
    load = function(plug_data)
      local data = plug_data.spec.data
      data.name = plug_data.spec.name
      data.key = repo_plugin_keymaps[data.repo]
      local skipped_local_specs = skipped_local_spec_map[data.repo]
      if skipped_local_specs then
        for _, spec in ipairs(skipped_local_specs) do
          init(spec.data)
        end
      end
      init(data)
      local remaining_local_specs = remain_local_spec_map[data.repo]
      if remaining_local_specs then
        for _, spec in ipairs(remaining_local_specs) do
          init(spec.data)
        end
      end
    end,
  })
end

--- @param plugin_names string[]
function M.load(plugin_names)
  for _, name in ipairs(plugin_names) do
    local data = M.plugin_spec_datas_by_plugin_name[name]
    if data then
      load(data)
    end
  end
end

function M.packadd(plugin_names)
  for _, name in ipairs(plugin_names) do
    local data = M.plugin_spec_datas_by_plugin_name[name]
    if data then
      packadd(data)
    end
  end
end

return M
