#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
