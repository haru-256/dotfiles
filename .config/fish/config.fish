if not functions -q fisher
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fish -c fisher
end

# 言語を日本語に
set -x LANG ja_JP.UTF-8

# prevent worning for pyenv from brew
# alias brew="env PATH=(string match -v /Users/yohei/.pyenv/shims $PATH | string join ':') brew"

# pyenv
# set -x  PYENV_ROOT "$HOME/.pyenv" # this env is setted by universal scope
# set -x  PATH "$PYENV_ROOT/bin" $PATH # this env is setted by universal scope
status is-login; and pyenv init --path | source

# zlib, bzip2
set -x LDFLAGS -L/usr/local/opt/zlib/lib
set -x CPPFLAGS -I/usr/local/opt/zlib/include
set -x PKG_CONFIG_PATH /usr/local/opt/zlib/lib/pkgconfig
set -x LDFLAGS -L/usr/local/opt/bzip2/lib
set -x CPPFLAGS -I/usr/local/opt/bzip2/include
set -x PATH /usr/local/opt/bzip2/bin $PATH

# pipenv
set -x PIPENV_VENV_IN_PROJECT 1
set -x PIPENV_IGNORE_VIRTUALENVS 1


# brew cleanup
set -x HOMEBREW_NO_INSTALL_CLEANUP 0

# goenv
set -x PATH $GOENV_ROOT/bin $PATH
source (goenv init - | psub)
set -x PATH "$GOROOT/bin" $PATH
set -x PATH "$GOPATH/bin" $PATH

# ssh
eval (ssh-agent -c) >/dev/null
ssh-add -K ~/.ssh/id_ed25519 >/dev/null 2>&1 # add private key to ssh-agent

# ぐるなびAPI
set -x GNAVI_KEYID f1eb48f37e746c71fbbec92d981312b1

# run this function at logout
function on_exit --on-process %self
    ssh-agent -k >/dev/null 2>&1 # kill ssh-agent
end

# direnv
#eval (direnv hook fish) # occuring Error
direnv hook fish | source

# node.js
set -x PATH $HOME/.nodebrew/current/bin $PATH

# starship
starship init fish | source

# fish color settings
set -x fish_color_command magenta
set -x fish_color_param normal
set -x fish_color_option green
set -x fish_color_operator yellow
set -x fish_color_quote yellow
set -x fish_color_error red

# for scipy
# https://github.com/pypa/pipenv/issues/4564
set -x SYSTEM_VERSION_COMPAT 1

# alias
alias e="exa"
alias g="git"
alias e="exa"
alias tf="terraform"
alias tfr="terraformer"
alias make="gmake"
alias k="kubectl"

set -x PATH /usr/local/sbin $PATH

# key bindings
bind \cf "forward-char"

# dracula theme
source ~/.config/fish/conf.d/dracula.fish

# add path for gcloud
source "$(brew --prefix)/share/google-cloud-sdk/path.fish.inc"

set -x COLORTERM truecolor

# tmux
alias ts="tmux new -A -t $(pwd | path basename)"

