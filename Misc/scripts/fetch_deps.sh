#!/bin/zsh

dep_util="$(cd "$(dirname "${(%):-%N}")" && pwd)/fetch_pkg.sh"

"$dep_util" "common"
