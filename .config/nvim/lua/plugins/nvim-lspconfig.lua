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
        local client = vim.lsp.get_client_by_id(args.data.client_id)

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
        vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, vim.tbl_extend("force", opts, {
          desc = "Rename symbol",
        }))
        vim.keymap.set({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, {
          desc = "Code action",
        }))
        vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, {
          desc = "Code action",
        }))
        vim.keymap.set("n", "<leader>ls", function()
          require("fzf-lua").lsp_document_symbols()
        end, vim.tbl_extend("force", opts, {
          desc = "Document symbols",
        }))
        vim.keymap.set("n", "<leader>cs", function()
          require("fzf-lua").lsp_document_symbols()
        end, vim.tbl_extend("force", opts, {
          desc = "Document symbols",
        }))

        if client and client:supports_method("textDocument/documentHighlight", args.buf) then
          local group = vim.api.nvim_create_augroup("lsp-document-highlight", { clear = false })
          vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            buffer = args.buf,
            group = group,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            buffer = args.buf,
            group = group,
            callback = vim.lsp.buf.clear_references,
          })
          vim.api.nvim_create_autocmd("LspDetach", {
            group = vim.api.nvim_create_augroup("lsp-document-highlight-detach", { clear = true }),
            callback = function(detach_args)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds({ group = "lsp-document-highlight", buffer = detach_args.buf })
            end,
          })
        end

        if client and client:supports_method("textDocument/inlayHint", args.buf) then
          vim.keymap.set("n", "<leader>lh", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }), { bufnr = args.buf })
          end, vim.tbl_extend("force", opts, {
            desc = "Toggle inlay hints",
          }))
        end
      end,
    })

    vim.lsp.config("lua_ls", {
      cmd = { "lua-language-server" },
      capabilities = capabilities,
      on_init = function(client)
        client.server_capabilities.documentFormattingProvider = false
        if client.workspace_folders then
          local path = client.workspace_folders[1].name
          if path ~= vim.fn.stdpath("config") and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc")) then
            return
          end
        end

        client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua, {
          runtime = {
            version = "LuaJIT",
            path = { "lua/?.lua", "lua/?/init.lua" },
          },
          workspace = {
            checkThirdParty = false,
            library = vim.tbl_extend("force", vim.api.nvim_get_runtime_file("", true), {
              "${3rd}/luv/library",
            }),
          },
        })
      end,
      settings = {
        Lua = {
          format = {
            enable = false,
          },
        },
      },
    })
    if vim.fn.executable("lua-language-server") == 1 then
      vim.lsp.enable("lua_ls")
    end

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
