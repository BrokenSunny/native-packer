local M = {}

function M.setup(source)
	require("native-packer.core").add(source)
	vim.api.nvim_create_user_command("NativePackerUpdate", function(args)
		require("native-packer.core").update(args.fargs, { force = args.bang })
	end, {
		bang = true,
		nargs = "*",
		complete = function()
			return require("native-packer.core").get_all_repo_plugin_names()
		end,
	})
	vim.api.nvim_create_user_command("NativePackerUpdateAll", function(args)
		local names = require("native-packer.core").get_all_repo_plugin_names()
		require("native-packer.core").update(names, { force = args.bang })
	end, {
		bang = true,
		nargs = 0,
	})
	vim.api.nvim_create_user_command("NativePackerDelete", function(args)
		require("native-packer.core").del(args.fargs)
	end, {
		nargs = "*",
		complete = function()
			return require("native-packer.core").get_all_repo_plugin_names()
		end,
	})
	vim.api.nvim_create_user_command("NativePackerLoad", function(args)
		for _, value in ipairs(args.fargs) do
			local data = require("native-packer.core").repo_plugin_map[value]
			if type(data) == "table" then
				require("native-packer.core").load(data)
			end
		end
	end, {
		nargs = "*",
		complete = function()
			return require("native-packer.core").get_all_plugin_names()
		end,
	})
	require("native-packer.key.core").load_filetype()
	require("native-packer.key.core").load_event()
end

return M
