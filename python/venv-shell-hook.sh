# This file is mostly copied from https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/interpreters/python/hooks/venv-shell-hook.sh
# But modified to use a different venv mechanism
_createVenv() {
  local venvPath="$1";

  if [[ -z "$venvPath" ]]; then
    echo "Missing venv arg" >> /dev/stderr
    exit 1
  fi

  # Run this in a subshell, because we're not affecting local state 
  # and then we can set opts
  (
     # Only set -e, -u will break wrapProgram
     set -e
     local interpreterName=$(basename "@pythonInterpreter@")
     local executablePath="$venvPath/bin/$interpreterName"

     "@pythonInterpreter@" -m venv "$venvPath"

     # Replace symlink binary with copy
     rm "$executablePath"
     cp "@pythonInterpreter@" "$executablePath"
     chmod 755 "$executablePath"

     # Patch interpreter
     patchelf --set-interpreter "@linkerPath@" "$executablePath"

     # Wrap the binary with paths
     wrapProgram "$executablePath" \
       --set "NIX_LD_LIBRARY_PATH" "@libraryPath@" \
       --set "NIX_LD" "@baseLinkerPath@"
   )
}

venvShellHookLD() {
    echo "Executing venvShellHookLD"
    runHook preShellHook

    if [ -d "${venvDir}" ]; then
        echo "Skipping venv creation, '${venvDir}' already exists"
        source "${venvDir}/bin/activate"
    else
        echo "Creating new venv environment in path: '${venvDir}'"
        _createVenv "${venvDir}"

        source "${venvDir}/bin/activate"
        runHook postVenvCreation
    fi

    runHook postShellHook
    echo "Finished executing venvShellHookLD"
}

if [ -z "${dontUseVenvShellHookLd:-}" ] && [ -z "${shellHook-}" ]; then
    echo "Using venvShellHookLD"
    if [ -z "${venvDir-}" ]; then
        echo "Error: \`venvDir\` should be set when using \`venvShellHookLD\`."
        exit 1
    else
        shellHook=venvShellHookLD
    fi
fi
