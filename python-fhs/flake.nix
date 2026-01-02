{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      mkInterpreter = {
        python,
        pythonPackages,
      }:
        (pkgs.buildFHSUserEnv {
          name = "python-env";
          targetPkgs = pkgs:
            (with pkgs; [
              pythonManylinuxPackages.manylinux2014Package
              cmake
              ninja
              gcc
              pre-commit
            ])
            ++ [python] ++ (with pythonPackages; [pip virtualenv]);
          runScript = "${pkgs.writeShellScriptBin "runScript" ''
            set -e

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

            source .venv/bin/activate
            set +e

            ${pkgs.bash}
          ''}/bin/runScript";
        })
        .env;
    in {
      devShells = rec {
        py310 = mkInterpreter {
          python = pkgs.python310;
          pythonPackages = pkgs.python310Packages;
        };
        py311 = mkInterpreter {
          python = pkgs.python311;
          pythonPackages = pkgs.python311Packages;
        };
        py312 = mkInterpreter {
          python = pkgs.python312;
          pythonPackages = pkgs.python312Packages;
        };
        py313 = mkInterpreter {
          python = pkgs.python313;
          pythonPackages = pkgs.python313Packages;
        };
        py314 = mkInterpreter {
          python = pkgs.python314;
          pythonPackages = pkgs.python314Packages;
        };
        default = py314;
      };
    });
}
