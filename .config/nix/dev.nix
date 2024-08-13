# shell.nix

let
  pkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-24.05.tar.gz") {};
  unstablePkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz") {};
in

pkgs.mkShell {
  buildInputs = [
    pkgs.zsh
    pkgs.glibc
    pkgs.getent
    pkgs.sssd
    pkgs.util-linux
    pkgs.go
    pkgs.git
    pkgs.jq
    pkgs.ripgrep
    pkgs.oh-my-zsh
    pkgs.fzf
    pkgs.ncurses
    pkgs.nssTools
    pkgs.openssh
    pkgs.glib
    pkgs.less
    pkgs.nettools
    pkgs.kubectl
    pkgs.minikube
    pkgs.hostname-debian
    pkgs.docker-machine-kvm2
    pkgs.glibcLocales
    pkgs.ps
    pkgs.bubblewrap
    pkgs.curl
    pkgs.wget
    pkgs.cacert
    unstablePkgs.neovim
  ];

  shellHook = ''
    # to make remote users work
    export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libnss_sss.so.2
    bwrap --dev-bind / / --ro-bind /nix /nix --tmpfs /home/$(whoami)/.cache --tmpfs /tmp --share-net --unshare-user --unshare-ipc --unshare-uts --unshare-cgroup -- zsh
  '';
}
