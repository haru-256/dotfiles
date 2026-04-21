return {
  "numToStr/Comment.nvim",
  lazy = false,
  opts = {
    mappings = {
      -- `gb` は jumplist back に使いたいので、basic mapping は自前で定義する。
      basic = false,
      extra = true,
    },
  },
}
