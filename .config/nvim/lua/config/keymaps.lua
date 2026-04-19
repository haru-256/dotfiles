-- `-` で現在ファイルの親ディレクトリを Oil で開けるようにする。
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory in Oil" })

-- `<C-n>` で現在ファイルに追従した neo-tree を右側にトグルする。
vim.keymap.set("n", "<C-n>", "<cmd>Neotree filesystem reveal right toggle<cr>", {
  desc = "Neo-tree (right)",
})
