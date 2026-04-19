return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  lazy = false,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  opts = {
    close_if_last_window = true,
    filesystem = {
      bind_to_cwd = true,
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
      filtered_items = {
        visible = false,
        hide_gitignored = true,
        hide_dotfiles = false,
      },
      window = {
        position = "right",
        width = 32,
        mappings = {
          ["<cr>"] = "open",
          ["l"] = "open",
          ["h"] = "close_node",
          ["s"] = "open_vsplit",
          ["S"] = "open_split",
          ["t"] = "open_tabnew",
          ["<space>"] = "toggle_node",
        },
      },
    },
    window = {
      mappings = {
        ["l"] = "open",
        ["h"] = "close_node",
      },
    },
  },
  config = function(_, opts)
    require("neo-tree").setup(opts)
  end,
}
