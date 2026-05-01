return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  opts = {
    -- 落ち着いたライトテーマを使う。
    flavour = "latte",
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    -- 起動時に catppuccin を色テーマとして適用する。
    vim.cmd.colorscheme("catppuccin")

    -- Ghostty 側の透過を活かすため、主要な背景色を描画しない。
    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
    vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })

    local palette = require("catppuccin.palettes").get_palette("latte")

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
