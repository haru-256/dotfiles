fish_add_path $HOME/.local/bin
fish_add_path /usr/local/sbin

# homebrew
fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin

fish_add_path $HOME/.fig/bin

# fish completions
# https://docs.brew.sh/Shell-Completion#configuring-completions-in-fish
if test -d (brew --prefix)"/share/fish/completions"
    set -p fish_complete_path (brew --prefix)/share/fish/completions
end
if test -d (brew --prefix)"/share/fish/vendor_completions.d"
    set -p fish_complete_path (brew --prefix)/share/fish/vendor_completions.d
end

# ssh
eval (ssh-agent -c) >/dev/null
# ssh-add ~/.ssh/id_ed25519 >/dev/null 2>&1
/usr/bin/ssh-add -K ~/.ssh/id_ed25519 >/dev/null 2>&1 # add private key to ssh-agent


set -x LANG ja_JP.UTF-8

# zlib, bzip2
# set -x LDFLAGS -L/usr/local/opt/zlib/lib
# set -x CPPFLAGS -I/usr/local/opt/zlib/include
# set -x PKG_CONFIG_PATH /usr/local/opt/zlib/lib/pkgconfig
# set -x LDFLAGS -L/usr/local/opt/bzip2/lib $LDFLAGS
# set -x CPPFLAGS -I/usr/local/opt/bzip2/include $CPPFLAGS
# fish_add_path /usr/local/opt/bzip2/bin

# pipenv
set -x PIPENV_VENV_IN_PROJECT 1
set -x PIPENV_IGNORE_VIRTUALENVS 1

# brew cleanup
set -x HOMEBREW_NO_INSTALL_CLEANUP 1


# run this function at logout
function on_exit --on-process %self
    ssh-agent -k >/dev/null 2>&1 # kill ssh-agent
end

# direnv
#eval (direnv hook fish) # occuring Error
direnv hook fish | source

# starship
starship init fish | source

# fish color settings
set -x fish_color_command magenta
set -x fish_color_param normal
set -x fish_color_option green
set -x fish_color_operator yellow
set -x fish_color_quote yellow
set -x fish_color_error red

# alias
if type -q eza
    alias g="git"
end
if type -q eza
    alias e="eza"
end
if type -q terraform
    alias tf="terraform"
end
if type -q terraformer
    alias tf="terraformer"
end
if type -q kubectl
    alias k="kubectl"
end
alias snowsql=/Applications/SnowSQL.app/Contents/MacOS/snowsql
if type -q glow
    alias md="glow -p -"
end
alias cdr="cd (git rev-parse --show-toplevel)"


# dracula theme
source ~/.config/fish/conf.d/dracula.fish

# add path for gcloud
source "$(brew --prefix)/share/google-cloud-sdk/path.fish.inc"

set -x COLORTERM truecolor

# java
fish_add_path /opt/homebrew/opt/openjdk/bin
set -gx CPPFLAGS -I/opt/homebrew/opt/openjdk/include

# rust
# fish_add_path "$HOME/.cargo/bin"

# fzf
set -x FZF_DEFAULT_OPTS "--layout=reverse --border=rounded --color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
# bind for ghq + fzf
bind \c] "ghq-fzf && commandline -f repaint"

# asdf
source /opt/homebrew/opt/asdf/libexec/asdf.fish
# NOTE: 上記scriptのL14でfish_add_pathを使わないように書いているが、先頭に追加するためにfish_add_pathを使う
fish_add_path $HOME/.asdf/shims
