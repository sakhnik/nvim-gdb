'''LLDB specifics.'''

import os
import re
import socket
import threading
from gdb.proxy import Proxy
from gdb.scm import BaseScm

import pysnooper
class LldbScm(BaseScm):
    '''LLDB SCM.'''
    @pysnooper.snoop("/tmp/what3")
    def __init__(self, common, cursor, win):
        super().__init__(common, cursor, win)

        re_prompt = re.compile(r'[\r\n]\(lldb\) $')
        self.add_trans(self.paused,
                       re.compile(r'[\r\n]Process \d+ resuming'),
                       self._paused_continue)
        self.add_trans(self.paused,
                       re.compile(r' at ([^:]+):(\d+)'),
                       self._paused_jump)
        self.add_trans(self.paused, re_prompt, self._query_b)
        self.add_trans(self.running,
                       re.compile(r'[\r\n]Breakpoint \d+:'),
                       self._query_b)
        self.add_trans(self.running,
                       re.compile(r'[\r\n]Process \d+ stopped'),
                       self._query_b)
        self.add_trans(self.running, re_prompt, self._query_b)

        self.state = self.running


        if not os.path.exists("/tmp/idk"):
            os.mkdir("/tmp/idk")
        if os.path.exists("/tmp/idk/server"):
            os.remove("/tmp/idk/server")
        if os.path.exists("/tmp/idk/client"):
            os.remove("/tmp/idk/client")

        thread = threading.Thread(target=listen, args=(self,))
        thread.start()


def init():
    '''Initialize the backend.'''
    return {'initScm': LldbScm,
            'delete_breakpoints': 'breakpoint delete',
            'breakpoint': 'b',
            'until {}': 'thread until {}'}


class Match():
    '''.'''
    def __init__(self, file, line):
        self.file = file
        self.line = line

    def group(self, i):
        '''.'''
        if i == 1:
            return self.file
        if i == 2:
            return self.line
        raise Exception

    def shutup_warning(self):
        '''.'''

import pysnooper
@pysnooper.snoop("/tmp/loggers")
def listen(scm):
    '''IDK'''
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    sock.bind("/tmp/idk/client")

    while True:
        try:
            data, _ = sock.recvfrom(65536)
            contents = data.decode('utf-8')
            if contents[0:8].startswith("fileline"):
                fileline = contents[8:]
                file_and_line = fileline.split(":")
                scm.vim.async_call(scm._paused_jump, Match(file_and_line[0], file_and_line[1]))
            elif contents[0:8].startswith("breakpnt"):
                pass
        except Exception as _:
            pass
