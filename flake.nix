# nix develop --ignore-environment --keep HOME
{
  description = "Development shell with stable and unstable packages";

  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs-stable, nixpkgs-unstable }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs-stable.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (system:
        let
          stablePkgs = import nixpkgs-stable {
              inherit system;
              config.allowUnfree = true;
          };

          unstablePkgs = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };

          toInstall = [
            # Allow to go deeper
            stablePkgs.nix
            stablePkgs.nix.man
            stablePkgs.nixd
            # Basic stuff
            stablePkgs.coreutils-full
            stablePkgs.gnupg
            stablePkgs.gnutar
            stablePkgs.locale
            stablePkgs.gnutar.info
            stablePkgs.gzip
            stablePkgs.gzip.man
            stablePkgs.gawk
            stablePkgs.gawk.man
            stablePkgs.gnugrep
            stablePkgs.which
            stablePkgs.cacert
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
            stablePkgs.netcat
            stablePkgs.netcat.man
            stablePkgs.ps
            stablePkgs.e2fsprogs
            stablePkgs.e2fsprogs.man
            stablePkgs.curl
            stablePkgs.curl.man
            stablePkgs.wget
            stablePkgs.htop
            stablePkgs.procps
            stablePkgs.automake
            stablePkgs.cmake
            stablePkgs.gnumake
            stablePkgs.gnumake.man
            stablePkgs.more
            stablePkgs.nano
            stablePkgs.man
            stablePkgs.libgcc
            stablePkgs.parallel
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
            stablePkgs.git-lfs
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
            stablePkgs.nodejs_22
            stablePkgs.yarn
            stablePkgs.ponysay
            stablePkgs.openssl
            stablePkgs.openssl.dev
            stablePkgs.pkg-config
            stablePkgs.fortune
            stablePkgs.gh
            stablePkgs.src-cli
            stablePkgs.zip
            stablePkgs.unixtools.xxd
            stablePkgs.nixfmt-rfc-style
            stablePkgs.nixpkgs-fmt
            stablePkgs.nix-index
            stablePkgs.vim
            stablePkgs.unzip
            stablePkgs.libvirt
            stablePkgs.lazygit
            stablePkgs.git
            stablePkgs.eza
            stablePkgs.eza.man
            stablePkgs.fd
            stablePkgs.mc
            stablePkgs.tcpdump
            stablePkgs.tree
            stablePkgs.rlwrap
            stablePkgs.dnsutils
            stablePkgs.dnsutils.man
            stablePkgs.nasm
            stablePkgs.mercurial
            stablePkgs.fping
            stablePkgs.whois
            stablePkgs.php83
            stablePkgs.sqlite
            stablePkgs.lua
            stablePkgs.quick-lint-js
            stablePkgs.rustc
            stablePkgs.cargo
            stablePkgs.clippy
            stablePkgs.rustfmt
            stablePkgs.rust-analyzer
            stablePkgs.llvmPackages.libclang.lib
            # stablePkgs.tpm2-tss
            stablePkgs.fontconfig
            stablePkgs.cairo
            stablePkgs.atk
            stablePkgs.gdk-pixbuf
            stablePkgs.pango
            stablePkgs.gtk3
            # stablePkgs.libsoup_3
            # stablePkgs.libjpeg
            # stablePkgs.libnl
            # stablePkgs.libva
            unstablePkgs.phpunit
            stablePkgs.phpactor
            stablePkgs.php83Packages.php-cs-fixer
            stablePkgs.php83Packages.composer
            stablePkgs.atuin
            stablePkgs.eternal-terminal
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
            unstablePkgs.bash-language-server
            unstablePkgs.lua-language-server
            unstablePkgs.stylua
            unstablePkgs.luajitPackages.luacheck
            unstablePkgs.tree-sitter
            unstablePkgs.efm-langserver
            unstablePkgs.atuin
            unstablePkgs.k9s
            unstablePkgs.lspmux
            unstablePkgs.pnpm
            unstablePkgs.prometheus.cli
            unstablePkgs.claude-code
            unstablePkgs.pre-commit
            unstablePkgs.zoxide
            unstablePkgs.graphite-cli
            unstablePkgs.okta-aws-cli
          ] ++ (nixpkgs-stable.lib.optionals (system == "x86_64-linux") [
            unstablePkgs.claude-code
            stablePkgs.steam-run
          ]);
        in
        {
          default = stablePkgs.mkShell {
            packages = toInstall;

            LIBCLANG_PATH = "${stablePkgs.llvmPackages.libclang.lib}/lib";

            NIX_ENFORCE_PURITY = "";

            # Disable Nix hardening flags (fortify, format, etc.) that break
            # autoconf-based C builds like jemalloc (strerror_r detection)
            # and format attribute checks. Not needed for a dev shell.
            hardeningDisable = [ "all" ];

            shellHook = ''
              # For running in docker when rc files are not checked out by default
              [ -d $HOME/.git ] || (TMP=$(mktemp -d) && git clone https://github.com/fspv/.bashrc.git $TMP && cp -r $TMP/{*,.*} $HOME/ && rm -rf $TMP && $HOME/.local/share/bin/init-user-env.sh)

              export ZSH=${stablePkgs.oh-my-zsh}/share/oh-my-zsh
              export NEOVIM_LAZY_PATH=${unstablePkgs.vimPlugins.lazy-nvim}
              export TMPPREFIX="$HOME/.cache/zsh"

              GIT_COMPLETION_DIR=${stablePkgs.git}/share/git/contrib/completion
              export GIT_COMPLETION_DIR

              mkdir -p $HOME/.config/github-copilot

              unset TERM
              export SHELL=${stablePkgs.zsh}/bin/zsh
              [[ $- == *i* ]] && exec ${stablePkgs.zsh}/bin/zsh
            '';
          };
        }
      );
    };
}
