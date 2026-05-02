return {
  "stevearc/conform.nvim",
  lazy = false,
  opts = {
    formatters_by_ft = {
      go = { "goimports", "gofmt" },
      python = { "ruff_format" },
    },
    format_on_save = function(bufnr)
      local ft = vim.bo[bufnr].filetype
      if ft == "go" or ft == "python" then
        return {
          timeout_ms = 500,
          lsp_format = "fallback",
        }
      end
    end,
  },
}
