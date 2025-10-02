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

      envWithScript = (
        python: let
          packages =
            (with pkgs; [
              cmake
              ninja
              gcc
              pre-commit
            ])
            ++ [python];

          shellHook = ''
            # Unset leaky PYTHONPATH
            unset PYTHONPATH

            __hash=$(echo ${python.interpreter} | sha256sum)

            # Setup if not defined ####
            if [[ ! -f ".venv/$__hash" ]]; then
                __setup_env() {
                    # Remove existing venv
                    if [[ -d .venv ]]; then
                        rm -r .venv
                    fi

                    # Stand up new venv
                    ${python.interpreter} -m venv .venv

                    # Add a marker that marks this venv as "ready"
                    touch ".venv/$__hash"
                }

              __setup_env
            fi
            ###########################

            # Activate venv
            source .venv/bin/activate
          '';
          env = lib.optionalAttrs pkgs.stdenv.isLinux {
            # Python uses dynamic loading for certain libraries.
            # We'll set the linker path instead of patching RPATH
            LD_LIBRARY_PATH = lib.makeLibraryPath pkgs.pythonManylinuxPackages.manylinux2014;
          };
        in
          pkgs.mkShell {
            inherit env packages shellHook;
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
        default = py313;
      };
    });
}
