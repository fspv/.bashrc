# https://search.nixos.org/packages

{ pkgs ? import <nixpkgs> {} }:

let
  # Also change ~/.local/share/bin/init-nix.sh
  stablePkgs = import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-25.05.tar.gz") {
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
    stablePkgs.hostname-debian
    stablePkgs.nettools
    stablePkgs.ps
    stablePkgs.curl
    stablePkgs.curl.man
    stablePkgs.wget
    stablePkgs.htop
    stablePkgs.procps
    stablePkgs.cmake
    stablePkgs.gnumake
    stablePkgs.gnumake.man
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
    stablePkgs.nodejs_22
    stablePkgs.yarn
    stablePkgs.ponysay
    stablePkgs.rustc
    stablePkgs.cargo
    stablePkgs.rust-analyzer
    stablePkgs.clippy
    stablePkgs.rustfmt
    stablePkgs.kubie
    stablePkgs.fortune
    stablePkgs.gh
    stablePkgs.src-cli # sourcegraph
    stablePkgs.attr
    # Formatting for .nix files
    stablePkgs.nixfmt-rfc-style
    stablePkgs.nixpkgs-fmt
    stablePkgs.vim
    stablePkgs.unzip
    stablePkgs.libvirt
    stablePkgs.lazygit
    stablePkgs.eza
    stablePkgs.eza.man
    stablePkgs.fd
    stablePkgs.mc
    stablePkgs.tcpdump
    stablePkgs.iotop
    stablePkgs.ngrep
    stablePkgs.lsscsi
    stablePkgs.lsof
    stablePkgs.vnstat
    stablePkgs.parted
    stablePkgs.parted.man
    stablePkgs.gptfdisk
    stablePkgs.tree
    stablePkgs.inetutils
    stablePkgs.inotify-tools
    stablePkgs.rlwrap
    stablePkgs.dmidecode
    stablePkgs.iftop
    stablePkgs.dnsutils
    stablePkgs.dnsutils.man
    stablePkgs.atop
    stablePkgs.nasm
    stablePkgs.mercurial
    stablePkgs.fping
    stablePkgs.multipath-tools
    stablePkgs.powertop
    stablePkgs.powertop.man
    stablePkgs.testdisk
    stablePkgs.ebtables
    stablePkgs.nmap
    stablePkgs.mtr
    stablePkgs.whois
    stablePkgs.pciutils
    stablePkgs.sysstat
    stablePkgs.lm_sensors
    stablePkgs.php83
    unstablePkgs.phpunit
    stablePkgs.phpactor
    stablePkgs.php83Packages.php-cs-fixer
    stablePkgs.php83Packages.composer
    unstablePkgs.tmux
    unstablePkgs.tmux.man
    unstablePkgs.neovim
    unstablePkgs.vimPlugins.lazy-nvim
    unstablePkgs.gopls
    unstablePkgs.pyright
    unstablePkgs.black
    unstablePkgs.isort
    unstablePkgs.typescript-language-server
    unstablePkgs.vscode-langservers-extracted
    unstablePkgs.yaml-language-server
    unstablePkgs.claude-code
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
    export USR_LIB_LOCALES_PATH=${stablePkgs.glibcLocales}/lib/locale

    source ${stablePkgs.glibcLocales}/nix-support/setup-hook

    GIT_COMPLETION_DIR=${stablePkgs.git}/share/git/contrib/completion
    export GIT_COMPLETION_DIR

    mkdir -p $HOME/.config/github-copilot

    source $HOME/.bashrc
  '';
}
