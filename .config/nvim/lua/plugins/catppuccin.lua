return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  opts = {
    -- 落ち着いたライトテーマを使う。
    flavour = "latte",
    -- Ghostty 側の透過を活かすため、背景を透過させる。
    transparent_background = true,
    -- 各プラグインの UI を catppuccin latte で統一する。
    integrations = {
      blink_cmp = true,
      gitsigns = true,
      indent_blankline = { enabled = true },
      neotree = true,
      telescope = { enabled = true },
      treesitter = true,
      which_key = true,
      trouble = true,
      -- LSP の診断表示（下線・仮想テキスト）に latte の色を適用する。
      native_lsp = {
        enabled = true,
        virtual_text = {
          errors = { "italic" },
          hints = { "italic" },
          warnings = { "italic" },
          information = { "italic" },
        },
        underlines = {
          errors = { "underline" },
          hints = { "underline" },
          warnings = { "underline" },
          information = { "underline" },
        },
        inlay_hints = { background = true },
      },
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    -- 起動時に catppuccin を色テーマとして適用する。
    vim.cmd.colorscheme("catppuccin")

    local flavour = opts.flavour or "latte"
    local palette = require("catppuccin.palettes").get_palette(flavour)

    -- transparent_background によりフロートも透明になるため、
    -- 背景を mantle で塗り直してエディタ本体から浮き上がらせる。
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = palette.mantle })
    vim.api.nvim_set_hl(0, "FloatBorder", { fg = palette.lavender, bg = palette.mantle })
    vim.api.nvim_set_hl(0, "BlinkCmpDocBorder", { fg = palette.lavender, bg = palette.mantle })
    vim.api.nvim_set_hl(0, "BlinkCmpSignatureHelpBorder", { fg = palette.lavender, bg = palette.mantle })

    -- 対応する括弧を控えめに、カーソル直下の括弧は少し強めに見せる。
    vim.api.nvim_set_hl(0, "MatchParen", {
      fg = palette.overlay2,
      bg = palette.surface0,
      bold = true,
      nocombine = true,
    })
    vim.api.nvim_set_hl(0, "MatchParenCur", {
      fg = palette.subtext1,
      bg = palette.surface1,
      bold = true,
      nocombine = true,
    })
  end,
}
