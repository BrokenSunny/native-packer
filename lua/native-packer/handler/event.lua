local M = {}

local function is_event_config(event)
	return type(event) == "table" and type(event.event) == "string"
end

local function is_event_string(event)
	return type(event) == "string"
end

function M.normalize(data)
	local event = data.event
	local events = {}

	if is_event_string(event) then
		event = { event }
	elseif type(event) == "table" then
		if is_event_config(event) then
			event = { event }
		end
	else
		event = {}
	end

	for _, e in ipairs(event) do
		local event = {}
		if is_event_string(e) then
			event.event = e
		elseif is_event_config(e) then
			event.event = e.event
			event.pattern = type(e.pattern) == "string" and e.pattern or nil
		end
		table.insert(events, event)
	end
	data.event = events
end

function M.register(plugin)
	local events = plugin.event
	if #events == 0 then
		return
	end

	local group = vim.api.nvim_create_augroup(plugin.name .. ":event", { clear = false })
	for _, event in ipairs(events) do
		local opt = {
			group = group,
			callback = function()
				require("native-packer.core").load({ plugin.name })
			end,
			pattern = event.pattern,
			once = true,
		}
		vim.api.nvim_create_autocmd(event.event, opt)
	end
end

function M.clean(plugin)
	if #plugin.event == 0 then
		return
	end
	pcall(vim.api.nvim_del_augroup_by_name, plugin.name .. ":event")
end

return M
