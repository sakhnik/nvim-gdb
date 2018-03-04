import re
import socket

class InfoSources(gdb.Command):
    def __init__(self):
        super(InfoSources, self).__init__("nvim-gdb-info-sources", gdb.COMMAND_NONE)

    def invoke(self, arg, from_tty):
        output = gdb.execute('info sources', from_tty=False, to_string=True)
        sources = "\n".join(sorted([f[0][::-1] for f in re.finditer(r'/[^, \n]+', output)]))
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        sock.sendto(sources.encode('utf-8'), arg)

InfoSources()
