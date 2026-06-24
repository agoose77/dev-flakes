{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    interpreters = ["python310" "python311" "python312" "python313" "python314"];
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};

      inherit (pkgs) lib;
    in {
      # Binary that creates venvs
      # The resulting Python interpreter uses nix-ld and pre-sets the NIX_LD_LIBRARY_PATH to the manylinux packages
      create-nix-ld-venv = let
        script = python:
        # Inject useful variables into venv-create script
          pkgs.replaceVarsWith {
            src = ./create-nix-ld-venv.sh;
            replacements = {
              python = python.interpreter;
              patchelf = lib.getExe pkgs.patchelf;
              bash = lib.getExe pkgs.bash;
              linkerPath = lib.getExe' pkgs.nix-ld "nix-ld";
              baseLinkerPath = pkgs.stdenv.cc.bintools.dynamicLinker;
              libraryPath = lib.makeLibraryPath pkgs.pythonManylinuxPackages.manylinux2014;
            };
            isExecutable = true;
          };
      in
        lib.makeOverridable ({python}:
          pkgs.writeShellApplication {
            name = "create-nix-ld-venv";
            text = "exec ${script python} \"$@\"";
          }) {python = pkgs.python3;};

      # Hook that creates venvs using create-nix-ld-venv
      nix-ld-venv-hook = lib.makeOverridable ({python}: let
        create-venv = self.packages.${system}.create-nix-ld-venv.override {inherit python;};
      in
        pkgs.makeSetupHook {
          name = "nix-ld-venv-hook";
          propagatedBuildInputs = [create-venv];
        } (./venv-shell-hook.sh)) {python = pkgs.python3;};
    });
    devShells = forAllSystems (
      system: let
        pkgs = import nixpkgs {inherit system;};
        inherit (pkgs) lib;

        devShells = lib.listToAttrs (lib.map
          (name: let
            python = lib.getAttr name pkgs;

            packages = self.packages.${system};
            venvHook = packages.nix-ld-venv-hook.override {inherit python;};
            createVenv = packages.create-nix-ld-venv.override {inherit python;};

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
                  createVenv
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
