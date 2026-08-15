#!/usr/bin/env bash

set -uex

if [[ "$(uname)" == "Darwin" ]]; then
    nix-channel --add https://nixos.org/channels/nixpkgs-26.05-darwin nixpkgs
else
    nix-channel --add https://nixos.org/channels/nixos-26.05 nixpkgs
fi

nix-channel --update
