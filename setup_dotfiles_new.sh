git clone --bare https://github.com/TheFinest/dotfiles.git
git --git-dir=$HOME/dotfiles.git --work-tree=$HOME checkout master
git --git-dir=$HOME/dotfiles.git --work-tree=$HOME submodule update --init --recursive
git --git-dir=$HOME/dotfiles.git --work-tree=$HOME config status.showUntrackedFiles no
git --git-dir=$HOME/dotfiles.git --work-tree=$HOME config user.email "natobot1999@gmail.com"
git --git-dir=$HOME/dotfiles.git --work-tree=$HOME config user.name "TheFinest"
