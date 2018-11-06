#!/usr/bin/env python3

"""
Run GDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re
import json
import os

from BaseProxy import BaseProxy

class _GdbFeatures:
    def __init__(self):
        self.app_name = "GDB"
        self.command_begin = b"server nvim-gdb-"
        self.command_end = b"\n(gdb) "
        self.last_src = None

    def ProcessResponse(self, response):
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.

        # Select lines in the current file with enabled breakpoints.
        pattern = re.compile("([^:]+):(\d+)")
        breaks = {}   # TODO: support more than one breakpoint per line
        for line in response.decode('utf-8').splitlines():
            try:
                fields = re.split("\s+", line)
                if fields[3] == 'y':    # Is enabled?
                    m = pattern.fullmatch(fields[-1])   # file.cpp:line
                    if (m and (self.last_src.endswith(m.group(1)) or self.last_src.endswith(os.path.realpath(m.group(1))))):
                        breaks[int(m.group(2))] = int(fields[0])
            except Exception as e:
                pass

        self.last_src = None
        return json.dumps(breaks).encode('utf-8')

    def FilterCommand(self, command):
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'info-breakpoints':
            self.last_src = tokens[1]
            return b'server nvim-gdb-info-breakpoints\n'
        return command


if __name__ == '__main__':
    BaseProxy.Create(_GdbFeatures())
