#!/bin/bash -e

# Check the prerequisites
echo -n "Check for neovim     " && command -v nvim
echo -n "Check for python3    " && command -v python3

echo -n "" >| backends.txt

echo -n "Check for gdb        "
if command -v gdb; then
    echo "gdb" >> backends.txt
else
    echo ""
fi
echo -n "Check for lldb       "
if command -v lldb; then
    echo "lldb" >> backends.txt
else
    echo ""
fi
echo -n "Check for bashdb     "
if command -v bashdb; then
    echo "bashdb" >> backends.txt
else
    echo ""
fi

echo -n "Check for cmake     "
if command -v cmake > /dev/null; then
    min_ver=3.14.7 # need File API
    lesser_ver=$(cmake --version | \
        awk -v min_ver="$min_ver" '/cmake version/ {print $3 "\n" min_ver}' | \
        sort --version-sort | head -n 1)
    if [ "$min_ver" == "$lesser_ver" ]; then
        command -v cmake
        echo "cmake" >> backends.txt
        echo "Running CMake"
        cmake src -B src/build
    else
        echo "CMake $min_ver or greater required"
    fi
fi

CXX=g++
[[ $(uname) == Darwin ]] && CXX=clang++

# pytest will resolve all symlinks, and debuggers may
# be confused if non-absolute paths are used during compilation.
readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
this_dir="$(dirname ${BASH_SOURCE[0]})"
cd $(readlinkf "$this_dir")

echo -n "Compiling test.cpp   "
if [[ src/test.cpp -nt a.out || src/lib.hpp -nt a.out ]]; then
    $CXX -g -std=c++11 src/test.cpp
    echo "a.out"
else
    echo "(cached a.out)"
fi
