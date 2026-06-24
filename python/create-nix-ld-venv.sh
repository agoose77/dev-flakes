# This file is mostly copied from https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/interpreters/python/hooks/venv-shell-hook.sh
# But modified to use a different venv mechanism
venvPath="$(realpath "$1")";

if [[ -z "$venvPath" ]]; then
  echo "Missing venv arg" >> /dev/stderr
exit 1
fi

interpreterName=$(basename "@python@")
executablePath="$venvPath/bin/$interpreterName"

# Create virtual env
"@python@" -m venv "$venvPath"

# Replace symlink binary with copy
rm "$executablePath"
cp "@pythonInterpreter@" "$executablePath"
chmod 755 "$executablePath"

# Patch interpreter to use nix-ld linker
"@patchelf@" --set-interpreter "@linkerPath@" "$executablePath"

exit 0
# Move patched interpreter to hidden path
hiddenPath="$(dirname "$executablePath")/.$(basename "$executablePath")"-wrapped
mv "$executablePath" "$hiddenPath"

# Create shim that invokes Python with vars
cat <<-EOF > "$executablePath"
#!@bash@
export NIX_LD_LIBRARY_PATH="@libraryPath@" NIX_LD="@baseLinkerPath@"
exec -a "$0" "$hiddenPath" "\$@"
EOF
chmod 755 "$executablePath"
