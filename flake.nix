# nix develop -i
{
  description = "Development shell with stable and unstable packages";

  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
    # jj with git-lfs support: https://github.com/jj-vcs/jj/pull/9068
    jj-with-lfs-support.url = "git+https://github.com/jj-vcs/jj?ref=refs/pull/9068/head";
    apps = {
      url = "path:./apps";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    zsh-autosuggestions = {
      url = "github:zsh-users/zsh-autosuggestions";
      flake = false;
    };
    zsh-syntax-highlighting = {
      url = "github:zsh-users/zsh-syntax-highlighting";
      flake = false;
    };
    powerlevel10k = {
      url = "github:romkatv/powerlevel10k";
      flake = false;
    };
    zsh-vi-mode = {
      url = "github:jeffreytse/zsh-vi-mode";
      flake = false;
    };
    forgit = {
      url = "github:wfxr/forgit";
      flake = false;
    };
    you-should-use = {
      url = "github:MichaelAquilina/zsh-you-should-use";
      flake = false;
    };
    fzf-tab = {
      url = "github:Aloxaf/fzf-tab";
      flake = false;
    };
    tmux-autoreload = {
      url = "github:b0o/tmux-autoreload";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs-stable,
      nixpkgs-unstable,
      rust-overlay,
      jj-with-lfs-support,
      apps,
      zsh-autosuggestions,
      zsh-syntax-highlighting,
      powerlevel10k,
      zsh-vi-mode,
      forgit,
      you-should-use,
      fzf-tab,
      tmux-autoreload,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs-stable.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          stablePkgs = import nixpkgs-stable {
            inherit system;
            config.allowUnfree = true;
            overlays = [ rust-overlay.overlays.default ];
          };

          unstablePkgs = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };

          rustToolchain = stablePkgs.rust-bin.stable.latest.default.override {
            extensions = [
              "rust-src"
              "rust-analyzer"
            ];
          };

          zshCustom = stablePkgs.linkFarm "oh-my-zsh-custom" {
            "plugins/zsh-autosuggestions" = zsh-autosuggestions;
            "plugins/zsh-syntax-highlighting" = zsh-syntax-highlighting;
            "themes/powerlevel10k" = powerlevel10k;
            "plugins/zsh-vi-mode" = zsh-vi-mode;
            "plugins/forgit" = forgit;
            "plugins/you-should-use" = you-should-use;
            "plugins/fzf-tab" = fzf-tab;
          };

          toInstallBasic = [
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
            stablePkgs.git
            stablePkgs.git-lfs
            stablePkgs.jq
            stablePkgs.jq.man
            stablePkgs.yq
            stablePkgs.ripgrep
            stablePkgs.oh-my-zsh
            stablePkgs.fzf
            stablePkgs.fzf.man
            stablePkgs.fzf-git-sh
            stablePkgs.docker-client
            stablePkgs.skopeo
            stablePkgs.skopeo.man
            stablePkgs.ponysay
            stablePkgs.openssl
            stablePkgs.openssl.dev
            stablePkgs.pkg-config
            stablePkgs.fortune
            stablePkgs.zip
            stablePkgs.unixtools.xxd
            stablePkgs.nixfmt-rfc-style
            stablePkgs.nixpkgs-fmt
            stablePkgs.nix-index
            stablePkgs.vim
            stablePkgs.unzip
            stablePkgs.libvirt
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
            stablePkgs.fping
            stablePkgs.whois
            stablePkgs.sqlite
            stablePkgs.eternal-terminal
            unstablePkgs.tmux
            unstablePkgs.tmux.man
            # Watcher used by tmux-autoreload
            stablePkgs.entr
            unstablePkgs.neovim
            unstablePkgs.vimPlugins.lazy-nvim
            unstablePkgs.atuin
          ];

          toInstallExtra = [
            stablePkgs.go
            stablePkgs.gotags
            stablePkgs.kubectl
            stablePkgs.kubectl.man
            stablePkgs.minikube
            stablePkgs.kubelogin-oidc
            stablePkgs.kubie
            stablePkgs.nodejs_22
            stablePkgs.yarn
            stablePkgs.gh
            stablePkgs.src-cli
            stablePkgs.lazygit
            stablePkgs.php83
            stablePkgs.lua
            stablePkgs.act
            stablePkgs.quick-lint-js
            stablePkgs.phpactor
            stablePkgs.php83Packages.php-cs-fixer
            stablePkgs.php83Packages.composer
            unstablePkgs.gopls
            unstablePkgs.pyright
            unstablePkgs.black
            unstablePkgs.isort
            unstablePkgs.phpunit
            stablePkgs.awscli2
            stablePkgs.mercurial
            stablePkgs.fontconfig
            stablePkgs.cairo
            stablePkgs.atk
            stablePkgs.gdk-pixbuf
            stablePkgs.pango
            stablePkgs.gtk3
            unstablePkgs.typescript-language-server
            unstablePkgs.vscode-langservers-extracted
            unstablePkgs.yaml-language-server
            unstablePkgs.bash-language-server
            unstablePkgs.lua-language-server
            unstablePkgs.stylua
            unstablePkgs.luajitPackages.luacheck
            unstablePkgs.tree-sitter
            unstablePkgs.efm-langserver
            unstablePkgs.k9s
            unstablePkgs.lspmux
            unstablePkgs.pnpm
            unstablePkgs.prometheus.cli
            unstablePkgs.pre-commit
            unstablePkgs.zoxide
            unstablePkgs.okta-aws-cli
            unstablePkgs.direnv
            unstablePkgs.nix-direnv
            rustToolchain
            stablePkgs.llvmPackages.libclang.lib
            unstablePkgs.jjui
            unstablePkgs.delta
            apps.packages.${system}.comment-lsp
            apps.packages.${system}.jjui-tools
            apps.packages.${system}.jj-tools
            apps.packages.${system}.jj-snapshot
            apps.packages.${system}.snapshot-store
            (jj-with-lfs-support.packages.${system}.default.overrideAttrs (_: {
              doCheck = false;
            }))
          ]
          ++ (builtins.filter
            (package: nixpkgs-stable.lib.meta.availableOn stablePkgs.stdenv.hostPlatform package)
            (
              [
                stablePkgs.bubblewrap
                stablePkgs.nsjail
                (unstablePkgs.claude-code.overrideAttrs (_: {
                  doInstallCheck = false;
                }))
              ]
              ++ nixpkgs-stable.lib.optional stablePkgs.stdenv.hostPlatform.isx86_64 stablePkgs.steam-run
            )
          );

          makeShell =
            packages:
            stablePkgs.mkShell {
              inherit packages;

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
                export ZSH_CUSTOM=${zshCustom}
                export GITSTATUS_DAEMON=${stablePkgs.gitstatus}/bin/gitstatusd
                export NEOVIM_LAZY_PATH=${unstablePkgs.vimPlugins.lazy-nvim}
                export TMUX_PLUGIN_SENSIBLE=${unstablePkgs.tmuxPlugins.sensible.rtp}
                export TMUX_PLUGIN_RESURRECT=${unstablePkgs.tmuxPlugins.resurrect.rtp}
                export TMUX_PLUGIN_SIDEBAR=${unstablePkgs.tmuxPlugins.sidebar.rtp}
                export TMUX_PLUGIN_AUTORELOAD=${tmux-autoreload}/tmux-autoreload.tmux
                export TMPPREFIX="$HOME/.cache/zsh"
                export EDITOR=nvim

                GIT_COMPLETION_DIR=${stablePkgs.git}/share/git/contrib/completion
                export GIT_COMPLETION_DIR

                mkdir -p $HOME/.config/github-copilot

                unset TERM
                export SHELL=${stablePkgs.zsh}/bin/zsh
                [[ $- == *i* ]] && exec ${stablePkgs.zsh}/bin/zsh
              '';
            };
        in
        {
          default = makeShell (toInstallBasic ++ toInstallExtra);
          basic = makeShell toInstallBasic;
        }
      );
    };
}
