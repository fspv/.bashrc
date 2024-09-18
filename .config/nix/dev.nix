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
    pkgs.cmake
    pkgs.gnumake
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
    pkgs.lazygit
    unstablePkgs.neovim
    unstablePkgs.vimPlugins.lazy-nvim
    unstablePkgs.gopls
  ];

  shellHook = ''
    # FIXME: have no idea, why it doesn't work without it.
    # ModuleNotFoundError: No module named '_sysconfigdata__linux_x86_64-linux-gnu'
    export _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_
    # glibc has no nss library included and tries to look at the default path instead
    export LD_LIBRARY_PATH=${pkgs.sssd}/lib
    export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh
    export ZSH_PLUGIN_DIRS=${pkgs.fzf-zsh}/share/zsh/plugins
    export NEOVIM_LAZY_PATH=${unstablePkgs.vimPlugins.lazy-nvim}

    # TODO: automatically source zsh plugins
    # TODO: automatically source MANPATH
    # TODO: automatically source bash and zsh completions

    BWRAPPED=1 bwrap \
        --die-with-parent \
        --unshare-ipc \
        --unshare-cgroup \
        --share-net \
        --bind /home/$(whoami) /home/$(whoami) \
        --ro-bind /bin /bin \
        --ro-bind /sbin /sbin \
        --ro-bind /lib /lib \
        --ro-bind /lib64 /lib64 \
        --ro-bind /usr /usr \
        --ro-bind /opt /opt \
        --ro-bind /snap /snap \
        --ro-bind /var /var \
        --ro-bind /nix /nix \
        --ro-bind /etc /etc \
        --dev /dev \
        --proc /proc \
        --tmpfs /tmp \
        --tmpfs /run/user/$(id -u) \
        --tmpfs /home/$(whoami)/.local \
        --tmpfs /home/$(whoami)/.config \
        --tmpfs /home/$(whoami)/.cache \
        --tmpfs /home/$(whoami)/.ssh \
        --tmpfs /etc/ssh/ssh_config.d \
        --bind-try /home/$(whoami)/.config/environment.d /home/$(whoami)/.config/environment.d \
        --bind-try /home/$(whoami)/.config/autostart /home/$(whoami)/.config/autostart \
        --bind-try /home/$(whoami)/.config/flake8 /home/$(whoami)/.config/flake8 \
        --bind-try /home/$(whoami)/.config/gtk-3.0 /home/$(whoami)/.config/gtk-3.0 \
        --bind-try /home/$(whoami)/.config/i3 /home/$(whoami)/.config/i3 \
        --bind-try /home/$(whoami)/.config/i3status /home/$(whoami)/.config/i3status \
        --bind-try /home/$(whoami)/.config/nix /home/$(whoami)/.config/nix \
        --bind-try /home/$(whoami)/.config/nvim /home/$(whoami)/.config/nvim \
        --bind-try /home/$(whoami)/.config/systemd /home/$(whoami)/.config/systemd \
        --bind-try /home/$(whoami)/.config/pulse /home/$(whoami)/.config/pulse \
        --bind-try /home/$(whoami)/.config/pycodestyle /home/$(whoami)/.config/pycodestyle \
        --bind-try /home/$(whoami)/.config/sway /home/$(whoami)/.config/sway \
        --bind-try /home/$(whoami)/.config/swaylock /home/$(whoami)/.config/swaylock \
        --bind-try /home/$(whoami)/.config/terminator /home/$(whoami)/.config/terminator \
        --bind-try /home/$(whoami)/.config/tmux /home/$(whoami)/.config/tmux \
        --bind-try /home/$(whoami)/.config/waybar /home/$(whoami)/.config/waybar \
        --bind-try /home/$(whoami)/.config/lazygit /home/$(whoami)/.config/lazygit \
        --bind-try /home/$(whoami)/.local/bin /home/$(whoami)/.local/bin \
        --bind-try /home/$(whoami)/.local/include /home/$(whoami)/.local/include \
        --bind-try /home/$(whoami)/.local/lib /home/$(whoami)/.local/lib \
        --bind-try /home/$(whoami)/.local/share/oh-my-zsh /home/$(whoami)/.local/share/oh-my-zsh \
        --bind-try /home/$(whoami)/.local/share/bin/wayland-user /home/$(whoami)/.local/share/bin/wayland-user \
        --bind-try /home/$(whoami)/.local/share/nvim /home/$(whoami)/.local/share/nvim \
        --bind-try /home/$(whoami)/.local/state/nvim /home/$(whoami)/.local/state/nvim \
        -- zsh
    zsh
  '';
}
