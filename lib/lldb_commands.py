import threading
import os
import socket
import re


def server(server_address):
    # Make sure the socket does not already exist
    try:
        os.unlink(server_address)
    except OSError:
        pass

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.bind(server_address)

    while True:
        data, addr = sock.recvfrom(65536)
        command = re.split(r'\s+', data.decode('utf-8'))
        if command[0] == "info-breakpoints":
            fname = command[1]
            sock.sendto(fname.encode('utf-8'), 0, addr)


def init(debugger, command, result, internal_dict):
    server_address = command
    t = threading.Thread(target=server, args=(server_address,))
    t.start()
