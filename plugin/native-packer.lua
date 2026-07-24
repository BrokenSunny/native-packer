vim.api.nvim_create_user_command("NativePackerLoad", function(ev)
  require("native-packer.core").load(ev.fargs)
end, {
  nargs = "*",
  complete = function()
    return vim.tbl_keys(require("native-packer.core").plugin_spec_datas_by_plugin_name)
  end,
})
