local M = {}

--- @param spec NativePacker.Plugin.Spec
--- @return string[]
function M.normalize(spec)
  local plugin_name = spec[1] or spec.name
  local source = spec.cmd
  --- @type string[]
  local cmd = {}
  if type(source) ~= "table" then
    source = { source }
  end

  for _, value in ipairs(source) do
    if type(value) == "string" then
      cmd[#cmd + 1] = value
    else
      vim.api.nvim_echo({
        {
          "NativePackerWarn: [" .. plugin_name .. "].cmd[integer] expectd string, but got " .. type(value) .. "\n",
          "WarningMsg",
        },
      }, true)
    end
  end
  return cmd
end

--- @param data NativePacker.Plugin.Data
--- @param load fun()
function M.register(data, load)
  for _, cmd in ipairs(data.cmd) do
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

      load()

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
        require("native-packer.core").packadd({ data.name })
        return vim.fn.getcompletion(line, "cmdline")
      end,
    })
  end
end

--- @param data NativePacker.Plugin.Data
function M.clean(data)
  for _, cmd in ipairs(data.cmd) do
    vim.api.nvim_del_user_command(cmd)
  end
end

--- @param cmd string[]
--- @return boolean
function M.has(cmd)
  return #cmd > 0
end

return M
