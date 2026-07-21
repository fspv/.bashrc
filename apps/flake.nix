{
  description = "Personal Rust tools workspace";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # Shared source for any package built from this workspace: only the
          # files cargo needs, so build artifacts never invalidate the derivation.
          workspaceSrc = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./Cargo.toml
              ./Cargo.lock
              ./common
              ./comment-lsp
              ./jj
              ./github
              ./jjui-tools
              ./jj-tools
            ];
          };
          tool = name: pkgs.rustPlatform.buildRustPackage {
            pname = name;
            version = "0.1.0";
            src = workspaceSrc;
            cargoLock.lockFile = ./Cargo.lock;
            cargoBuildFlags = [ "-p" name ];
          };
        in
        {
          comment-lsp = tool "comment-lsp";
          jjui-tools = tool "jjui-tools";
          jj-tools = tool "jj-tools";

          default = self.packages.${system}.jjui-tools;
        });
    };
}
