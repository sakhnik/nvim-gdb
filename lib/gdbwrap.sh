#!/bin/bash

# Assuming the first argument is path to gdb, the rest are arguments.
# We'd like to ensure gdb is launched with our custom initialization
# injected.

# Process wrapper's options
while getopts "a:" o; do
    case "${o}" in
        a) server_addr=${OPTARG};;
        *) exit 1;;
    esac
done
shift $((OPTIND - 1))

# gdb command
gdb="$1"
# gdb arguments
rest="${@:2}"

# Prepare gdb initialization commands
this_dir=$(readlink -f `dirname ${BASH_SOURCE[0]}`)

unlink $server_addr >/dev/null 2>&1 || true

gdb_init=`mktemp /tmp/gdb_init.XXXXXX`
cat >$gdb_init <<EOF
set confirm off
set pagination off
alias -a nvim-gdb-info-breakpoints = info breakpoints
EOF

cleanup()
{
    unlink $gdb_init
    unlink $server_addr
}
trap cleanup EXIT

# Execute gdb finally through the proxy with our custom initialization script
"$this_dir/gdbproxy.py" -a $server_addr -- "$gdb" -f -ix $gdb_init $rest
