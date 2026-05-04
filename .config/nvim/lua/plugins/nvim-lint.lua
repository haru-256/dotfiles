return {
  "mfussenegger/nvim-lint",
  event = { "BufWritePost" },
  opts = {
    linters_by_ft = {
      go = { "golangcilint" },
      python = { "ruff" },
      fish = { "fish" },
    },
  },
  config = function(_, opts)
    local lint = require("lint")

    lint.linters_by_ft = opts.linters_by_ft

    vim.api.nvim_create_autocmd({ "BufWritePost" }, {
      group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
