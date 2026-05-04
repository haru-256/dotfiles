return {
  "nvim-mini/mini.pairs",
  event = "InsertEnter",
  opts = {
    modes = {
      insert = true,
      command = true,
      terminal = false,
    },
    skip_ts = { "string" },
    skip_unbalanced = true,
    markdown = true,
  },
}
