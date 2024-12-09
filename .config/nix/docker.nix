# nix-build ~/.config/nix/docker.nix && ./result | docker load && docker run --mount type=bind,source="$(pwd)",target=/build -it nix-shell-dev:latest
{
  pkgs ? import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-24.05.tar.gz") {},
}:
let
  shellDrv = import ./dev.nix { inherit pkgs; };
in
pkgs.dockerTools.streamNixShellImage {
  name = "nuhotetotniksvoboden/bashrc";
  tag = "latest";
  drv = shellDrv;
}
