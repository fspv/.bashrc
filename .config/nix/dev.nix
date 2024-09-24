# https://search.nixos.org/packages

let
  pkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-24.05.tar.gz") {
    # You can include overlays here https://nixos.wiki/wiki/Overlays
    overlays = [
      (self: super: {
      })
    ];
  };
  unstablePkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz") { };
  toInstall = [
    # Allow to go deeper
    pkgs.nix
    pkgs.nix.man
    pkgs.nixd
    # Sandboxing
    pkgs.bubblewrap
    # Basic stuff
    pkgs.coreutils-full
    pkgs.gnutar
    pkgs.gnutar.info
    pkgs.gzip
    pkgs.gzip.man
    pkgs.gnugrep
    pkgs.which
    pkgs.cacert
    pkgs.iputils
    pkgs.strace
    pkgs.ltrace
    pkgs.glibc
    pkgs.glibcLocales
    pkgs.getent
    pkgs.sssd
    pkgs.ncurses
    pkgs.ncurses.man
    pkgs.util-linux
    pkgs.util-linux.man
    pkgs.nssTools
    pkgs.openssh
    pkgs.glib
    pkgs.less
    pkgs.less.man
    pkgs.nettools
    pkgs.hostname-debian
    pkgs.ps
    pkgs.curl
    pkgs.curl.man
    pkgs.wget
    pkgs.htop
    pkgs.procps
    pkgs.cmake
    pkgs.gnumake
    pkgs.gnumake.man
    pkgs.less
    pkgs.less.man
    pkgs.more
    pkgs.man
    pkgs.linux-manual
    pkgs.man-pages
    pkgs.man-pages-posix
    # Other
    pkgs.bashInteractive
    pkgs.bashInteractive.man
    pkgs.bash-completion
    pkgs.bat
    pkgs.zsh
    pkgs.zsh.man
    pkgs.zsh-completions
    pkgs.go
    pkgs.gotags
    pkgs.git
    pkgs.jq
    pkgs.jq.man
    pkgs.yq
    pkgs.ripgrep
    pkgs.arduino
    pkgs.arduino-core
    pkgs.arduino-ide
    pkgs.arduino-cli
    pkgs.arduino-language-server
    pkgs.oh-my-zsh
    pkgs.fzf
    pkgs.fzf.man
    pkgs.fzf-zsh
    pkgs.fzf-git-sh
    pkgs.kubectl
    pkgs.kubectl.man
    pkgs.minikube
    pkgs.krew
    pkgs.kubie
    pkgs.docker-client
    pkgs.skopeo
    pkgs.skopeo.man
    pkgs.docker-machine-kvm2
    pkgs.podman
    pkgs.podman.man
    pkgs.nodejs_22
    pkgs.ponysay
    pkgs.rustup
    pkgs.kubie
    pkgs.fortune
    pkgs.gh
    pkgs.src-cli # sourcegraph
    # Formatting for .nix files
    pkgs.nixfmt-rfc-style
    pkgs.nixpkgs-fmt
    pkgs.vim
    pkgs.unzip
    pkgs.libvirt
    pkgs.lazygit
    pkgs.eza
    pkgs.eza.man
    pkgs.tmux
    pkgs.tmux.man
    pkgs.fd
    unstablePkgs.neovim
    unstablePkgs.vimPlugins.lazy-nvim
    unstablePkgs.gopls
    # unfree NIXPKGS_ALLOW_UNFREE=1
    pkgs.vagrant
  ];
  findPathInToInstallPackages = path:
    let
      packagesWithPath = builtins.filter (pkg: builtins.pathExists "${pkg}/${path}") toInstall;
    in
        builtins.concatStringsSep ":" (builtins.map (pkg: "${pkg}/${path}") packagesWithPath);
in

# https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-mkShell
pkgs.mkShell {
  packages = toInstall;

  shellHook = ''
    # glibc has no nss library included and tries to look at the default path instead
    export LD_LIBRARY_PATH=${pkgs.sssd}/lib
    export ZSH=${pkgs.oh-my-zsh}/share/oh-my-zsh
    export ZSH_PLUGIN_DIRS=${findPathInToInstallPackages "share/zsh/plugins"}
    export NEOVIM_LAZY_PATH=${unstablePkgs.vimPlugins.lazy-nvim}
    export FPATH_CUSTOM=${findPathInToInstallPackages "share/zsh/site-functions"}
    # This is to handle `pkgs.*.man` package outputs, which are not included by default
    export MANPATH=${findPathInToInstallPackages "share/man"}

    GIT_COMPLETION_DIR=${pkgs.git}/share/git/contrib/completion
    export GIT_COMPLETION_DIR

    BWRAPPED=1 bwrap \
        --die-with-parent \
        --unshare-ipc \
        --unshare-cgroup \
        --share-net \
        --bind $HOME $HOME \
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
        --tmpfs $HOME/.local \
        --tmpfs $HOME/.config \
        --tmpfs $HOME/.cache \
        --tmpfs $HOME/.ssh \
        --tmpfs /etc/ssh/ssh_config.d \
        --bind-try $HOME/.config/environment.d $HOME/.config/environment.d \
        --bind-try $HOME/.config/autostart $HOME/.config/autostart \
        --bind-try $HOME/.config/flake8 $HOME/.config/flake8 \
        --bind-try $HOME/.config/gtk-3.0 $HOME/.config/gtk-3.0 \
        --bind-try $HOME/.config/i3 $HOME/.config/i3 \
        --bind-try $HOME/.config/i3status $HOME/.config/i3status \
        --bind-try $HOME/.config/nix $HOME/.config/nix \
        --bind-try $HOME/.config/nvim $HOME/.config/nvim \
        --bind-try $HOME/.config/github-copilot $HOME/.config/github-copilot \
        --bind-try $HOME/.config/systemd $HOME/.config/systemd \
        --bind-try $HOME/.config/pulse $HOME/.config/pulse \
        --bind-try $HOME/.config/pycodestyle $HOME/.config/pycodestyle \
        --bind-try $HOME/.config/sway $HOME/.config/sway \
        --bind-try $HOME/.config/swaylock $HOME/.config/swaylock \
        --bind-try $HOME/.config/terminator $HOME/.config/terminator \
        --bind-try $HOME/.config/tmux $HOME/.config/tmux \
        --bind-try $HOME/.config/waybar $HOME/.config/waybar \
        --bind-try $HOME/.config/lazygit $HOME/.config/lazygit \
        --bind-try $HOME/.local/bin $HOME/.local/bin \
        --bind-try $HOME/.local/include $HOME/.local/include \
        --bind-try $HOME/.local/lib $HOME/.local/lib \
        --bind-try $HOME/.local/share/oh-my-zsh $HOME/.local/share/oh-my-zsh \
        --bind-try $HOME/.local/share/bin/wayland-user $HOME/.local/share/bin/wayland-user \
        --bind-try $HOME/.local/share/nvim $HOME/.local/share/nvim \
        --bind-try $HOME/.local/state/nvim $HOME/.local/state/nvim \
        -- zsh
    zsh
  '';
}
