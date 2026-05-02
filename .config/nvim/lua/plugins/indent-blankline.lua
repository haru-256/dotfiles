return {
  "lukas-reineke/indent-blankline.nvim",
  -- indent-blankline.nvim v3 系は ibl というモジュール名で設定する。
  main = "ibl",
  opts = {
    -- インデントの階層ごとに縦線を表示する。
    indent = {
      highlight = "IblIndent",
    },
    -- カーソル位置に対応するスコープのインデントだけ、少し明るい色で強調する。
    scope = {
      enabled = true,
      include = {
        node_type = {
          python = {
            "if_statement",
            "for_statement",
            "while_statement",
            "try_statement",
            "with_statement",
            "match_statement",
          },
        },
      },
    },
  },
  config = function(_, opts)
    local hooks = require("ibl.hooks")
    local palette = require("catppuccin.palettes").get_palette("latte")

    -- catppuccin latte の色に合わせて、通常のガイドは控えめに、
    -- active scope だけ少し目立つ色にする。
    hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
      vim.api.nvim_set_hl(0, "IblIndent", { fg = palette.surface2, nocombine = true })
      vim.api.nvim_set_hl(0, "IblScope", { fg = palette.lavender, nocombine = true })
    end)

    require("ibl").setup(opts)
  end,
}
