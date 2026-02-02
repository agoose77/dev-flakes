{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      inherit (pkgs) lib;

      # Unset these unwanted env vars
      # PYTHONPATH bleeds from Nix Python packages
      unwantedEnvPreamble = ''
        unset SOURCE_DATE_EPOCH PYTHONPATH
      '';
      venvDir = "./.venv";
      manyLinux = pkgs.pythonManylinuxPackages.manylinux2014;

      envWithScript = (
        python: let
          packages =
            (with pkgs; [
              cmake
              ninja
              gcc
              pre-commit
            ])
            ++ [
              python
              python.pkgs.venvShellHook
            ];
        in
          pkgs.mkShell {
            inherit packages venvDir;
            nativeBuildInputs = [pkgs.makeWrapper];

            # Drop bad env vars on activation
            postShellHook = unwantedEnvPreamble;

            # Setup venv by patching interpreter with LD_LIBRARY_PATH
            # This is required because ld does not exist on Nix systems
            postVenvCreation = let
              # Find the interpreter of the venv
              interpreterPath = lib.path.subpath.join [venvDir "bin" (baseNameOf python.interpreter)];
            in
              unwantedEnvPreamble
              # Patch the venv to find the dynamic libs
              + ''
                wrapProgram "${interpreterPath}" --prefix "LD_LIBRARY_PATH" : "${lib.makeLibraryPath manyLinux}"
              '';
          }
      );
    in {
      devShells = rec {
        py310 =
          envWithScript pkgs.python310;
        py311 =
          envWithScript pkgs.python311;
        py312 =
          envWithScript pkgs.python312;
        py313 =
          envWithScript pkgs.python313;
        py314 =
          envWithScript pkgs.python314;
        default = py314;
      };
    });
}
