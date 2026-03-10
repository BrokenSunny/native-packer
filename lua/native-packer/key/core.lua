local M = {
	keymaps = {},
	delete_keymaps = {},
	filetypes = {},
	exclude_filetypes = {
		["blink-cmp-menu"] = {},
		["fzf"] = {},
	},
	events = {},
}

local KEYMAP_SET_OPTS = {
	noremap = true,
	nowait = true,
	silent = true,
	script = true,
	expr = true,
	unique = true,
	callback = true,
	desc = true,
	replace_keycodes = true,
	buffer = true,
	remap = true,
}

local KEYMAP_DEL_OPTS = {
	buffer = true,
}

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

local function collect_filetype_keymap(map, filetype, callback)
	if type(filetype) == "string" then
		map[filetype] = map[filetype] or {}
		table.insert(map[filetype], function(buf)
			callback(buf)
		end)
		return
	end

	if type(filetype) == "table" then
		for _, ft in ipairs(filetype) do
			collect_filetype_keymap(map, ft, callback)
		end
	end
end

local function collect_event_keymap(event, callback)
	if type(event) == "string" then
		M.events[event] = M.events[event] or {}
		table.insert(M.events[event], callback)
		return
	end

	if type(event) == "table" then
		for _, e in ipairs(event) do
			collect_event_keymap(e, callback)
		end
	end
end

local function get_opts(opts, parent_opts)
	local final_opts = {}
	for key, value in pairs(opts) do
		if type(key) == "string" then
			final_opts[key] = value
		end
	end
	final_opts = vim.tbl_extend("force", parent_opts or {}, final_opts)
	return final_opts
end

local function get_keymap_opts(map, opts)
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

local function set_keymap(mode, lhs, rhs, opts, extra)
	local _rhs = rhs
	if not opts.expr and type(rhs) == "function" then
		rhs = function()
			_rhs(extra)
		end
	end
	local ok, err = pcall(vim.keymap.set, mode, lhs, rhs, opts)
	if not ok then
		vim.schedule(function()
			vim.notify(("Keymap failed: %s"):format(err), vim.log.levels.WARN)
		end)
	end
end

---@param lhs string
---@param rhs string|fun()
---@param mode string
---@param opts vim.keymap.set.Opts
---@param extra NativePacker.KeySpec.Options
function M.set_keymap(lhs, rhs, mode, opts, extra, set)
	if not is_rhs(rhs) then
		vim.notify("rhs must be string or function")
		return
	end
	if type(mode) ~= "string" then
		vim.notify("mode must be string or table<string>")
		return
	end
	set = set or set_keymap
	collect_keymap(lhs, rhs, mode, extra)
	if extra.ft or extra.exclude_ft then
		collect_filetype_keymap(M.filetypes, extra.ft, function(buffer)
			set(mode, lhs, rhs, vim.tbl_extend("force", opts, { buffer = buffer }), extra)
		end)
		collect_filetype_keymap(M.exclude_filetypes, extra.exclude_ft, function(buffer)
			set(mode, lhs, rhs, vim.tbl_extend("force", opts, { buffer = buffer }), extra)
		end)
		return
	end
	if extra.event then
		collect_event_keymap(extra.event, function()
			set(mode, lhs, rhs, opts, extra)
		end)
		return
	end
	set(mode, lhs, rhs, opts, extra)
end

local function parse_mode(lhs, rhs, modes, parent_opts, set)
	for _, mode in ipairs(modes) do
		M.set_mode_keymap(lhs, rhs, mode, get_opts(modes, parent_opts), set)
	end
end

---@param lhs string
---@param rhs NativePacker.KeySpec.Rhs
---@param mode NativePacker.KeySpec.Mode
---@param opts NativePacker.KeySpec.Options
function M.set_mode_keymap(lhs, rhs, mode, opts, set)
	if type(mode) == "string" then
		M.set_keymap(lhs, rhs, mode, get_keymap_opts(KEYMAP_SET_OPTS, opts), opts, set)
	elseif type(mode) == "table" then
		parse_mode(lhs, rhs, mode, opts, set)
	end
end

local function parse_one_rhs(lhs, data, parent_opts, set)
	local rhs = data[1]
	local mode = data[2]
	M.set_mode_keymap(lhs, rhs, mode, get_opts(data, parent_opts), set)
end

local function parse_more_rhs(lhs, data, parent_opts, set)
	for _, value in ipairs(data) do
		parse_one_rhs(lhs, value, get_opts(data, parent_opts), set)
	end
end

---@param lhs string
---@param config NativePacker.KeySpec.Config
function M.parse_keymap(lhs, config, set)
	if type(config) ~= "table" then
		vim.notify("lhs = value must be table")
		return
	end
	local opts = get_opts(config, {})
	if is_rhs(config[1]) then
		parse_one_rhs(lhs, config, opts, set)
		return
	end
	if type(config[1]) == "table" then
		parse_more_rhs(lhs, config, opts, set)
	end
end

function M.load_filetype()
	if vim.tbl_count(M.filetypes) > 0 then
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("native-packer-keymap-filetype", {}),
			pattern = vim.tbl_keys(M.filetypes),
			callback = function(ev)
				local callbacks = M.filetypes[vim.bo.filetype] or {}
				for _, cb in ipairs(callbacks) do
					cb(ev.buf)
				end
			end,
		})
	end
	if vim.tbl_count(M.exclude_filetypes) > 0 then
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("native-packer-keymap-exclude-filetype", {}),
			pattern = "*",
			callback = function(ev)
				if M.exclude_filetypes[vim.bo.filetype] then
					return
				end
				for _, callbacks in pairs(M.exclude_filetypes) do
					for _, cb in ipairs(callbacks) do
						cb(ev.buf)
					end
				end
			end,
		})
	end
end

function M.load_event()
	for event, callbacks in pairs(M.events) do
		vim.api.nvim_create_autocmd(event, {
			group = vim.api.nvim_create_augroup("simple-keymap-event", {}),
			callback = function()
				for _, cb in ipairs(callbacks) do
					cb()
				end
			end,
		})
	end
end

local function del_keymap(lhs, mode, opts)
	M.delete_keymaps[lhs] = M.delete_keymaps[lhs] or {}
	M.delete_keymaps[lhs][mode] = opts
	local keymap_opts = get_keymap_opts(KEYMAP_DEL_OPTS, opts)
	pcall(vim.keymap.del, mode, lhs, keymap_opts)
end

local function parse_delete_keymap(lhs, data)
	local opts = get_opts(data)

	for _, mode in ipairs(data) do
		if type(mode) == "string" then
			collect_event_keymap("BufReadPre", function()
				del_keymap(lhs, mode, opts)
			end)
		elseif type(mode) == "table" then
			parse_delete_keymap(lhs, vim.tbl_extend("force", opts, mode))
		end
	end
end

---@param source NativePacker.KeySpec
function M.add(source, set)
	for lhs, config in pairs(source) do
		M.parse_keymap(lhs, config, set)
	end
end

function M.del(source)
	for lhs, config in pairs(source) do
		parse_delete_keymap(lhs, config)
	end
end

--- @param lhs string
--- | '"ALL"'
function M.get(lhs)
	if lhs == "ALL" then
		return M.keymaps
	end
	return M.keymaps[lhs]
end

return M
