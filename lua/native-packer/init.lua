local M = {}

--- @param source NativePacker.Plugin
function M.add(source)
  require("native-packer.core").add(source)
end

return M
