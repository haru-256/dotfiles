return {
  "stevearc/oil.nvim",
  -- 遅延読み込みすると開き方によって不安定になりやすいため常時読み込む。
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    default_file_explorer = true,
    columns = {
      "icon",
    },
    view_options = {
      show_hidden = true,
    },
  },
}
