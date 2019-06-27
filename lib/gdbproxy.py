#!/usr/bin/env python3

"""
Run GDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re
import json
import os

from base_proxy import BaseProxy
from StreamFilter import StreamFilter

class GdbProxy(BaseProxy):
    PROMPT = re.compile(b"\x1a\x1a\x1a")
    CSEQ = re.compile(b'\[[^m]*m')

    def __init__(self):
        super().__init__("GDB")

    def ProcessInfoBreakpoints(self, last_src, response):
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.
        self.log("Process info breakpoints %d bytes" % len(response))

        # Filter out the escape sequences used by GDB8
        response = GdbProxy.CSEQ.sub(b'', response)

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
                self.log('Exception: {}'.format(str(e)))

        return json.dumps(breaks).encode('utf-8')

    def ProcessHandleCommand(self, cmd, response):
        self.log("Process handle command %d bytes" % len(response))
        # XXX: Assuming the prompt occupies the last line
        result = response[(len(cmd) + 1):response.rfind(b'\n')].strip()
        # Get rid of control sequences
        return GdbProxy.CSEQ.sub(b'', result)

    def filter_command(self, command):
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'info-breakpoints':
            last_src = tokens[1]
            res = self.set_filter(StreamFilter(GdbProxy.PROMPT),
                    lambda d: self.ProcessInfoBreakpoints(last_src, d))
            return b'server info breakpoints' if res else b''
        elif tokens[0] == 'handle-command':
            cmd = b'server ' + command[len('handle-command '):]
            res = self.set_filter(StreamFilter(GdbProxy.PROMPT),
                    lambda d: self.ProcessHandleCommand(cmd, d))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    GdbProxy().run()
