-- Neovim を最小構成で始めるための基本設定。

-- 基本表示
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.background = "dark"

-- 改行したときに、前の行のインデントを引き継ぐ。
vim.opt.autoindent = true
-- {} などを含む行では、次の行のインデントを少し賢く調整する。
vim.opt.smartindent = true

-- OS のクリップボードと連携して、yank した内容を他アプリでも使えるようにする。
vim.opt.clipboard = "unnamedplus"

-- キーマップの接頭辞として Space を使う。
vim.g.mapleader = " "
