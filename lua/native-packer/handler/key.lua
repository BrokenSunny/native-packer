local M = {}

function M.normalize(data)
	local keys = data.key
	if type(keys) ~= "table" then
		data.key = {}
	end
end

function M.register(plugin)
	local keys = plugin.key
	plugin.key_resets = {}
	require("native-packer.key").add(keys, function(mode, lhs, rhs, opts, extra)
		local reset = function()
			local _rhs = rhs
			if not extra.expr and type(rhs) == "function" then
				rhs = function()
					_rhs(extra)
				end
			end
			pcall(vim.keymap.set, mode, lhs, rhs, opts)
		end
		table.insert(plugin.key_resets, reset)
		local handle = function()
			if extra.depend then
				local data = {
					depend = extra.depend,
				}
				require("native-packer.depend").normalize(data)
				require("native-packer.core").load(data.depend)
			end
			require("native-packer.core").load({ plugin.name })
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Ignore>" .. lhs, true, true, true), "i", false)
		end
		pcall(vim.keymap.set, mode, lhs, handle, vim.tbl_extend("force", opts, { expr = true }))
	end)
end

function M.clean(plugin)
	for _, callback in ipairs(plugin.key_resets or {}) do
		callback()
	end
	plugin.key_resets = {}
end

return M
