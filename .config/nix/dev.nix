# https://search.nixos.org/packages

{ pkgs ? import <nixpkgs> {} }:

let
  stablePkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-24.05.tar.gz") {
    # You can include overlays here https://nixos.wiki/wiki/Overlays
    overlays = [
      (self: super: {
      })
    ];
  };
  unstablePkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz") { };
  toInstall = [
    # Allow to go deeper
    stablePkgs.nix
    stablePkgs.nix.man
    stablePkgs.nixd
    # Sandboxing
    stablePkgs.bubblewrap
    # Basic stuff
    stablePkgs.coreutils-full
    stablePkgs.gnupg
    stablePkgs.gnutar
    stablePkgs.gnutar.info
    stablePkgs.gzip
    stablePkgs.gzip.man
    stablePkgs.gawk
    stablePkgs.gawk.man
    stablePkgs.gnugrep
    stablePkgs.which
    stablePkgs.cacert
    stablePkgs.iputils
    stablePkgs.strace
    stablePkgs.ltrace
    stablePkgs.glibc
    stablePkgs.glibcLocales
    stablePkgs.getent
    stablePkgs.sssd
    stablePkgs.ncurses
    stablePkgs.ncurses.man
    stablePkgs.util-linux
    stablePkgs.util-linux.man
    stablePkgs.nssTools
    stablePkgs.openssh
    stablePkgs.glib
    stablePkgs.less
    stablePkgs.less.man
    stablePkgs.nettools
    stablePkgs.hostname-debian
    stablePkgs.ps
    stablePkgs.curl
    stablePkgs.curl.man
    stablePkgs.wget
    stablePkgs.htop
    stablePkgs.procps
    stablePkgs.cmake
    stablePkgs.gnumake
    stablePkgs.gnumake.man
    stablePkgs.less
    stablePkgs.less.man
    stablePkgs.more
    stablePkgs.man
    stablePkgs.linux-manual
    stablePkgs.man-pages
    stablePkgs.man-pages-posix
    # Other
    stablePkgs.bashInteractive
    stablePkgs.bashInteractive.man
    stablePkgs.bash-completion
    stablePkgs.bat
    stablePkgs.pwgen
    stablePkgs.zsh
    stablePkgs.zsh.man
    stablePkgs.zsh-completions
    stablePkgs.go
    stablePkgs.gotags
    stablePkgs.git
    stablePkgs.jq
    stablePkgs.jq.man
    stablePkgs.yq
    stablePkgs.ripgrep
    stablePkgs.oh-my-zsh
    stablePkgs.fzf
    stablePkgs.fzf.man
    stablePkgs.fzf-zsh
    stablePkgs.fzf-git-sh
    stablePkgs.kubectl
    stablePkgs.kubectl.man
    stablePkgs.minikube
    stablePkgs.krew
    stablePkgs.kubie
    stablePkgs.docker-client
    stablePkgs.skopeo
    stablePkgs.skopeo.man
    stablePkgs.docker-machine-kvm2
    stablePkgs.podman
    stablePkgs.podman.man
    stablePkgs.nodejs_22
    stablePkgs.ponysay
    stablePkgs.rustup
    stablePkgs.kubie
    stablePkgs.fortune
    stablePkgs.gh
    stablePkgs.src-cli # sourcegraph
    # Formatting for .nix files
    stablePkgs.nixfmt-rfc-style
    stablePkgs.nixpkgs-fmt
    stablePkgs.vim
    stablePkgs.unzip
    stablePkgs.libvirt
    stablePkgs.lazygit
    stablePkgs.eza
    stablePkgs.eza.man
    unstablePkgs.tmux
    unstablePkgs.tmux.man
    stablePkgs.fd
    unstablePkgs.neovim
    unstablePkgs.vimPlugins.lazy-nvim
    unstablePkgs.gopls
    unstablePkgs.pyright
    unstablePkgs.black
    unstablePkgs.isort
    # unfree NIXPKGS_ALLOW_UNFREE=1
    # pkgs.vagrant
    # Other
    stablePkgs.arduino
    stablePkgs.arduino-core
    stablePkgs.arduino-cli
    stablePkgs.arduino-language-server
  ] ++ (
    if stablePkgs.stdenv.hostPlatform.system == "x86_64-linux" then [] else []
  );
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
    # For running in docker when rc files are not checked out by default
    [ -d $HOME/.git ] || (TMP=$(mktemp -d) && git clone https://github.com/fspv/.bashrc.git $TMP && cp -r $TMP/{*,.*} $HOME/ && rm -rf $TMP && $HOME/.local/share/bin/init-user-env.sh)

    # glibc has no nss library included and tries to look at the default path instead
    export LD_LIBRARY_PATH=${stablePkgs.sssd}/lib
    export ZSH=${stablePkgs.oh-my-zsh}/share/oh-my-zsh
    export ZSH_PLUGIN_DIRS=${findPathInToInstallPackages "share/zsh/plugins"}
    export NEOVIM_LAZY_PATH=${unstablePkgs.vimPlugins.lazy-nvim}
    export FPATH_CUSTOM=${findPathInToInstallPackages "share/zsh/site-functions"}
    # This is to handle `pkgs.*.man` package outputs, which are not included by default
    export MANPATH=${findPathInToInstallPackages "share/man"}

    GIT_COMPLETION_DIR=${stablePkgs.git}/share/git/contrib/completion
    export GIT_COMPLETION_DIR

    mkdir -p $HOME/.config/github-copilot

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
        --bind /opt /opt \
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
        --bind-try $HOME/.config/wezterm $HOME/.config/wezterm \
        --bind-try $HOME/.config/lazygit $HOME/.config/lazygit \
        --bind-try $HOME/.local/bin $HOME/.local/bin \
        --bind-try $HOME/.local/include $HOME/.local/include \
        --bind-try $HOME/.local/lib $HOME/.local/lib \
        --bind-try $HOME/.local/share/oh-my-zsh $HOME/.local/share/oh-my-zsh \
        --bind-try $HOME/.local/share/bin $HOME/.local/share/bin \
        --bind-try $HOME/.local/share/nvim $HOME/.local/share/nvim \
        --bind-try $HOME/.local/state/nvim $HOME/.local/state/nvim \
        --bind-try $HOME/.local/state/nix $HOME/.local/state/nix \
        -- zsh
    zsh
  '';
}
