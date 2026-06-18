return {
  "sindrets/diffview.nvim",
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewFileHistory",
  },
  keys = {
    { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Git diff view" },
    { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "Close git diff view" },
    { "<leader>gF", "<cmd>DiffviewToggleFiles<cr>", desc = "Toggle diff files" },
    { "<leader>gl", "<cmd>DiffviewFileHistory %<cr>", desc = "Current file history" },
    { "<leader>gL", "<cmd>DiffviewFileHistory<cr>", desc = "Git file history" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
}
