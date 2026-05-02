-- `-` で現在ファイルの親ディレクトリを Oil で開けるようにする。
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory in Oil" })

-- `<C-n>` で現在ファイルに追従した neo-tree を右側にトグルする。
vim.keymap.set("n", "<C-n>", "<cmd>Neotree filesystem reveal right toggle<cr>", {
  desc = "Neo-tree (right)",
})

-- 定義ジャンプなどで移動した後、ひとつ前の場所へ戻る。
vim.keymap.set("n", "gb", "<C-o>", { desc = "Go back in jumplist" })

-- よく使う基本操作。
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })

-- 行コメントの toggle は残しつつ、`gb` は back に使えるようにする。
vim.keymap.set("n", "gc", "<Plug>(comment_toggle_linewise)", { desc = "Comment toggle linewise" })
vim.keymap.set("x", "gc", "<Plug>(comment_toggle_linewise_visual)", { desc = "Comment toggle linewise" })
vim.keymap.set("n", "gcc", function()
  return vim.v.count == 0 and "<Plug>(comment_toggle_linewise_current)" or "<Plug>(comment_toggle_linewise_count)"
end, { expr = true, desc = "Comment toggle current line" })

-- Telescope でファイルや文字列を検索する。
vim.keymap.set("n", "<leader>ff", function()
  require("telescope.builtin").find_files()
end, { desc = "Find files" })

vim.keymap.set("n", "<leader>fg", function()
  require("telescope.builtin").live_grep()
end, { desc = "Live grep" })

vim.keymap.set("n", "<leader>fb", function()
  require("telescope.builtin").buffers()
end, { desc = "Buffers" })

vim.keymap.set("n", "<leader>fh", function()
  require("telescope.builtin").help_tags()
end, { desc = "Help tags" })

-- LSP/diagnostic 系の補助操作。
vim.keymap.set("n", "<leader>lf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })

vim.keymap.set("n", "<leader>ld", vim.diagnostic.open_float, { desc = "Line diagnostic" })
vim.keymap.set("n", "<leader>lq", vim.diagnostic.setloclist, { desc = "Diagnostic list" })

-- 診断エラー・警告を順番に移動する。
vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]D", function()
  vim.diagnostic.jump({ count = math.huge })
end, { desc = "Last diagnostic" })
vim.keymap.set("n", "[D", function()
  vim.diagnostic.jump({ count = -math.huge })
end, { desc = "First diagnostic" })
