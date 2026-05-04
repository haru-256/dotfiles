return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    signs = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "" },
      topdelete = { text = "" },
      changedelete = { text = "▎" },
      untracked = { text = "▎" },
    },
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns
      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      map("n", "]h", gs.next_hunk, "Next git hunk")
      map("n", "[h", gs.prev_hunk, "Previous git hunk")
      map("n", "]H", function()
        gs.nav_hunk("last")
      end, "Last git hunk")
      map("n", "[H", function()
        gs.nav_hunk("first")
      end, "First git hunk")
      map({ "n", "x" }, "<leader>ghs", gs.stage_hunk, "Stage git hunk")
      map({ "n", "x" }, "<leader>ghr", gs.reset_hunk, "Reset git hunk")
      map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo stage git hunk")
      map("n", "<leader>ghS", gs.stage_buffer, "Stage buffer")
      map("n", "<leader>ghR", gs.reset_buffer, "Reset buffer")
      map("n", "<leader>ghp", gs.preview_hunk, "Preview git hunk")
      map("n", "<leader>ghb", gs.blame_line, "Blame current line")
      map("n", "<leader>ghd", gs.diffthis, "Diff this")
      map("n", "<leader>hp", gs.preview_hunk, "Preview git hunk")
      map("n", "<leader>hb", gs.blame_line, "Blame current line")
      map("n", "<leader>hr", gs.reset_hunk, "Reset git hunk")
    end,
  },
}
