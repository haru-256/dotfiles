return {
  "neovim/nvim-lspconfig",
  lazy = false,
  config = function()
    local capabilities = require("blink.cmp").get_lsp_capabilities()

    -- hover ポップアップに丸みのある枠をつける。
    vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
      config = vim.tbl_deep_extend("force", config or {}, { border = "rounded" })
      return vim.lsp.handlers.hover(err, result, ctx, config)
    end

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local opts = { buffer = args.buf }

        -- LSP が attach したバッファだけに、定義ジャンプなどのキーマップを生やす。
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, {
          desc = "Go to definition",
        }))
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, {
          desc = "Go to declaration",
        }))
        vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, {
          desc = "Show references",
        }))
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", opts, {
          desc = "Go to implementation",
        }))
        vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, vim.tbl_extend("force", opts, {
          desc = "Go to type definition",
        }))
        vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, {
          desc = "Hover documentation",
        }))
        vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, vim.tbl_extend("force", opts, {
          desc = "Rename symbol",
        }))
        vim.keymap.set({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, {
          desc = "Code action",
        }))
        vim.keymap.set("n", "<leader>ls", function()
          require("telescope.builtin").lsp_document_symbols()
        end, vim.tbl_extend("force", opts, {
          desc = "Document symbols",
        }))
      end,
    })

    -- Go の定義ジャンプや補完などを gopls で提供する。
    vim.lsp.config("gopls", {
      cmd = { "gopls" },
      capabilities = capabilities,
    })
    vim.lsp.enable("gopls")

    -- Python の定義ジャンプや型情報を basedpyright で提供する。
    vim.lsp.config("basedpyright", {
      cmd = { "basedpyright-langserver", "--stdio" },
      capabilities = capabilities,
    })
    vim.lsp.enable("basedpyright")
  end,
}
