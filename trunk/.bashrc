source $HOME/.bash_functions

export HSIM_HOME=$HOME/HSIM
export PATH=$HOME/.JS/bin:$HSIM_HOME/bin:$PATH
export LANG=C

alias ls='ls --color=auto'
alias l.='ls -d .*'
alias ll='ls -l'
alias h='history'
alias js='cd $HOME/.JS/bin'
alias vi='vim'

####################### reset PATH ###########################
_PATH=
IFS=:
for P in $PATH; do
    _EXIST=0
    for _P in $_PATH; do
        if [ "$P" = "$_P" ]; then
            _EXIST=1; break
        fi
    done
    if [ "$_EXIST" -ne 1 ]; then
        _PATH="$_PATH:$P"
    fi
done
unset IFS
export PATH="$_PATH"
