# nix-build ~/.config/nix/docker.nix && ./result | docker load && docker run --mount type=bind,source="$(pwd)",target=/build -it nix-shell-dev:latest
{
  pkgs ? import <nixpkgs> {},
}:
let
  shellDrv = import ./dev.nix { inherit pkgs; };
in
pkgs.dockerTools.streamNixShellImage {
  name = "nuhotetotniksvoboden/bashrc";
  tag = "latest";
  drv = shellDrv.overrideAttrs (old: {
    nativeBuildInputs = old.nativeBuildInputs or [] ++ [
      # Just an example of how to add a package
      pkgs.sudo
    ];
  });
}
