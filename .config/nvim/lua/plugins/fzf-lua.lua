return {
  "ibhagwan/fzf-lua",
  cmd = "FzfLua",
  dependencies = { "nvim-mini/mini.icons" },
  opts = function()
    local actions = require("fzf-lua.actions")

    return {
      "default-title",
      fzf_colors = true,
      fzf_opts = {
        ["--no-scrollbar"] = true,
      },
      defaults = {
        formatter = "path.dirname_first",
      },
      winopts = {
        width = 0.8,
        height = 0.8,
        row = 0.5,
        col = 0.5,
        preview = {
          scrollchars = { "┃", "" },
        },
      },
      files = {
        cwd_prompt = false,
        actions = {
          ["alt-h"] = { actions.toggle_hidden },
          ["alt-i"] = { actions.toggle_ignore },
        },
      },
      grep = {
        actions = {
          ["alt-h"] = { actions.toggle_hidden },
          ["alt-i"] = { actions.toggle_ignore },
        },
      },
      lsp = {
        symbols = {
          child_prefix = false,
        },
      },
    }
  end,
  config = function(_, opts)
    if opts[1] == "default-title" then
      local function fix(t)
        t.prompt = t.prompt ~= nil and " " or nil
        for _, v in pairs(t) do
          if type(v) == "table" then
            fix(v)
          end
        end
        return t
      end
      opts = vim.tbl_deep_extend("force", fix(require("fzf-lua.profiles.default-title")), opts)
      opts[1] = nil
    end

    require("fzf-lua").setup(opts)
    require("fzf-lua").register_ui_select()
  end,
}
