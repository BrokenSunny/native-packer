local M = {}
M.plugin_map = {}
M.local_plugin_map = {}
M.repo_plugin_map = {}
local Handler = require("native-packer.handler")

---@alias NativePacker.PluginSource
---|string
---|NativePacker.PluginSpec[]
---|NativePacker.PluginSource[]

---@class NativePacker.PluginSpecHandlers
---@field event? string|string[]
---@field cmd? string|string[]
---@field ft? string|string[]
---@field colorscheme? string|string[]
---@field key? any

---@class NativePacker.PluginSpecHooks
---@field config? fun()

---@class NativePacker.PluginSpec:NativePacker.PluginSpecHandlers,NativePacker.PluginSpecHooks
---@field [1] string
---@field name? string
---@field dir? string
---@field depend? string|string[]|NativePacker.PluginSpec[]
---@field enabled? boolean|fun():boolean
---@field lazy? boolean
---@field priority? integer
---@field version? string|vim.VersionRange

local function is_local_plugin(data)
	return data.dir and data.dir ~= ""
end

---@param plugin_spec NativePacker.PluginSpec
---@return vim.pack.Spec
local function create_spec(plugin_spec)
	local spec = {}

	local data = {
		startup = not plugin_spec.lazy,
		lazy = plugin_spec.lazy,
		depend = plugin_spec.depend,
		enabled = plugin_spec.enabled,
		priority = plugin_spec.priority or 100,
		event = plugin_spec.event,
		cmd = plugin_spec.cmd,
		ft = plugin_spec.ft,
		colorscheme = plugin_spec.colorscheme,
		key = plugin_spec.key,
		config = plugin_spec.config,
		dir = plugin_spec.dir,
	}
	Handler.normalize(data)
	if type(data.priority) ~= "number" then
		data.priority = 100
	end
	if type(data.name) ~= "string" then
		data.name = nil
	end
	if not plugin_spec.dir then
		spec.src = "https://github.com/" .. plugin_spec[1]
		spec.version = plugin_spec.version
		spec.name = plugin_spec.name
		spec.data.src = spec.src
		spec.data.version = spec.version
		spec.data.name = spec.name
	end
	if
		#data.cmd > 0
		-- or #spec.data.ft > 0
		-- or #spec.data.event > 0
		-- or #spec.data.colorscheme > 0
		-- or vim.tbl_count(spec.data.keys) > 0
	then
		data.lazy = true
		data.startup = nil
	end
	spec.data = data
	return spec
end

---@param source NativePacker.PluginSource
---@return NativePacker.PluginSpec[]
local function normalize_plugin_specs(source)
	local plugin_specs = {}

	local function run(s)
		if type(s) == "string" then
			table.insert(plugin_specs, { s })
		elseif type(s) == "table" then
			if #s == 1 and type(s[1]) == "string" then
				table.insert(plugin_specs, s)
			elseif s.dir then
				table.insert(plugin_specs, s)
			else
				for _, v in ipairs(s) do
					run(v)
				end
			end
		end
	end
	run(source)
	return plugin_specs
end

local function sort_by_priority(plugin_specs, get_item)
	local priority_map = {}
	local priority_list = {}
	local items = {}

	for _, plugin_spec in ipairs(plugin_specs) do
		local item, priority = get_item(plugin_spec)
		if not priority_map[priority] then
			priority_map[priority] = { item, priority = priority }
			table.insert(priority_list, priority_map[priority])
		else
			table.insert(priority_map[priority], item)
		end
	end
	table.sort(priority_list, function(a, b)
		return a.priority > b.priority
	end)
	for _, v in ipairs(priority_list) do
		for _, item in ipairs(v) do
			table.insert(items, item)
		end
	end
	return items
end

