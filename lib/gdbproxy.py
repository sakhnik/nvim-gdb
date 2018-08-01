#!/usr/bin/env python3

"""
Run GDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

from BaseProxy import BaseProxy


class _GdbFeatures:
    def __init__(self):
        self.app_name = "GDB"
        self.command_begin = b"server nvim-gdb-"
        self.command_end = b"\n(gdb) "

    def ProcessResponse(self, response, addr, sock):
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.
        pass

    def FilterCommand(self, command):
        # Assuming the code is primarily targeted for GDB,
        # nothing needs be adapted here.
        return command


if __name__ == '__main__':
    BaseProxy.Create(_GdbFeatures())
