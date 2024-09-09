# https://search.nixos.org/packages

let
  pkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-24.05.tar.gz") {
    # You can include overlays here https://nixos.wiki/wiki/Overlays
  };
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
    pkgs.which
    pkgs.cacert
    pkgs.iputils
    pkgs.strace
    pkgs.ltrace
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
    pkgs.htop
    pkgs.procps
    # Other
    pkgs.bashInteractive
    pkgs.bat
    pkgs.zsh
    pkgs.go
    pkgs.gotags
    pkgs.git
    pkgs.jq
    pkgs.yq
    pkgs.ripgrep
    pkgs.arduino
    pkgs.arduino-core
    pkgs.arduino-ide
    pkgs.arduino-cli
    pkgs.arduino-language-server
    pkgs.oh-my-zsh
    pkgs.fzf
    pkgs.fzf-zsh
    pkgs.fzf-git-sh
    pkgs.kubectl
    pkgs.minikube
    pkgs.krew
    pkgs.kubie
    pkgs.docker
    pkgs.skopeo
    pkgs.docker-machine-kvm2
    pkgs.podman
    pkgs.nodejs_22
    pkgs.ponysay
    pkgs.rustup
    pkgs.kubie
    pkgs.fortune
    pkgs.gh
    pkgs.src-cli # sourcegraph
    # pkgs.vagrant # unfree and not installable
    # Formatting for .nix files
    pkgs.nixfmt-rfc-style
    pkgs.nixpkgs-fmt
    pkgs.vim
    pkgs.unzip
    pkgs.strace
    pkgs.ltrace
    pkgs.libvirt
    unstablePkgs.neovim
    unstablePkgs.gopls
  ];

  shellHook = ''
    # FIXME: have no idea, why it doesn't work without it.
    # ModuleNotFoundError: No module named '_sysconfigdata__linux_x86_64-linux-gnu'
    export _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_
    # glibc has no nss library included and tries to look at the default path instead
    export LD_LIBRARY_PATH="${pkgs.sssd}/lib"
    export ZSH="${pkgs.oh-my-zsh}/share/oh-my-zsh"
    export ZSH_PLUGIN_DIRS="${pkgs.fzf-zsh}/share/zsh/plugins"

    # TODO: automatically source zsh plugins
    # TODO: automatically source MANPATH
    # TODO: automatically source bash and zsh completions

    bwrap --dev-bind / / \
        --ro-bind /nix /nix \
        --tmpfs /tmp \
        --tmpfs /home/$(whoami)/.cache \
        --tmpfs /etc/ssh/ssh_config.d \
        --share-net \
        -- zsh
    zsh
  '';
}
