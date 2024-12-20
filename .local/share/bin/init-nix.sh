#!/usr/bin/env bash

set -uex

# Also change .config/nix/*.nix when changing the version
nix-channel --add https://nixos.org/channels/nixos-24.11 nixpkgs
nix-channel --update
