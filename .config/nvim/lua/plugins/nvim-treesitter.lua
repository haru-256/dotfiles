return {
  "nvim-treesitter/nvim-treesitter",
  -- Treesitter は lazy-load 非対応なので、起動時に読み込む。
  lazy = false,
  -- プラグイン更新時に parser も追従させる。
  build = ":TSUpdate",
  opts = {
    -- 今の設定で使う言語だけを最小限インストールする。
    ensure_installed = { "lua", "python", "vim", "vimdoc", "query" },
  },
  config = function(_, opts)
    local ts = require("nvim-treesitter")

    ts.setup({
      -- parser と query を標準 runtime より優先して使えるようにする。
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    -- scope 強調に必要な parser を起動時に揃える。
    ts.install(opts.ensure_installed):wait(300000)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "lua", "python", "vim", "query", "help" },
      callback = function(args)
        -- Treesitter ベースの構文ハイライトをそのバッファで有効にする。
        pcall(vim.treesitter.start, args.buf)
        -- Treesitter ベースのインデント計算を有効にする。
        vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
