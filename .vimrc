" solarized設定
syntax enable
set background=dark
colorscheme solarized

" 日本語設定
set encoding=utf-8
set fileencodings=iso-2022-jp,utf-8,cp932,euc-jp " 読み込み時の文字コードの自動判別. 左側が優先される

set fileencoding=utf-8 " 保存時の文字コード
set fileformats=unix,dos,mac " 改行コードの自動判別. 左側が優先される
set ambiwidth=double " □や○文字が崩れる問題を解決

" 行番号を表示
set number

set guifont=Ricty_Discord:h16

set whichwrap=b,s,h,l,<,>,[,],~ " カーソルの左右移動で行末から次の行の行頭への移動が可能になる
set number " 行番号を表示
set cursorline " カーソルラインをハイライト

" 行が折り返し表示されていた場合、行単位ではなく表示行単位でカーソルを移動する
nnoremap j gj
nnoremap k gk
nnoremap <down> gj
nnoremap <up> gk

" バックスペースキーの有効化
set backspace=indent,eol,start
