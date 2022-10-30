#!/bin/bash

# Prepare gdb initialization commands
this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"

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
if [[ "$gdb" == "rr-replay.py" ]]; then
    gdb="$this_dir/rr-replay.py"
fi

# the rest are gdb arguments
shift

gdb_init=$(mktemp /tmp/gdb_init.XXXXXX)
cat >"$gdb_init" <<EOF
set confirm off
set pagination off
set filename-display absolute
python gdb.prompt_hook = lambda p: p + ("" if p.endswith("\x01\x1a\x1a\x1a\x02") else "\x01\x1a\x1a\x1a\x02")
EOF

cleanup()
{
    unlink "$gdb_init"
}
trap cleanup EXIT

# Execute gdb finally through the proxy with our custom initialization script
"$this_dir/gdb_proxy.py" -a "$server_addr" -- "$gdb" -f -ix "$gdb_init" "$@"
