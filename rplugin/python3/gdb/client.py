'''.'''

import os
from gdb.common import Common


class Client(Common):
    '''The class to maintain connection to the debugger client.'''
    @staticmethod
    def _get_plugin_dir():
        path = os.path.realpath(__file__)
        for _ in range(4):
            path = os.path.dirname(path)
        return path

    def __init__(self, common, win, proxy_cmd, client_cmd, sock_dir):
        super().__init__(common)
        self.win = win
        self.client_id = None

        # Prepare the debugger command to run
        self.command = client_cmd
        if proxy_cmd:
            self.proxy_addr = sock_dir.get() + '/server'
            self.command = f"{self._get_plugin_dir()}/lib/{proxy_cmd}" \
                f" -a {self.proxy_addr} -- {client_cmd}"
        self.vim.command(f"{win.number}wincmd w")
        self.vim.command("enew")
        self.client_buf = self.vim.current.buffer

    def del_buffer(self):
        '''Delete the client buffer.'''
        if self.vim.call("bufexists", self.client_buf.handle):
            self.vim.command(f"bd! {self.client_buf.handle}")

    def cleanup(self):
        '''The destructor.'''
        if self.proxy_addr:
            try:
                os.remove(self.proxy_addr)
            except FileNotFoundError:
                pass

    def start(self):
        '''Open a terminal window with the debugger client command.'''
        # Go to the yet-to-be terminal window
        self.vim.command(f"{self.win.number}wincmd w")
        self.client_id = self.vim.call("nvimgdb#TermOpen", self.command,
                                       self.vim.current.tabpage.handle)

    def interrupt(self):
        '''Interrupt running program by sending ^c.'''
        self.vim.call("jobsend", self.client_id, "\x03")

    def send_line(self, data):
        '''Execute one command on the debugger interpreter.'''
        self.vim.call("jobsend", self.client_id, data + "\n")

    def get_buf(self):
        '''Get the client terminal buffer.'''
        return self.client_buf

    def get_proxy_addr(self):
        '''Get the side-channel address.'''
        return self.proxy_addr
