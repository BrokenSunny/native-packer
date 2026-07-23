local M = {}
-- stylua: ignore
local EVENTS = { "BufAdd", "BufCreate", "BufDelete", "BufEnter", "BufFilePost", "BufFilePre", "BufHidden", "BufLeave",
  "BufNew", "BufNewFile", "BufRead", "BufReadCmd", "BufReadPost", "BufReadPre", "BufUnload", "BufWinEnter", "BufWinLeave",
  "BufWipeout", "BufWrite", "BufWriteCmd", "BufWritePost", "BufWritePre", "ChanClose", "ChanInfo", "ChanOpen",
  "CmdUndefined", "CmdlineChanged", "CmdlineEnter", "CmdlineLeave", "CmdlineLeavePre", "CmdwinEnter", "CmdwinLeave",
  "ColorScheme", "ColorSchemePre", "CompleteChanged", "CompleteDone", "CompleteDonePre", "CursorHold", "CursorHoldI",
  "CursorMoved", "CursorMovedC", "CursorMovedI", "DiagnosticChanged", "DiffUpdated", "DirChanged", "DirChangedPre",
  "EncodingChanged", "ExitPre", "FileAppendCmd", "FileAppendPost", "FileAppendPre", "FileChangedRO", "FileChangedShell",
  "FileChangedShellPost", "FileEncoding", "FileReadCmd", "FileReadPost", "FileReadPre", "FileType", "FileWriteCmd",
  "FileWritePost", "FileWritePre", "FilterReadPost", "FilterReadPre", "FilterWritePost", "FilterWritePre", "FocusGained",
  "FocusLost", "FuncUndefined", "GUIEnter", "GUIFailed", "InsertChange", "InsertCharPre", "InsertEnter", "InsertLeave",
  "InsertLeavePre", "LspAttach", "LspDetach", "LspNotify", "LspProgress", "LspRequest", "LspTokenUpdate", "MarkSet",
  "MenuPopup", "ModeChanged", "OptionSet", "PackChanged", "PackChangedPre", "Progress", "QuickFixCmdPost",
  "QuickFixCmdPre", "QuitPre", "RecordingEnter", "RecordingLeave", "RemoteReply", "SafeState", "SearchWrapped",
  "SessionLoadPost", "SessionLoadPre", "SessionWritePost", "SessionWritePre", "ShellCmdPost", "ShellFilterPost", "Signal",
  "SourceCmd", "SourcePost", "SourcePre", "SpellFileMissing", "StdinReadPost", "StdinReadPre", "SwapExists", "Syntax",
  "TabClosed", "TabClosedPre", "TabEnter", "TabLeave", "TabMoved", "TabNew", "TabNewEntered", "TermChanged", "TermClose",
  "TermEnter", "TermLeave", "TermOpen", "TermRequest", "TermResponse", "TextChanged", "TextChangedI", "TextChangedP",
  "TextChangedT", "TextPutPost", "TextPutPre", "TextYankPost", "UIEnter", "UILeave", "User", "VimEnter", "VimLeave",
  "VimLeavePre", "VimResized", "VimResume", "VimSuspend", "WinClosed", "WinEnter", "WinLeave", "WinNew", "WinNewPre",
  "WinResized", "WinScrolled", }

local MESSAGE = {
  not_available_pattern_type = function(plugin_name, t)
    return {
      {
        "NativePackerWarn: ["
        .. plugin_name
        .. "].event.pattern expected string, but got "
        .. t
        .. ". This config will be ignore!!!",
        "WarningMsg",
      },
    }
  end,
  not_available_condition_type = function(plugin_name, t)
    return {
      {
        "NativePackerWarn: ["
        .. plugin_name
        .. "].event.condition expected function, but got "
        .. t
        .. ". This config will be ignore!!!",
        "WarningMsg",
      },
    }
  end,
  not_available_event_type = function(plugin_name, t)
    return {
      {
        "NativePackerWarn: ["
        .. plugin_name
        .. "].event[integer] expected string, but got "
        .. t
        .. ". This config will be ignore!!!",
        "WarningMsg",
      },
    }
  end,
  not_available_event_value = function(plugin_name, event_name)
    return {
      {
        "NativePackerWarn: ["
        .. plugin_name
        .. "].event[integer] expected vim.api.keyset.events, "
        .. '"'
        .. event_name
        .. '" is not a available event!!!"',
        "WarningMsg",
      },
    }
  end,
}

--- @param condition any
--- @return fun()|nil
local function normalize_condition(condition, plugin_name)
  if condition ~= nil and type(condition) ~= "function" then
    vim.api.nvim_echo(MESSAGE.not_available_condition_type(plugin_name, type(condition)), true)
    condition = nil
  end
  return condition
end

--- @param pattern any
--- @return string|string[]|nil
local function normalize_pattern(pattern, plugin_name)
  if pattern ~= nil and type(pattern) ~= "table" and type(pattern) ~= "string" then
    vim.api.nvim_echo(MESSAGE.not_available_pattern_type(plugin_name, type(pattern)), true)
  end

  if type(pattern) == "table" then
    local new_pattern = {}
    for _, p in ipairs(pattern) do
      if type(p) ~= "string" then
        vim.api.nvim_echo(MESSAGE.not_available_pattern_type(plugin_name, type(pattern)), true)
      else
        new_pattern[#new_pattern + 1] = p
      end
    end
    pattern = new_pattern
  end

  return pattern
end

--- @param spec NativePacker.Plugin.Spec
--- @return NativePacker.Plugin.Data.Event
function M.normalize(spec)
  local plugin_name = spec[1] or spec.name
  local source = spec.event
  --- @type NativePacker.Plugin.Data.Event
  local event = {}

  if type(source) ~= "table" then
    source = { source }
  end

  --- @param s NativePacker.Plugin.Spec.Event.Spec
  local function normalize(s, config)
    local condition = normalize_condition(s.condition, plugin_name) or config.condition
    local pattern = normalize_pattern(s.pattern, plugin_name) or config.pattern

    for _, value in ipairs(s) do
      if type(value) == "string" then
        if vim.list_contains(EVENTS, value) then
          event[#event + 1] = { value, condition = condition, pattern = pattern }
        else
          vim.api.nvim_echo(MESSAGE.not_available_event_value(plugin_name, value), true)
        end
      elseif type(value) == "table" then
        normalize(value, { condition = condition, pattern = pattern })
      else
        vim.api.nvim_echo(MESSAGE.not_available_event_type(plugin_name, type(value)), true)
      end
    end
  end
  normalize(source, {})
  return event
end

--- @param data NativePacker.Plugin.Data
--- @param loader fun(data: NativePacker.Plugin.Data)
function M.register(data, loader)
  local events = data.event
  if #events == 0 then
    return
  end

  local group = vim.api.nvim_create_augroup("NativePacker:" .. (data.repo or data.name) .. ":event", { clear = false })
  for _, event in ipairs(events) do
    local opt = {
      group = group,
      callback = function()
        -- vim.print(event[1] .. ": load " .. data.name)
        loader(data)
      end,
      pattern = event.pattern,
      once = true,
    }
    vim.api.nvim_create_autocmd(event[1], opt)
  end
end

--- @param data NativePacker.Plugin.Data
function M.clean(data)
  if #data.event == 0 then
    return
  end
  pcall(vim.api.nvim_del_augroup_by_name, "NativePacker:" .. (data.repo or data.name) .. ":event")
end

--- @param event NativePacker.Plugin.Data.Event
--- @return boolean
function M.has(event)
  return #event > 0
end

return M
