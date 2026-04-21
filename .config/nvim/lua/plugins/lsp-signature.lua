return {
  "ray-x/lsp_signature.nvim",
  event = "LspAttach",
  opts = {
    bind = true,
    handler_opts = {
      border = "rounded",
    },
    hint_enable = false,
    floating_window_above_cur_line = true,
  },
  config = function(_, opts)
    require("lsp_signature").setup(opts)

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        require("lsp_signature").on_attach(opts, args.buf)
      end,
    })
  end,
}
