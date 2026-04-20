return {
  "stevearc/conform.nvim",
  lazy = false,
  opts = {
    formatters_by_ft = {
      go = { "goimports", "gofmt" },
    },
    format_on_save = function(bufnr)
      if vim.bo[bufnr].filetype == "go" then
        return {
          timeout_ms = 500,
          lsp_format = "fallback",
        }
      end
    end,
  },
}
