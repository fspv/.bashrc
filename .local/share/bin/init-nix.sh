#!/usr/bin/env bash

set -uex

nix-channel --add https://nixos.org/channels/nixos-26.05 nixpkgs
nix-channel --update
