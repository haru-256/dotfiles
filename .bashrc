alias ls='ls -G'
alias ll='ls -lG'
alias la='ls -laG'
#cp, mv, rm を-iオプション(上書きしていいかどうか)付きで再定義
alias mv='mv -i'
alias cp='cp -i'
# alias rm='rm -i'

# emacs をbrewで入れたものに通す
alias emacs=/Applications/Emacs.app/Contents/MacOS/Emacs
# alias vim=/Applications/Emacs.app/Contents/MacOS/Emacs

#
# ターミナルでsolarizedのディレクトリ配色にする
eval $(gdircolors ~/git-related/dircolors-solarized/dircolors.ansi-dark)

# brewに関する/.pyenvのエラーのための対処
alias brew="env PATH=${PATH/\/Users\/yohei\/\.pyenv\/shims:/} brew"

# Homebrew Completions
BREW_SCRIPTS="$(brew --prefix)/etc/bash_completion.d"
if [ -d "$BREW_SCRIPTS" ]; then for script in $(find $BREW_SCRIPTS -type l) ; do . $script ; done fi
if [ -f "$BREW_SCRIPTS/git-prompt.sh" ]; then PS1='[\u@\h \W$(__git_ps1 " (%s)")]\$ '; fi

# java
alias java_home=/System/Library/Frameworks/JavaVM.framework/Versions/A/Commands/java_home
alias java8='JAVA_HOME=`java_home -v "1.8"` java'
alias javac8='JAVA_HOME=`java_home -v "1.8"` javac'

