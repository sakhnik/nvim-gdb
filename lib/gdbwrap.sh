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
# Beware that readlink -f doesn't work in some systems
readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
this_dir=$(readlinkf `dirname ${BASH_SOURCE[0]}`)

gdb_init=`mktemp /tmp/gdb_init.XXXXXX`
cat >$gdb_init <<EOF
set confirm off
set pagination off
EOF

cleanup()
{
    unlink $gdb_init
}
trap cleanup EXIT

# Execute gdb finally through the proxy with our custom initialization script
"$this_dir/gdbproxy.py" -a $server_addr -- "$gdb" -f -ix $gdb_init $rest
