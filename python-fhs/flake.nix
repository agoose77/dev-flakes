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
    devShells = forAllSystems (
      system: let
        pkgs = import nixpkgs {inherit system;};
        inherit (pkgs) lib;

        devShells = lib.listToAttrs (lib.map
          (name: let
            python = lib.getAttr name pkgs;
          in {
            inherit name;
            value =
              (pkgs.buildFHSEnv
                {
                  name = "python-env";
                  targetPkgs = pkgs:
                    (with pkgs; [
                      pythonManylinuxPackages.manylinux2014Package
                      cmake
                      ninja
                      gcc
                      pre-commit
                    ])
                    ++ [python];
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

                    exec ${lib.getExe pkgs.bash} "$@"
                  ''}/bin/runScript";
                }).env;
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
