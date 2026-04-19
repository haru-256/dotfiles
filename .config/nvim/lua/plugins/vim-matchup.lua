return {
  "andymass/vim-matchup",
  -- 括弧の上だけでなく、括弧の内側にいる間も surrounding pair を見やすくする。
  lazy = false,
  init = function()
    -- カーソル移動中の負荷を抑えつつ、少し遅延してハイライトする。
    vim.g.matchup_matchparen_deferred = 1
    -- カーソルが括弧の内側にある間も surrounding pair を強調する。
    vim.g.matchup_matchparen_hi_surround_always = 1
    -- 画面外の対応括弧は小さな popup で表示する。
    vim.g.matchup_matchparen_offscreen = { method = "popup" }
  end,
}
