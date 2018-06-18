
# ログイン時に.bashrcを読み込む
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# sshのためにロケールを設定
export LANG=ja_JP.UTF-8

# カラー設定
# export LSCOLORS=gxfxcxdxbxegedabagacad

# brewのgitを使うように設定  いらない?
# export PATH="/usr/local/Cellar/git/2.5.0/bin:$PATH"

# プロキシサーバ: http://cache.st.ryukoku.ac.jp:8080/
# ネットワーク設定名: 龍谷
proxy_name=http://cache.st.ryukoku.ac.jp:8080
switch_triggers=("ilab" "tlab")
for switch_trigger in ${switch_triggers[@]}; do
    if [ "`networksetup -getcurrentlocation`" = "$switch_trigger" ]; then
	export http_proxy=$proxy_name
	export https_proxy=$proxy_name
	export all_proxy=$proxy_name
        export no_proxy="127.0.0.1,localhost,133.83.*,192.168.*,192.168.1.1"
    fi
done

# pstoeditの環境変数
# :export PATH=/usr/local/bin/pstoedit:$PATH

#git をbrewで入れたものを通す
#export PATH='/usr/local/Cellar/git/2.14.3/bash'

export PYENV_ROOT="${HOME}/.pyenv"
if [ -d "${PYENV_ROOT}" ]; then
    export PATH=${PYENV_ROOT}/bin:$PATH
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi
#export PYENV_VIRTUALENV_DISABLE_PROMPT=1

# lessをutf-8対応に
# export LESSCHARSET=utf-8
# . /Users/yohei/.pyenv/versions/miniconda3-latest/etc/profile.d/conda.sh
# conda activate

export PATH="/usr/local/opt/sphinx-doc/bin:$PATH"
# ftpなどのコマンドが prefix 'g' なので通常の名前でアクセスできる様にするため. brew より
export PATH="/usr/local/opt/inetutils/libexec/gnubin:$PATH"
# 上と同様にmanも通常の名前でアクセスさせるため
export MANPATH="/usr/local/opt/inetutils/libexec/gnuman:$MANPATH"
# sqlite
export PATH="/usr/local/opt/sqlite/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/sqlite/lib:$LDFLAGS"
export CPPFLAGS="-I/usr/local/opt/sqlite/include:$CPPFLAGS"
export PKG_CONFIG_PATH="/usr/local/opt/sqlite/lib/pkgconfig:$PKG_CONFIG_PATH"
