require "set_paths"
libstd = require "posix.stdlib"
s = require "posix.sys.socket"

function InfoBreakpoints(fname, proxy_addr)
    dir = libstd.mkdtemp('/tmp/nvimgdb-sock-XXXXXX')
    sock = s.socket(s.AF_UNIX, s.SOCK_DGRAM, 0)
    s.bind(sock, {family = s.AF_UNIX, path = dir .. "/socket"})
    s.setsockopt(sock, s.SOL_SOCKET, s.SO_RCVTIMEO, 0, 500000)
    s.connect(sock, {family = s.AF_UNIX, path = proxy_addr})
    s.send(sock, "info-breakpoints " .. fname .. "\n")
    data = s.recv(sock, 65536)
    os.remove(dir .. "/socket")
    os.remove(dir)
    return data
end
