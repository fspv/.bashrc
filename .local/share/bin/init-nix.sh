#!/usr/bin/env bash

set -uex

# Also change .config/nix/*.nix when changing the version
nix-channel --add https://nixos.org/channels/nixos-25.05 nixpkgs
nix-channel --update
