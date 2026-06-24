venvShellHookLD() {
    echo "Executing venvShellHookLD"
    runHook preShellHook

    if [ -d "${venvDir}" ]; then
        echo "Skipping venv creation, '${venvDir}' already exists"
        source "${venvDir}/bin/activate"
    else
        echo "Creating new venv environment in path: '${venvDir}'"
        create-nix-ld-venv "${venvDir}"

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
