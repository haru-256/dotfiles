return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  opts = {
    flavour = "latte",
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")

    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
    vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })

    local palette = require("catppuccin.palettes").get_palette("latte")

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
