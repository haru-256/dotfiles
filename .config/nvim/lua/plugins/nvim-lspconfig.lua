return {
  "neovim/nvim-lspconfig",
  lazy = false,
  config = function()
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local opts = { buffer = args.buf }

        -- LSP が attach したバッファだけに、定義ジャンプなどのキーマップを生やす。
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, {
          desc = "Go to definition",
        }))
        vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, {
          desc = "Show references",
        }))
        vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, {
          desc = "Hover documentation",
        }))
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, {
          desc = "Rename symbol",
        }))
      end,
    })

    -- Go の定義ジャンプや補完などを gopls で提供する。
    vim.lsp.config("gopls", {
      cmd = { "gopls" },
    })
    vim.lsp.enable("gopls")

    -- Python の定義ジャンプや型情報を basedpyright で提供する。
    vim.lsp.config("basedpyright", {
      cmd = { "basedpyright-langserver", "--stdio" },
    })
    vim.lsp.enable("basedpyright")
  end,
}
