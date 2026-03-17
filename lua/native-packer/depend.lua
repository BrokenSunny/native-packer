local M = {}

function M.normalize(data)
  local source = data.depend
  local depends = {}

  if type(source) == "string" then
    source = { source }
  elseif type(source) == "table" then
    source = source
  else
    source = {}
  end

  for _, dp in ipairs(source) do
    if type(dp) == "string" then
      depends[#depends + 1] = dp
    else
      vim.notify("native-packer: depend: string | string[]", vim.log.levels.ERROR)
    end
  end

  data.depend = depends
end

return M
