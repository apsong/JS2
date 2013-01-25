JS2
===

.bashrc .bash_functions .vimrc .JS .HSIM

<Usage>
A: Initial upload:
==================
/github> git clone git@github.com:apsong/JS2
/github> cd JS2
/github/JS2> git config --global user.name "Samson Jin"
/github/JS2> git config --global user.email apsong@gmail.com
$ cat ~/.gitconfig
[user]
        name = Samson Jin
        email = apsong@gmail.com
/github/JS2> git add init_clone.sh trunk/
/github/JS2> git commit -a -m "1"
/github/JS2> git push

B: Download & Modify & Upload:
==============================
/github2> git clone git@github.com:apsong/JS2
/github2> cd JS2
/github/JS2> edit init_clone.sh
/github/JS2> git commit -a -m "3"
/github/JS2> git push

A: Update to lastest version:
=============================
/github/JS2> git fetch
/github/JS2> git reset --hard
/github/JS2> git rebase

C: Undo last commit before push
===============================
/github/JS2> git commit -a -m "add .minttyrc to set color Blue & DarkBlue"  #commit with wrong comment
/github/JS2> git reset --soft HEAD^                                                                    #undo last commit
/github/JS2> git add .JS/bin/colortable16.sh                                                      #add new file to commit together
/github/JS2> git commit -m "add .minttyrc to set color Blue & BoldBlue"       #commit again
