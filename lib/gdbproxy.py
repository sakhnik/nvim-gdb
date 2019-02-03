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
from StreamFilter import StreamFilter

class GdbProxy(BaseProxy):
    PROMPT = b"\n(gdb) "

    def __init__(self):
        super().__init__("GDB")

    def ProcessInfoBreakpoints(self, last_src, response):
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.
        self.log("Process info breakpoints %d bytes" % len(response))

        # Select lines in the current file with enabled breakpoints.
        pattern = re.compile("([^:]+):(\d+)")
        breaks = {}
        for line in response.decode('utf-8').splitlines():
            try:
                fields = re.split("\s+", line)
                if fields[3] == 'y':    # Is enabled?
                    m = pattern.fullmatch(fields[-1])   # file.cpp:line
                    if (m and (last_src.endswith(m.group(1)) or last_src.endswith(os.path.realpath(m.group(1))))):
                        line = m.group(2)
                        brId = int(fields[0])
                        try:
                            breaks[line].append(brId)
                        except KeyError:
                            breaks[line] = [brId]
            except Exception as e:
                pass

        return json.dumps(breaks).encode('utf-8')

    def ProcessHandleCommand(self, cmd, response):
        self.log("Process handle command %d bytes" % len(response))
        return response[(len(cmd) + 1):-len(GdbProxy.PROMPT)]

    def FilterCommand(self, command):
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'info-breakpoints':
            last_src = tokens[1]
            cmd = b'server info breakpoints'
            res = self.set_filter(StreamFilter(cmd, GdbProxy.PROMPT),
                    lambda d: self.ProcessInfoBreakpoints(last_src, d))
            return cmd if res else b''
        elif tokens[0] == 'handle-command':
            cmd = b'server ' + command[len('handle-command '):]
            res = self.set_filter(StreamFilter(cmd, GdbProxy.PROMPT),
                    lambda d: self.ProcessHandleCommand(cmd, d))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    GdbProxy().run()
