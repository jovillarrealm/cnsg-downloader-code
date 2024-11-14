#!/bin/bash

# This is for conveniently installing rust and some common tooling
echo "ignore errors about env.fish or things that are not fish if you use fish...      yeah"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
. "$HOME/.cargo/env"
source "$HOME/.cargo/env.fish"

cargo install --locked zellij
cargo install fd-find
cargo install du-dust
cargo install ripgrep
cargo install --locked yazi-fm yazi-cli

curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/snap/code/174/.local/share/../bin/env
source $HOME/snap/code/174/.local/share/../bin/env.fish
