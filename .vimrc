"
" Vim8用サンプル vimrc
"
if has('win32')                   " Windows 32bit または 64bit ?
  set encoding=cp932              " cp932 が嫌なら utf-8 にしてください
else
  set encoding=utf-8
endif
scriptencoding utf-8              " This file's encoding

" 推奨設定の読み込み (:h default.vim)
unlet! skip_defaults_vim
source $VIMRUNTIME/defaults.vim

"===============================================================================
" 設定の追加はこの行以降でおこなうこと！
" 分からないオプション名は先頭に ' を付けてhelpしましょう。例:
" :h 'helplang

" syntax hilight for fish file
if &shell =~# 'fish$'
    set shell=sh
endif

" packadd! vimdoc-ja                " 日本語help の読み込み
" set helplang=ja,en                " help言語の設定

set number " 行番号を表示
set cursorline " カーソルラインをハイライト
set incsearch " seearch方法をwebブラウザのように
set scrolloff=0
set laststatus=2                  " 常にステータス行を表示する
set cmdheight=2                   " hit-enter回数を減らすのが目的
if !has('gui_running')            " gvimではない？ (== 端末)
  set mouse=                      " マウス無効 (macOS時は不便かも？)
  set ttimeoutlen=0               " モード変更時の表示更新を最速化
  if $COLORTERM == "truecolor"    " True Color対応端末？
    set termguicolors
  endif
endif
set nofixendofline                " Windowsのエディタの人達に嫌われない設定
set ambiwidth=double              " ○, △, □等の文字幅をASCII文字の倍にする
set directory-=.                  " swapファイルはローカル作成がトラブル少なめ
set formatoptions+=mM             " 日本語の途中でも折り返す
let &grepprg="grep -rnIH --exclude=.git --exclude-dir=.hg --exclude-dir=.svn --exclude=tags"
let loaded_matchparen = 1         " カーソルが括弧上にあっても括弧ペアをハイライトさせない

" :grep 等でquickfixウィンドウを開く (:lgrep 等でlocationlistウィンドウを開く)
augroup qf_win
autocmd!
autocmd QuickfixCmdPost [^l]* copen
autocmd QuickfixCmdPost l* lopen
augroup END

" マウスの中央ボタンクリックによるクリップボードペースト動作を抑制する
noremap <MiddleMouse> <Nop>
noremap! <MiddleMouse> <Nop>
noremap <2-MiddleMouse> <Nop>
noremap! <2-MiddleMouse> <Nop>
noremap <3-MiddleMouse> <Nop>
noremap! <3-MiddleMouse> <Nop>
noremap <4-MiddleMouse> <Nop>
noremap! <4-MiddleMouse> <Nop>

" 括弧等の自動補完
inoremap { {}<LEFT>
inoremap [ []<LEFT>
inoremap ( ()<LEFT>
inoremap " ""<LEFT>
inoremap ' ''<LEFT>
"-------------------------------------------------------------------------------
" ステータスライン設定
let &statusline = "%<%f %m%r%h%w[%{&ff}][%{(&fenc!=''?&fenc:&enc).(&bomb?':bom':'')}] "
if has('iconv')
  let &statusline .= "0x%{FencB()}"

  function! FencB()
    let c = matchstr(getline('.'), '.', col('.') - 1)
    if c != ''
      let c = iconv(c, &enc, &fenc)
      return s:Byte2hex(s:Str2byte(c))
    else
      return '0'
    endif
  endfunction
  function! s:Str2byte(str)
    return map(range(len(a:str)), 'char2nr(a:str[v:val])')
  endfunction
  function! s:Byte2hex(bytes)
    return join(map(copy(a:bytes), 'printf("%02X", v:val)'), '')
  endfunction
else
  let &statusline .= "0x%B"
endif
let &statusline .= "%=%l,%c%V %P"

"-------------------------------------------------------------------------------
" ファイルエンコーディング検出設定
let &fileencoding = &encoding
if has('iconv')
  if &encoding ==# 'utf-8'
    let &fileencodings = 'iso-2022-jp,euc-jp,cp932,' . &fileencodings
  else
    let &fileencodings .= ',iso-2022-jp,utf-8,ucs-2le,ucs-2,euc-jp'
  endif
endif
" 日本語を含まないファイルのエンコーディングは encoding と同じにする
if has('autocmd')
  function! AU_ReSetting_Fenc()
    if &fileencoding =~# 'iso-2022-jp' && search("[^\x01-\x7e]", 'n') == 0
      let &fileencoding = &encoding
    endif
  endfunction
  augroup resetting_fenc
    autocmd!
    autocmd BufReadPost * call AU_ReSetting_Fenc()
  augroup END
endif

"-------------------------------------------------------------------------------
" カラースキームの設定
"colorscheme torte
" syntax enable
" set background=dark
" colorscheme solarized

try
  silent hi CursorIM
catch /E411/
   "CursorIM (IME ON中のカーソル色)が定義されていなければ、紫に設定
  hi CursorIM ctermfg=16 ctermbg=127 guifg=#000000 guibg=#af00af
endtry

" Tab, インデントの設定
set et ts=4 sw=0

" インデントガイドの設定を変更"
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_guide_size = 1
let g:indent_guides_start_level = 2
"自動カラーを無効にする"
" let g:indent_guides_auto_colors=0
" 奇数インデントのカラー
" autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd   ctermbg=darkgray
" 偶数インデントのカラー
" autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=darkgray
"-------------------------------------------------------------------------------
" vim-plugの設定開始(begineの引数はVimプラグインが格納されているディレクトリ)
call plug#begin('~/.vim/plugged')

" NERDTreeのインストール
Plug 'scrooloose/nerdtree'

" tcomment_vimのインストール
Plug 'tomtom/tcomment_vim'

" vim-trailing-whitespaceのインストール
Plug 'bronson/vim-trailing-whitespace'

" mattn/emmet-vimのインストール
Plug 'mattn/emmet-vim'
" emmet-vimの設定を書き換える
let g:user_emmet_settings = {
\   'lang' : 'ja'
\ }

" tpope/vim-surroundのインストール
Plug 'tpope/vim-surround'

" hail2u/vim-css3-syntaxのインストール
Plug 'hail2u/vim-css3-syntax'

" pangloss/vim-javascriptのインストール
Plug 'pangloss/vim-javascript'

" othree/html5.vimのインストール
Plug 'othree/html5.vim'

" vim-indent-guideのインストール
Plug 'nathanaelkane/vim-indent-guides'

" jedi-vim のインストール
Plug 'davidhalter/jedi-vim'

" solarizedのインストール
Plug 'altercation/vim-colors-solarized'

" monokaiのインストール
Plug 'crusoexia/vim-monokai'

" vim-fish
Plug 'dag/vim-fish'

" install with vim-plug
Plug 'haishanh/night-owl.vim'

Plug 'techtuner/aura-neovim'

Plug 'dracula/vim', { 'as': 'dracula' }

Plug 'catppuccin/vim', { 'as': 'catppuccin' }

" 他のインストールしたいVimプラグいんがあれば，同様に記述する

" vim-plugの設定終了
call plug#end()
"-------------------------------------------------------------------------------
syntax enable
set background=dark
colorscheme catppuccin_mocha
set termguicolors

" 透過させるために背景色などをなくす
highlight Normal ctermbg=NONE guibg=NONE
highlight NonText ctermbg=NONE guibg=NONE
highlight SpecialKey ctermbg=NONE guibg=NONE
highlight EndOfBuffer ctermbg=NONE guibg=NONE
