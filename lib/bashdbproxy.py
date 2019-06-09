#!/usr/bin/env python3

"""
Run bashdb in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re
import json
import os

from BaseProxy import BaseProxy
from StreamFilter import StreamFilter

class BashDbProxy(BaseProxy):
    PROMPT = re.compile(b'[\r\n]bashdb<\(?\d+\)?> ')
    CSEQ = re.compile(b'\[[^m]*m')

    def __init__(self):
        super().__init__("BashDB")

    def ProcessInfoBreakpoints(self, last_src, response):
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.
        self.log("Process info breakpoints %d bytes" % len(response))

        # Filter out the escape sequences used by GDB8
        response = BashDbProxy.CSEQ.sub(b'', response)

        # Select lines in the current file with enabled breakpoints.
        pattern = re.compile("([^:]+):(\d+)")
        breaks = {}
        for line in response.decode('utf-8').splitlines():
            try:
                fields = re.split("\s+", line)
                if fields[3] == 'y':    # Is enabled?
                    m = pattern.fullmatch(fields[-1])   # file.cpp:line
                    if m and m.group(1) == last_src:
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
        # XXX: Assuming the prompt occupies the last line
        result = response[(len(cmd) + 1):response.rfind(b'\n')].strip()
        # Get rid of control sequences
        return BashDbProxy.CSEQ.sub(b'', result)

    def FilterCommand(self, command):
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'info-breakpoints':
            last_src = tokens[1]
            res = self.set_filter(StreamFilter(BashDbProxy.PROMPT),
                    lambda d: self.ProcessInfoBreakpoints(last_src, d))
            return b'info breakpoints' if res else b''
        elif tokens[0] == 'handle-command':
            cmd = command[len('handle-command '):]
            res = self.set_filter(StreamFilter(BashDbProxy.PROMPT),
                    lambda d: self.ProcessHandleCommand(cmd, d))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    BashDbProxy().run()
