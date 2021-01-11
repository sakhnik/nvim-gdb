#!/bin/bash -ex

cd "$(dirname "${BASH_SOURCE[0]}")"/..
rootDir="$(pwd -P)"

# Deliberately test that the tests pass from a random symlink
# to the source directory.
tmpDir="$(mktemp -d /tmp/nvim-gdb-test.XXXXXX)"
ln -sf "$rootDir" "$tmpDir/src"
cleanup() {
    unlink "$tmpDir/src";
    rm -rf "$tmpDir"
}
trap cleanup EXIT

cd "$tmpDir/src/test"

./prerequisites.sh

if [[ $# -gt 0 ]]; then

    runvis=$tmpDir/run.sh 
    cat >$runvis <<END
#!/bin/bash
./run-visual -vv ..
END
    chmod +x $runvis
    cat $runvis

    if [[ $(uname) == Darwin ]]; then
        script -t stript-timing.log script-out.log "$runvis"
    else
        # Still not quite working, script-out.log isn't collected
        script -c "$runvis" -t script-timing.log script-out.log
    fi
else
    ./run -vv ..
fi
