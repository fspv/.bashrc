# nix develop -i
# `flake.lock` is intentionally empty in git to avoid dealing with merge
# conflicts on multiple machines. It does cause problems though, because you
# need to remember to not accidentally commit it and also it leads to a
# guaranteed update on a new machine. It is a source of known problems in CI
# such as world rebuild when the package is not cached in Hydra. Happens often
# for MacOS build and there is no good solution yet.
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
    please-nvim = {
      url = "github:marcuscaisey/please.nvim";
      flake = false;
    };
    vim-quickui = {
      url = "github:skywind3000/vim-quickui";
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
      please-nvim,
      vim-quickui,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs-stable.lib.genAttrs supportedSystems;

      nvimLuaLibsFor =
        unstablePkgs:
        unstablePkgs.linkFarm "nvim-lua-libs" {
          nvim-runtime = "${unstablePkgs.neovim-unwrapped}/share/nvim/runtime/lua";
          telescope-nvim = "${unstablePkgs.vimPlugins.telescope-nvim}/lua";
          plenary-nvim = "${unstablePkgs.vimPlugins.plenary-nvim}/lua";
          sqlite-lua = "${unstablePkgs.vimPlugins.sqlite-lua}/lua";
        };

      nvimPluginsFor =
        unstablePkgs:
        unstablePkgs.linkFarm "nvim-plugins" {
          "gruvbox.nvim" = unstablePkgs.vimPlugins.gruvbox-nvim;
          "nvim-treesitter-textobjects" = unstablePkgs.vimPlugins.nvim-treesitter-textobjects;
          "friendly-snippets" = unstablePkgs.vimPlugins.friendly-snippets;
          "blink.cmp" = unstablePkgs.vimPlugins.blink-cmp;
          "nvim-lspconfig" = unstablePkgs.vimPlugins.nvim-lspconfig;
          "conform.nvim" = unstablePkgs.vimPlugins.conform-nvim;
          "flash.nvim" = unstablePkgs.vimPlugins.flash-nvim;
          "ctrlp.vim" = unstablePkgs.vimPlugins.ctrlp-vim;
          "vim-fugitive" = unstablePkgs.vimPlugins.vim-fugitive;
          "gitsigns.nvim" = unstablePkgs.vimPlugins.gitsigns-nvim;
          "diffview-plus.nvim" = unstablePkgs.vimPlugins.diffview-plus-nvim;
          "neogit" = unstablePkgs.vimPlugins.neogit;
          "neo-tree.nvim" = unstablePkgs.vimPlugins.neo-tree-nvim;
          "nui.nvim" = unstablePkgs.vimPlugins.nui-nvim;
          "go.nvim" = unstablePkgs.vimPlugins.go-nvim;
          "guihua.lua" = unstablePkgs.vimPlugins.guihua-lua;
          "rustaceanvim" = unstablePkgs.vimPlugins.rustaceanvim;
          "plenary.nvim" = unstablePkgs.vimPlugins.plenary-nvim;
          "nvim-dap" = unstablePkgs.vimPlugins.nvim-dap;
          "bufferline.nvim" = unstablePkgs.vimPlugins.bufferline-nvim;
          "lualine.nvim" = unstablePkgs.vimPlugins.lualine-nvim;
          "statuscol.nvim" = unstablePkgs.vimPlugins.statuscol-nvim;
          "dropbar.nvim" = unstablePkgs.vimPlugins.dropbar-nvim;
          "telescope.nvim" = unstablePkgs.vimPlugins.telescope-nvim;
          "telescope-fzf-native.nvim" = unstablePkgs.vimPlugins.telescope-fzf-native-nvim;
          "telescope-live-grep-args.nvim" = unstablePkgs.vimPlugins.telescope-live-grep-args-nvim;
          "rainbow-delimiters.nvim" = unstablePkgs.vimPlugins.rainbow-delimiters-nvim;
          "indent-blankline.nvim" = unstablePkgs.vimPlugins.indent-blankline-nvim;
          "vim-matchup" = unstablePkgs.vimPlugins.vim-matchup;
          "trouble.nvim" = unstablePkgs.vimPlugins.trouble-nvim;
          "which-key.nvim" = unstablePkgs.vimPlugins.which-key-nvim;
          "treesj" = unstablePkgs.vimPlugins.treesj;
          "auto-session" = unstablePkgs.vimPlugins.auto-session;
          "sqlite.lua" = unstablePkgs.vimPlugins.sqlite-lua;
          "please.nvim" = please-nvim;
          "vim-quickui" = vim-quickui;
        };

      # Each grammar's own queries, so parser and queries revisions match.
      nvimTreesitterFor =
        unstablePkgs:
        let
          inherit (nixpkgs-stable) lib;

          duplicateGrammars = [
            "tree-sitter-go-template" # same rev as tree-sitter-gotmpl
            "tree-sitter-org-nvim" # same rev as tree-sitter-org
          ];

          # ~56 MiB of the ~227 MiB of all parsers.
          oversizedGrammars = [
            "tree-sitter-fsharp"
            "tree-sitter-lean"
            "tree-sitter-razor"
            "tree-sitter-verilog"
          ];

          # The language id is the `tree_sitter_<id>` symbol the parser exports.
          languageIdOverrides = {
            "tree-sitter-go-template-helm" = "helm";
            "tree-sitter-sshclientconfig" = "ssh_client_config";
          };

          # Defaults to the repo's first grammar, which is another copy of php.
          grammarOverrides = {
            "tree-sitter-php-only" = unstablePkgs.tree-sitter-grammars.tree-sitter-php-only.override {
              language = "php_only";
            };
          };

          nestedQueryDirs = {
            cpon = "vim";
            ghostty = "ghostty";
            glimmer = "glimmer";
            graphql = "graphql";
            hyprlang = "hyprlang";
            just = "just";
            mail = "mail";
            matlab = "neovim";
            nu = "nu";
            query = "query";
            snakemake = "snakemake";
            tcl = "tcl";
            templ = "templ";
            typst = "typst";
            vhdl = "Neovim";
            vim = "vim";
            vue = "vue";
            werk = "werk";
          };

          languagesWithUncompilableQueries = [
            "hurl"
            "mojo"
            "scss"
            "supercollider"
          ];

          languagesWithoutQueries = [
            "amber"
            "beancount"
            "comment"
            "commonlisp" # only tags.scm, which neovim does not use
            "csv"
            "dbml"
            "dtd"
            "edoc"
            "fennel"
            "gdscript"
            "gitignore"
            "gn"
            "godot_resource"
            "haskell_persistent"
            "hcl"
            "helm"
            "hosts"
            "jq"
            "latex"
            "ledger"
            "lpf"
            "luau"
            "norg"
            "ocaml"
            "ocaml_interface"
            "org"
            "passwd"
            "perl"
            "php"
            "php_only"
            "phpdoc"
            "pioasm"
            "ql_dbscheme"
            "rst"
            "rust_format_args"
            "slang"
            "slint"
            "spade"
            "sparql"
            "surface"
            "talon"
            "task"
            "tsq"
            "tsx"
            "turtle"
            "typescript"
            "wast"
            "wat"
            "wren"
            "xit"
            "xml"
          ];

          languagesWithoutUsableQueries = languagesWithoutQueries ++ languagesWithUncompilableQueries;

          languageIdFor =
            name: languageIdOverrides.${name} or (lib.replaceStrings [ "tree-sitter-" "-" ] [ "" "_" ] name);

          queryPathFor =
            language: grammar:
            if nestedQueryDirs ? ${language} then
              "${grammar}/queries/${nestedQueryDirs.${language}}"
            else
              "${grammar}/queries";

          grammars = lib.filterAttrs (
            name: grammar:
            !lib.elem name (duplicateGrammars ++ oversizedGrammars)
            && lib.meta.availableOn unstablePkgs.stdenv.hostPlatform grammar
          ) (unstablePkgs.tree-sitter-grammars.derivations // grammarOverrides);
        in
        unstablePkgs.linkFarm "nvim-treesitter-parsers" (
          {
            # Sourced explicitly by treesitter_conf.lua, so not under plugin/.
            "filetypes.lua" = "${unstablePkgs.vimPlugins.nvim-treesitter}/plugin/filetypes.lua";
          }
          // lib.concatMapAttrs (
            name: grammar:
            let
              language = languageIdFor name;
            in
            {
              "parser/${language}.so" = "${grammar}/parser";
            }
            // lib.optionalAttrs (!lib.elem language languagesWithoutUsableQueries) {
              "queries/${language}" = queryPathFor language grammar;
            }
          ) grammars
        );
    in
    {
      formatter = forAllSystems (system: (import nixpkgs-unstable { inherit system; }).nixfmt-tree);

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

          nvimLuaLibs = nvimLuaLibsFor unstablePkgs;
          nvimPlugins = nvimPluginsFor unstablePkgs;
          nvimTreesitter = nvimTreesitterFor unstablePkgs;

          tmuxPluginsDir = stablePkgs.linkFarm "tmux-plugins" {
            sensible = builtins.dirOf unstablePkgs.tmuxPlugins.sensible.rtp;
            resurrect = builtins.dirOf unstablePkgs.tmuxPlugins.resurrect.rtp;
            sidebar = builtins.dirOf unstablePkgs.tmuxPlugins.sidebar.rtp;
            autoreload = tmux-autoreload;
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
            stablePkgs.nixfmt
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
            stablePkgs.clang-tools
            unstablePkgs.typescript-language-server
            unstablePkgs.vscode-langservers-extracted
            unstablePkgs.yaml-language-server
            unstablePkgs.bash-language-server
            unstablePkgs.lua-language-server
            unstablePkgs.emmylua-check
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
            (unstablePkgs.google-cloud-sdk.withExtraComponents (
              with unstablePkgs.google-cloud-sdk.components;
              [
                gke-gcloud-auth-plugin
                kubectl-oidc
              ]
            ))
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
            { packages, extraShellHook }:
            stablePkgs.mkShell {
              inherit packages;

              LIBCLANG_PATH = "${stablePkgs.llvmPackages.libclang.lib}/lib";

              NIX_ENFORCE_PURITY = "";

              # Disable Nix hardening flags (fortify, format, etc.) that break
              # autoconf-based C builds like jemalloc (strerror_r detection)
              # and format attribute checks. Not needed for a dev shell.
              hardeningDisable = [ "all" ];

              shellHook = ''
                export ZSH=${stablePkgs.oh-my-zsh}/share/oh-my-zsh
                export ZSH_CUSTOM=${zshCustom}
                export GITSTATUS_DAEMON=${stablePkgs.gitstatus}/bin/gitstatusd
                export NVIM_LUA_LIBS=${nvimLuaLibs}
                ${extraShellHook}
                export TMUX_PLUGINS=${tmuxPluginsDir}
                export TMPPREFIX="$HOME/.cache/zsh"
                export EDITOR=nvim

                GIT_COMPLETION_DIR=${stablePkgs.git}/share/git/contrib/completion
                export GIT_COMPLETION_DIR

                unset TERM
                export SHELL=${stablePkgs.zsh}/bin/zsh
                [[ $- == *i* ]] && exec ${stablePkgs.zsh}/bin/zsh
              '';
            };
        in
        {
          default = makeShell {
            packages = toInstallBasic ++ toInstallExtra;
            # The plugin set needs the language servers from toInstallExtra.
            extraShellHook = ''
              export NEOVIM_LAZY_PATH=${unstablePkgs.vimPlugins.lazy-nvim}
              export NEOVIM_PLUGINS_PATH=${nvimPlugins}
              export NEOVIM_TREESITTER_PATH=${nvimTreesitter}
            '';
          };
          basic = makeShell {
            packages = toInstallBasic;
            extraShellHook = "";
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          unstablePkgs = import nixpkgs-unstable { inherit system; };

          nvimCheck =
            name: script:
            unstablePkgs.runCommand name
              {
                nativeBuildInputs = [
                  unstablePkgs.neovim
                  unstablePkgs.nodejs_22
                  unstablePkgs.git
                ];
                NEOVIM_LAZY_PATH = unstablePkgs.vimPlugins.lazy-nvim;
                NEOVIM_PLUGINS_PATH = nvimPluginsFor unstablePkgs;
                NEOVIM_TREESITTER_PATH = nvimTreesitterFor unstablePkgs;
                BWRAPPED = 1;
              }
              ''
                export HOME=$TMPDIR/home
                export XDG_CONFIG_HOME=$HOME/.config
                export XDG_CACHE_HOME=$TMPDIR/cache
                export XDG_DATA_HOME=$TMPDIR/data
                export XDG_STATE_HOME=$TMPDIR/state
                mkdir -p "$XDG_CONFIG_HOME"
                # init.vim sources `~/.config/vim`, so the config has to sit under $HOME
                cp -r --no-preserve=mode ${self}/.config/nvim "$XDG_CONFIG_HOME/nvim"
                cp -r --no-preserve=mode ${self}/.config/vim "$XDG_CONFIG_HOME/vim"
                nvim --headless +"luafile $XDG_CONFIG_HOME/nvim/lua/${script}"
                touch $out
              '';

          nvimLuaLibs = nvimLuaLibsFor unstablePkgs;
        in
        {
          nvim-smoke-test = nvimCheck "nvim-smoke-test" "smoke_test.lua";
          nvim-deprecations = nvimCheck "nvim-deprecations" "deprecation_check.lua";

          emmylua =
            unstablePkgs.runCommand "emmylua-check"
              {
                nativeBuildInputs = [ unstablePkgs.emmylua-check ];
                NVIM_LUA_LIBS = nvimLuaLibsFor unstablePkgs;
              }
              ''
                export HOME=$TMPDIR
                emmylua_check ${self}/.config/nvim --warnings-as-errors
                touch $out
              '';

          yamllint = unstablePkgs.runCommand "yamllint" { nativeBuildInputs = [ unstablePkgs.yamllint ]; } ''
            cd ${self}
            yamllint -c .config/yamllint/config.yaml .
            touch $out
          '';

          taplo = unstablePkgs.runCommand "taplo" { nativeBuildInputs = [ unstablePkgs.taplo ]; } ''
            cd ${self}
            taplo lint --config .config/taplo/taplo.toml
            touch $out
          '';

          editorconfig =
            unstablePkgs.runCommand "editorconfig"
              { nativeBuildInputs = [ unstablePkgs.editorconfig-checker ]; }
              ''
                cd ${self}
                editorconfig-checker -config .config/editorconfig-checker/config.json
                touch $out
              '';

          stylua = unstablePkgs.runCommand "stylua" { nativeBuildInputs = [ unstablePkgs.stylua ]; } ''
            cd ${self}
            stylua --check .
            touch $out
          '';

          luacheck =
            unstablePkgs.runCommand "luacheck" { nativeBuildInputs = [ unstablePkgs.luajitPackages.luacheck ]; }
              ''
                cd ${self}
                luacheck .
                touch $out
              '';

          lua-language-server =
            unstablePkgs.runCommand "lua-language-server"
              {
                nativeBuildInputs = [ unstablePkgs.lua-language-server ];
                LUARC = unstablePkgs.writers.writeJSON "luarc.json" {
                  "runtime.version" = "LuaJIT";
                  "diagnostics.globals" = [
                    "vim"
                    "MiniIcons"
                  ];
                  "workspace.library" = [
                    "${nvimLuaLibs}/nvim-runtime"
                    "${nvimLuaLibs}/telescope-nvim"
                    "${nvimLuaLibs}/plenary-nvim"
                    "${nvimLuaLibs}/sqlite-lua"
                  ];
                };
              }
              ''
                export HOME=$TMPDIR
                cd ${self}
                lua-language-server --check "$PWD/.config/nvim" \
                  --checklevel=Warning \
                  --configpath=$LUARC \
                  --logpath=$TMPDIR/lua-language-server-log
                touch $out
              '';

          actionlint =
            unstablePkgs.runCommand "actionlint" { nativeBuildInputs = [ unstablePkgs.actionlint ]; }
              ''
                cd ${self}
                actionlint .github/workflows/*
                touch $out
              '';

          zizmor = unstablePkgs.runCommand "zizmor" { nativeBuildInputs = [ unstablePkgs.zizmor ]; } ''
            cd ${self}
            zizmor --no-online-audits .github/workflows/
            touch $out
          '';

          nixfmt = unstablePkgs.runCommand "nixfmt" { nativeBuildInputs = [ unstablePkgs.nixfmt ]; } ''
            cd ${self}
            find . -type f -name '*.nix' -print0 | xargs -0 nixfmt --check
            touch $out
          '';

          statix = unstablePkgs.runCommand "statix" { nativeBuildInputs = [ unstablePkgs.statix ]; } ''
            cd ${self}
            statix check .
            touch $out
          '';

          deadnix = unstablePkgs.runCommand "deadnix" { nativeBuildInputs = [ unstablePkgs.deadnix ]; } ''
            cd ${self}
            deadnix --fail --no-lambda-pattern-names .
            touch $out
          '';

          shellcheck =
            unstablePkgs.runCommand "shellcheck" { nativeBuildInputs = [ unstablePkgs.shellcheck ]; }
              ''
                cd ${self}
                find . -type f -print0 \
                  | xargs -0 file --mime-type \
                  | awk -F: '$2 ~ /text\/x-shellscript/ {print $1}' \
                  | grep -v '^\./\.config/zsh/' \
                  | xargs shellcheck
                touch $out
              '';

          shfmt = unstablePkgs.runCommand "shfmt" { nativeBuildInputs = [ unstablePkgs.shfmt ]; } ''
            cd ${self}
            find . -type f -print0 \
              | xargs -0 file --mime-type \
              | awk -F: '$2 ~ /text\/x-shellscript/ {print $1}' \
              | grep -v '^\./\.config/zsh/' \
              | xargs shfmt --indent 4 --case-indent --diff
            touch $out
          '';

          zsh-syntax = unstablePkgs.runCommand "zsh-syntax" { nativeBuildInputs = [ unstablePkgs.zsh ]; } ''
            cd ${self}
            find .config/zsh -type f -print0 | xargs -0 -n1 zsh -n
            zsh -n .zshenv
            touch $out
          '';

          ruff-format =
            unstablePkgs.runCommand "ruff-format" { nativeBuildInputs = [ unstablePkgs.ruff ]; }
              ''
                cd ${self}
                ruff format --check --no-cache .
                touch $out
              '';

          ruff-lint = unstablePkgs.runCommand "ruff-lint" { nativeBuildInputs = [ unstablePkgs.ruff ]; } ''
            cd ${self}
            ruff check --no-cache .
            touch $out
          '';

          mypy =
            unstablePkgs.runCommand "mypy"
              {
                nativeBuildInputs = [
                  (unstablePkgs.python3.withPackages (pythonPackages: [
                    pythonPackages.i3ipc
                    pythonPackages.mypy
                    pythonPackages.pytest
                  ]))
                ];
              }
              ''
                cd ${self}
                find . -type f -name '*.py' -print0 \
                  | xargs -0 mypy --strict --cache-dir=$TMPDIR/mypy
                touch $out
              '';

          rustfmt =
            unstablePkgs.runCommand "rustfmt"
              {
                nativeBuildInputs = [
                  unstablePkgs.cargo
                  unstablePkgs.rustfmt
                ];
              }
              ''
                export HOME=$TMPDIR
                cd ${self}
                cargo fmt --manifest-path apps/Cargo.toml --all --check
                touch $out
              '';

          json = unstablePkgs.runCommand "json" { nativeBuildInputs = [ unstablePkgs.jq ]; } ''
            cd ${self}
            find . -type f -name '*.json' -not -path './.config/Code/User/*' -print0 \
              | xargs -0 -n1 jq empty
            touch $out
          '';

          markdownlint =
            unstablePkgs.runCommand "markdownlint" { nativeBuildInputs = [ unstablePkgs.markdownlint-cli ]; }
              ''
                cd ${self}
                find . -type f -name '*.md' -print0 \
                  | xargs -0 markdownlint --config .config/markdownlint/config.yaml
                touch $out
              '';

          desktop-entries =
            unstablePkgs.runCommand "desktop-entries"
              { nativeBuildInputs = [ unstablePkgs.desktop-file-utils ]; }
              ''
                cd ${self}
                desktop-file-validate .config/autostart/*.desktop
                touch $out
              '';

          vint = unstablePkgs.runCommand "vint" { nativeBuildInputs = [ unstablePkgs.vim-vint ]; } ''
            cd ${self}
            vint --warning --enable-neovim .config/vim/vimrc .config/nvim/init.vim
            touch $out
          '';

          dangling-symlinks = unstablePkgs.runCommand "dangling-symlinks" { } ''
            cd ${self}
            find . -type l -not -lname '/*' -xtype l \
              | awk '{print "dangling symlink: " $0} END {exit NR > 0}'
            touch $out
          '';

          shell-exec-bit = unstablePkgs.runCommand "shell-exec-bit" { } ''
            cd ${self}
            find . -type f ! -perm -u+x -print0 \
              | xargs -0 file --mime-type \
              | awk -F: '$2 ~ /text\/x-shellscript/ {print "not executable: " $1; found = 1} END {exit found}'
            touch $out
          '';

          typos = unstablePkgs.runCommand "typos" { nativeBuildInputs = [ unstablePkgs.typos ]; } ''
            cd ${self}
            typos --isolated --config .config/typos/typos.toml .
            touch $out
          '';

          pre-commit-config =
            unstablePkgs.runCommand "pre-commit-config" { nativeBuildInputs = [ unstablePkgs.pre-commit ]; }
              ''
                export HOME=$TMPDIR
                cd ${self}
                pre-commit validate-config .pre-commit-config.yaml
                touch $out
              '';

          biome = unstablePkgs.runCommand "biome" { nativeBuildInputs = [ unstablePkgs.biome ]; } ''
            export HOME=$TMPDIR
            cd ${self}
            biome lint --config-path=.config/biome/biome.json --error-on-warnings \
              .local/share/tampermonkey/*.user.js
            touch $out
          '';

          apps-packages = unstablePkgs.linkFarm "apps-packages" apps.packages.${system};
        }
        // nixpkgs-stable.lib.optionalAttrs unstablePkgs.stdenv.hostPlatform.isLinux {
          sway-config =
            unstablePkgs.runCommand "sway-config" { nativeBuildInputs = [ unstablePkgs.sway-unwrapped ]; }
              ''
                export XDG_RUNTIME_DIR=$TMPDIR/run
                mkdir -p "$XDG_RUNTIME_DIR"
                export WLR_BACKENDS=headless
                export WLR_RENDERER=pixman
                cd ${self}
                sway --validate --config .config/sway/config
                sway --validate --config .config/sway/config-minimal
                touch $out
              '';
        }
      );
    };
}
