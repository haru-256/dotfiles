-- Neovim を最小構成で始めるための基本設定。

-- 基本表示
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.background = "light"
vim.opt.winborder = "rounded"

-- LSP の診断アイコンが出ても行番号列の幅が変わらないようにする。
vim.opt.signcolumn = "yes"

-- スクロール時にカーソルの上下に常に 8 行のコンテキストを保つ。
vim.opt.scrolloff = 8

-- 垂直分割は右、水平分割は下に開く。
vim.opt.splitright = true
vim.opt.splitbelow = true

-- undo 履歴をファイルに書き出して、再起動後も u で戻れるようにする。
vim.opt.undofile = true

-- CursorHold イベントの発火間隔。LSP hover や gitsigns の応答速度に影響する。
vim.opt.updatetime = 250
-- キーシーケンスの待機時間。which-key のポップアップ表示速度に影響する。
vim.opt.timeoutlen = 300

-- 改行したときに、前の行のインデントを引き継ぐ。
vim.opt.autoindent = true
-- {} などを含む行では、次の行のインデントを少し賢く調整する。
vim.opt.smartindent = true

-- OS のクリップボードと連携して、yank した内容を他アプリでも使えるようにする。
vim.opt.clipboard = "unnamedplus"

-- キーマップの接頭辞として Space を使う。
vim.g.mapleader = " "
