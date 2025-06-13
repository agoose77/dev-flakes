{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      envWithScript = script:
        (pkgs.buildFHSUserEnv {
          name = "micromamba-env";
          targetPkgs = pkgs: (with pkgs; [
            micromamba
          ]);
          runScript = let
            mamba = "${pkgs.lib.getExe pkgs.micromamba}";
          in "${pkgs.writeShellScriptBin "runScript" (''
              set -e
              export MAMBA_ROOT_PREFIX=${builtins.getEnv "PWD"}/.mamba
              eval "$(${mamba} shell hook --shell bash | sed 's/complete / # complete/g')"
              test -d .env || ${mamba} create -p .env/
	      # Use created command
              micromamba activate .env/
              set +e
            ''
            + script)}/bin/runScript";
        })
        .env;
    in {
      devShell = envWithScript "bash";
    });
}
