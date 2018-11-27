require "set_paths"
libstd = require "posix.stdlib"

class SockDir
    new: =>
        @sockDir = libstd.mkdtemp('/tmp/nvimgdb-sock-XXXXXX')

    cleanup: =>
        if @sockDir != ""
            os.remove(@sockDir)

    get: => @sockDir

SockDir
