return {
  "folke/todo-comments.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {},
  keys = {
    {
      "<leader>st",
      function()
        require("todo-comments.fzf").todo()
      end,
      desc = "Todo comments",
    },
    {
      "<leader>sT",
      function()
        require("todo-comments.fzf").todo({ keywords = { "TODO", "FIX", "FIXME" } })
      end,
      desc = "Todo/Fix/Fixme comments",
    },
  },
}
