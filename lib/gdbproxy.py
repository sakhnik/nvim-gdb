#!/usr/bin/env python3

"""
Run GDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

from BaseProxy import BaseProxy


class _GdbFeatures:
    app_name = "GDB"
    command_begin = b"server nvim-gdb-"
    command_end = b"\n(gdb) "

    @staticmethod
    def ProcessResponse(response, addr, sock):
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.
        pass


if __name__ == '__main__':
    BaseProxy.Create(_GdbFeatures)
