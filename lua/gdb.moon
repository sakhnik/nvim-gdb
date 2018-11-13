gdb =
    app: require "gdb.app"
    breakpoint: require "gdb.breakpoint"
    Cursor: require "gdb.cursor"
    win: require "gdb.win"
    scm: require "gdb.scm"
    client: require "gdb.client"
    backend:
        gdb: require "gdb.backend.gdb"
        lldb: require "gdb.backend.lldb"
        pdb: require "gdb.backend.pdb"

gdb
