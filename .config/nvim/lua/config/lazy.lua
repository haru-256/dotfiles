-- lazy.nvim を使ってプラグインを管理する。
-- 未インストールなら初回起動時に自動で取得する。
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- lazy.nvim がまだローカルにない場合だけ、GitHub から取得する。
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  -- git clone を実行して、lazy.nvim を Neovim のデータ領域に配置する。
  local clone_result = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })

  -- clone に失敗した場合は、Neovim 上にエラー内容を表示して以降の処理を止める。
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "lazy.nvim bootstrap failed:\n", "ErrorMsg" },
      { clone_result, "WarningMsg" },
    }, true, {})
    return
  end
end

-- lazy.nvim を runtimepath の先頭に追加して読み込めるようにする。
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
})
