#!/bin/bash

# Assuming the first argument is path to lldb, the rest is arguments.
# We'd like to ensure lldb is launched with our custom initialization
# injected.

# Process wrapper's options
while getopts "a:" o; do
    case "${o}" in
        a) server_addr=${OPTARG};;
        *) exit 1;;
    esac
done
shift $((OPTIND - 1))

# lldb command
lldb="$1"
# lldb arguments
rest="${@:2}"

# Prepare lldb initialization commands
this_dir=$(readlink -f `dirname ${BASH_SOURCE[0]}`)

lldb_init=`mktemp /tmp/lldb_init.XXXXXX`
cat >$lldb_init <<EOF
command script import $this_dir/lldb_commands.py
command script add -f lldb_commands.init nvim-gdb-init
nvim-gdb-init /tmp/nvim-gdb-lldb-sock
settings set frame-format frame #\${frame.index}: \${frame.pc}{ \${module.file.basename}{\`\${function.name-with-args}{\${frame.no-debug}\${function.pc-offset}}}}{ at \032\032\${line.file.fullpath}:\${line.number}}{\${function.is-optimized} [opt]}\n
settings set auto-confirm true
settings set stop-line-count-before 0
settings set stop-line-count-after 0
EOF

cleanup()
{
    unlink $lldb_init
}
trap cleanup EXIT

# Execute lldb finally with our custom initialization script
"$lldb" -S $lldb_init $rest
