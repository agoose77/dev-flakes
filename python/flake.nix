{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};

      manyLinux = pkgs.pythonManylinuxPackages.manylinux2014;
      inherit (pkgs) lib;
    in {
      nix-ld-venv-hook = lib.makeOverridable ({python}:
        pkgs.makeSetupHook {
          name = "nix-ld-venv-hook";
          propagatedBuildInputs = [pkgs.patchelf pkgs.makeBinaryWrapper];
          substitutions = {
            pythonInterpreter = python.interpreter;
            linkerPath = lib.getExe' pkgs.nix-ld "nix-ld";
            baseLinkerPath = pkgs.stdenv.cc.bintools.dynamicLinker;
            libraryPath = lib.makeLibraryPath manyLinux;
          };
        } (./venv-shell-hook.sh)) {python = pkgs.python3;};
    });
    devShells = forAllSystems (
      system: let
        pkgs = import nixpkgs {inherit system;};
        inherit (pkgs) lib;

        interpreters = ["python310" "python311" "python312" "python313" "python314"];

        devShells = lib.listToAttrs (lib.map
          (name: let
            python = lib.getAttr name pkgs;
            venvHook = self.packages.${system}.nix-ld-venv-hook.override {inherit python;};
            # Unset these unwanted env vars
            # PYTHONPATH bleeds from Nix Python packages
            unwantedEnvPreamble = ''
              unset SOURCE_DATE_EPOCH PYTHONPATH
            '';
          in {
            name = name;
            value = pkgs.mkShell {
              packages =
                [
                  python
                  venvHook
                ]
                ++ (with pkgs; [
                  cmake
                  ninja
                  gcc
                ]);
              venvDir = ".venv";

              # Drop bad env vars on activation
              postShellHook = unwantedEnvPreamble;

              # Setup venv by patching interpreter with LD_LIBRARY_PATH
              # This is required because ld does not exist on Nix systems
              postVenvCreation = unwantedEnvPreamble;
            };
          })
          interpreters);
      in
        devShells
        //
        # Set last interpreter as default
        {default = lib.getAttr (lib.lists.last interpreters) devShells;}
    );
  };
}
