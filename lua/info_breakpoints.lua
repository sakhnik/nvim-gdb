libstd = require "posix.stdlib"
libsock = require "posix.sys.socket"

function InfoBreakpoints(fname, proxy_addr)
    dir = libstd.mkdtemp('/tmp/nvimgdb-sock-XXXXXX')
    sock = libsock.socket(libsock.AF_UNIX, libsock.SOCK_DGRAM, 0)
    libsock.bind(sock, {family = libsock.AF_UNIX, path = dir .. "/socket"})
    libsock.setsockopt(sock, libsock.SOL_SOCKET, libsock.SO_RCVTIMEO, 0, 500000)
    libsock.connect(sock, {family = libsock.AF_UNIX, path = proxy_addr})
    libsock.send(sock, "info-breakpoints " .. fname .. "\n")
    data = libsock.recv(sock, 65536)
    os.remove(dir .. "/socket")
    os.remove(dir)
    return data
end
