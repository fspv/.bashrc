# shell.nix

let
  pkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-24.05.tar.gz") { };
  unstablePkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz") { };
in

pkgs.mkShell {
  buildInputs = [
    # Allow to go deeper
    pkgs.nix
    pkgs.nixd
    # Sandboxing
    pkgs.bubblewrap
    # Basic stuff
    pkgs.cacert
    pkgs.glibc
    pkgs.getent
    pkgs.sssd
    pkgs.ncurses
    pkgs.util-linux
    pkgs.nssTools
    pkgs.openssh
    pkgs.glib
    pkgs.less
    pkgs.nettools
    pkgs.hostname-debian
    pkgs.ps
    pkgs.glibcLocales
    pkgs.curl
    pkgs.wget
    # Other
    pkgs.python3
    pkgs.virtualenv
    pkgs.zsh
    pkgs.go
    pkgs.git
    pkgs.jq
    pkgs.ripgrep
    pkgs.oh-my-zsh
    pkgs.fzf
    pkgs.kubectl
    pkgs.minikube
    pkgs.docker-machine-kvm2
    pkgs.nodejs_22
    pkgs.ponysay
    pkgs.rustup
    pkgs.kubie
    pkgs.fortune
    pkgs.gh
    # Formatting for .nix files
    pkgs.nixfmt-rfc-style
    pkgs.nixpkgs-fmt
    unstablePkgs.neovim
  ];

  shellHook = ''
    # to make remote users work
    [ -f /usr/lib/x86_64-linux-gnu/libnss_sss.so.2 ] && export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libnss_sss.so.2
    bwrap --dev-bind / / \
        --ro-bind /nix /nix \
        --tmpfs /home/$(whoami)/.cache \
        --tmpfs /tmp \
        --share-net \
        --unshare-user \
        --unshare-ipc \
        --unshare-uts \
        --unshare-cgroup \
        -- zsh
  '';
}
