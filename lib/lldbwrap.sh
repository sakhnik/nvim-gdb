#!/bin/bash

# Assuming the first argument is path to lldb, the rest are arguments.
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
# Beware that readlink -f doesn't work in Darwin
readlinkf(){ perl -MCwd -e 'print Cwd::abs_path shift' "$1";}
this_dir=$(readlinkf `dirname ${BASH_SOURCE[0]}`)

unlink $server_addr >/dev/null 2>&1 || true

lldb_init=`mktemp /tmp/lldb_init.XXXXXX`
cat >$lldb_init <<EOF
command script import $this_dir/lldb_commands.py
command script add -f lldb_commands.init nvim-gdb-init
nvim-gdb-init $server_addr
settings set frame-format frame #\${frame.index}: \${frame.pc}{ \${module.file.basename}{\`\${function.name-with-args}{\${frame.no-debug}\${function.pc-offset}}}}{ at \032\032\${line.file.fullpath}:\${line.number}}{\${function.is-optimized} [opt]}\n
settings set auto-confirm true
settings set stop-line-count-before 0
settings set stop-line-count-after 0
EOF

cleanup()
{
    unlink $lldb_init
    unlink $server_addr
}
trap cleanup EXIT

# Execute lldb finally with our custom initialization script
"$lldb" -S $lldb_init $rest
