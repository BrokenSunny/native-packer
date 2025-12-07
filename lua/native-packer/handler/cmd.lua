local M = {}

local function notify()
	vim.notify("native-packer: cmd: string | string[]", vim.log.levels.ERROR)
end

function M.normalize(data)
	local cmd = data.cmd
	local cmds = {}

	if cmd then
		if type(cmd) == "string" then
			cmds = { cmd }
		elseif type(cmd) == "table" then
			for _, c in ipairs(cmd) do
				if type(c) == "string" then
					cmds[#cmds + 1] = c
				else
					notify()
				end
			end
		else
			notify()
		end
	end
	data.cmd = cmds
end

local function register(cmd, loader)
	vim.api.nvim_create_user_command(cmd, function(event)
		local command = {
			cmd = cmd,
			bang = event.bang or nil,
			mods = event.smods,
			args = event.fargs,
			count = event.count >= 0 and event.range == 0 and event.count or nil,
		}

		if event.range == 1 then
			command.range = { event.line1 }
		elseif event.range == 2 then
			command.range = { event.line1, event.line2 }
		end

		loader()

		local info = vim.api.nvim_get_commands({})[cmd] or vim.api.nvim_buf_get_commands(0, {})[cmd]
		if not info then
			return
		end

		command.nargs = info.nargs
		if event.args and event.args ~= "" and info.nargs and info.nargs:find("[1?]") then
			command.args = { event.args }
		end
		vim.cmd(command)
	end, {
		bang = true,
		range = true,
		nargs = "*",
		complete = function(_, line)
			loader()
			return vim.fn.getcompletion(line, "cmdline")
		end,
	})
end

function M.register(plugin)
	local cmds = plugin.cmd
	for _, cmd in ipairs(cmds) do
		register(cmd, function()
			require("native-packer.core").load({ plugin.name })
		end)
	end
end

function M.clean(plugin)
	for _, cmd in ipairs(plugin.cmd) do
		pcall(vim.api.nvim_del_user_command, cmd)
	end
end

return M
