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
        script -t script-timing.log script-out.log $runvis
    else
        script=$tmpDir/script.sh
        cat >$script <<END
#!/bin/bash
script -c "$runvis" -t script-timing.log script-out.log
END
        chmod +x $script
        cat $script
        $script
    fi
else
    ./run -vv ..
fi
