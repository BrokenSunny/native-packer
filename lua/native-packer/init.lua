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
		require("native-packer.core").load(args.fargs)
	end, {
		nargs = "*",
		complete = function()
			return require("native-packer.core").get_all_plugin_names()
		end,
	})
	vim.api.nvim_create_user_command("NativePackerGet", function(args)
		vim.print(require("native-packer.core").get(args.fargs))
	end, {
		nargs = "*",
		complete = function()
			return require("native-packer.core").get_all_repo_plugin_names()
		end,
	})
	vim.api.nvim_create_user_command("NativePacker", function(args) end, {
		nargs = 0,
	})
	require("native-packer.key.core").load_filetype()
	require("native-packer.key.core").load_event()
end

return M
