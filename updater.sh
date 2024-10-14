eval $"rm -rf ./nvim ./kitty ./.bashrc"
eval $"cp ~/.config/nvim/ ~/repo/dotfiles/ -r"
eval $"cp ~/.config/kitty/ ~/repo/dotfiles/ -r"
eval $"cp ~/.bashrc ~/repo/dotfiles/ -r"

eval $"git diff"
