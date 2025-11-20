local M = {}

function M.clean(data)
	require("native-packer.handler.cmd").clean(data)
	require("native-packer.handler.colorscheme").clean(data)
	require("native-packer.handler.event").clean(data)
	require("native-packer.handler.ft").clean(data)
	require("native-packer.handler.key").clean(data)
end

function M.register(data)
	require("native-packer.handler.cmd").register(data)
	require("native-packer.handler.colorscheme").register(data)
	require("native-packer.handler.event").register(data)
	require("native-packer.handler.ft").register(data)
	require("native-packer.handler.key").register(data)
end

function M.normalize(data)
	require("native-packer.handler.cmd").normalize(data)
	require("native-packer.handler.colorscheme").normalize(data)
	require("native-packer.handler.event").normalize(data)
	require("native-packer.handler.ft").normalize(data)
	require("native-packer.handler.key").normalize(data)
end

return M
