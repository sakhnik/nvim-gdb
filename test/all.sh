#!/bin/bash -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..
rootDir="$(pwd -P)"

# Deliberately test that the tests pass from a random symlink
# to the source directory.
tmpDir="$(mktemp -d -t nvim-gdb-test.XXXXXX)"
ln -sf "$rootDir" "$tmpDir/src"
cleanup() {
    unlink "$tmpDir/src";
    rm -rf "$tmpDir"
}
trap cleanup EXIT

cd "$tmpDir/src/test"

echo "Test neovim is usable"
nvim --headless +qa

python ./prerequisites.py

./run -vv .. 2>&1 | tee pytest.log

exit ${PIPESTATUS[0]}
