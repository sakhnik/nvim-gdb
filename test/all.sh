#!/bin/bash -e

cd "$(dirname "${BASH_SOURCE[0]}")"/..
rootDir="$(pwd -P)"

# Deliberately test that the tests pass from a random symlink
# to the source directory.
tmpDir="$(mktemp -d /tmp/nvim-gdb-test.XXXXXX)"
ln -sf "$rootDir" "$tmpDir/src"
cleanup() {
    unlink "$tmpDir/src";
    rmdir "$tmpDir"
}
trap cleanup EXIT

cd "$tmpDir/src/test"

./prerequisites.sh

if [[ $# -gt 0 ]]; then
    ./run-visual -vv ..
else
    ./run -vv ..
fi
