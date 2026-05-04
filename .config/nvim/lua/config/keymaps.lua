-- `-` で現在ファイルの親ディレクトリを Oil で開けるようにする。
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory in Oil" })

-- `<C-n>` で現在ファイルに追従した neo-tree を右側にトグルする。
vim.keymap.set("n", "<C-n>", "<cmd>Neotree filesystem reveal right toggle<cr>", {
  desc = "Neo-tree (right)",
})
vim.keymap.set("n", "<leader>e", "<cmd>Neotree filesystem reveal right toggle<cr>", {
  desc = "Explorer (neo-tree)",
})

-- 定義ジャンプなどで移動した後、ひとつ前の場所へ戻る。
vim.keymap.set("n", "gb", "<C-o>", { desc = "Go back in jumplist" })

-- よく使う基本操作。
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })

-- fzf-lua でファイルや文字列を検索する。
vim.keymap.set("n", "<leader><space>", function()
  require("fzf-lua").files()
end, { desc = "Find files" })

vim.keymap.set("n", "<leader>/", function()
  require("fzf-lua").live_grep()
end, { desc = "Live grep" })

vim.keymap.set("n", "<leader>,", function()
  require("fzf-lua").buffers()
end, { desc = "Buffers" })

vim.keymap.set("n", "<leader>ff", function()
  require("fzf-lua").files()
end, { desc = "Find files" })

vim.keymap.set("n", "<leader>fg", function()
  require("fzf-lua").live_grep()
end, { desc = "Live grep" })

vim.keymap.set("n", "<leader>fb", function()
  require("fzf-lua").buffers()
end, { desc = "Buffers" })

vim.keymap.set("n", "<leader>fh", function()
  require("fzf-lua").helptags()
end, { desc = "Help tags" })

vim.keymap.set("n", "<leader>fr", function()
  require("fzf-lua").oldfiles()
end, { desc = "Recent files" })

vim.keymap.set("n", "<leader>fc", function()
  require("fzf-lua").files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Find config file" })

vim.keymap.set("n", "<leader>gs", function()
  require("fzf-lua").git_status()
end, { desc = "Git status" })

vim.keymap.set("n", "<leader>gc", function()
  require("fzf-lua").git_commits()
end, { desc = "Git commits" })

vim.keymap.set("n", "<leader>gd", function()
  require("fzf-lua").git_diff()
end, { desc = "Git diff" })

-- LSP/diagnostic 系の補助操作。
vim.keymap.set("n", "<leader>cf", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })

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