local function low_priority_depend_up_plugin(spec_map, spec, specs, insert)
	if spec.data.sorted then
		return
	end
	spec.data.startup = true
	spec.data.depend = sort_by_priority(spec.data.depend, function(dp)
		return dp, spec_map[dp] and spec_map[dp].data.priority or 100
	end)
	for _, dp in ipairs(spec.data.depend) do
		if not spec_map[dp] then
			spec_map[dp] = create_spec({ dp })
		end
		local dp_spec = spec_map[dp]
		low_priority_depend_up_plugin(spec_map, dp_spec, specs)
	end
	insert(spec)
end

--- @return NativePacker.PluginSpec[]
local function get_specs_sort_by_depend_priority(specs, spec_map)
	local _specs = {}
	local function insert(spec)
		spec.data.sorted = true
		spec.data.index = #_specs
		table.insert(_specs, spec)
	end
	for _, spec in ipairs(specs) do
		if spec.data.startup then
			low_priority_depend_up_plugin(spec_map, spec, _specs, insert)
		else
			insert(spec)
		end
	end

	return {}
end

---@param specs NativePacker.PluginSpec[]
---@return NativePacker.PluginSpec[]
local function filter_repo_specs(specs)
	return vim.iter(specs)
		:filter(function(spec)
			return not is_local_plugin(spec.data)
		end)
		:totable()
end

---@param source NativePacker.PluginSource
---@return vim.pack.Spec[]
---@return vim.pack.Spec[]
local function build_specs(source)
	local plugin_specs = normalize_plugin_specs(source)
	local spec_map = {}
	local specs = sort_by_priority(plugin_specs, function(plugin_spec)
		local spec = create_spec(plugin_spec)
		local spec_name = spec.data[1] or spec.data.dir
		spec_map[spec_name] = spec
		return spec, spec.data.priority
	end)
	specs = get_specs_sort_by_depend_priority(specs, spec_map)
	return specs, filter_repo_specs(specs)
end

local function load_depend(data)
	for _, name in ipairs(data.depend) do
		local dp = M.plugin_map[name]
		if not dp.loaded then
			M.load(dp)
		end
	end
end

function M.load(data)
	load_depend(data)
	vim.cmd.packadd(data.name)
	if data.config and type(data.config) == "function" then
		data.config()
	end
	data.loaded = true
	Handler.clean(data)
end

local function packadd(data)
	if is_local_plugin(data) then
		M.local_plugin_map[data.name] = data
	else
		M.repo_plugin_map[data.name] = data
	end
	M.plugin_map[data.name] = data

	if data.startup then
		M.load(data)
	else
		Handler.register(data)
	end
end

local function create_skipped_packadd(all_specs)
	local pre_index = 0

	return function(data)
		local current_index = data.index
		if current_index > pre_index + 1 then
			local skip_specs = vim.list_slice(all_specs, pre_index + 1, current_index - 1)
			for _, spec in ipairs(skip_specs) do
				packadd(spec.data)
			end
		end
		pre_index = current_index
	end
end

local function create_remaining_packadd(total, all_specs)
	local current = 0
	return function(data)
		current = current + 1
		if current == total then
			if #all_specs > data.index then
				local skip_specs = vim.list_slice(all_specs, data.index + 1, #all_specs)
				for _, spec in ipairs(skip_specs) do
					packadd(spec)
				end
			end
		end
	end
end

--- @param source NativePacker.PluginSource
function M.add(source)
	local specs, repo_specs = build_specs(source)
	local skipped_packadd = create_skipped_packadd(specs)
	local remaining_packadd = create_remaining_packadd(#repo_specs, specs)
	vim.pack.add(repo_specs, {
		load = function(plug_data)
			local data = plug_data.spec.data
			data.path = plug_data.path
			data.name = plug_data.spec.name
			skipped_packadd(data)
			packadd(data)
			remaining_packadd(data)
		end,
	})
end

---@param names string[]
function M.del(names)
	pcall(vim.pack.del, names)
end

---@param names? string[]
---@param opts? vim.pack.keyset.update
function M.update(names, opts)
	pcall(vim.pack.update, names, opts)
end

return M
