return {
  "MagicDuck/grug-far.nvim",
  cmd = { "GrugFar", "GrugFarWithin" },
  opts = {
    headerMaxWidth = 80,
  },
  keys = {
    {
      "<leader>sr",
      function()
        local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
        require("grug-far").open({
          transient = true,
          prefills = {
            filesFilter = ext ~= "" and "*." .. ext or nil,
          },
        })
      end,
      mode = { "n", "x" },
      desc = "Search and replace",
    },
  },
}
