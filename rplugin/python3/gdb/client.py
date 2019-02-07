import os

class Client:
    def __init__(self, vim, win, proxyCmd, clientCmd, sockDir):
        self.vim = vim
        self.win = win

        # Prepare the debugger command to run
        self.command = clientCmd
        if proxyCmd:
            self.proxyAddr = sockDir.get() + '/server'
            self.command = "%s/lib/%s -a %s -- %s" %
                (vim.call("nvimgdb#GetPluginDir"), proxyCmd, self.proxyAddr, clientCmd)
        # TODO: work with the Window class
        vim.command("%dwincmd w" % vim.call("nvim_win_get_number", win))
        vim.command("enew")
        self.clientBuf = vim.current.buffer

    def cleanup(self):
        if self.proxyAddr:
            os.remove(self.proxyAddr)

    def start(self):
        # Go to the yet-to-be terminal window
        self.vim.command("%dwincmd w" % self.vim.call("nvim_win_get_number", self.win))
        self.clientId = V.call("nvimgdb#TermOpen", self.command, self.vim.current.tabpage)

    def interrupt(self):
        self.vim.call("jobsend", self.clientId, "\x03")

    def sendLine(self, data):
        self.vim.call("jobsend", self.clientId, data + "\n")

    def getBuf(self):
        return self.clientBuf

    def getProxyAddr(self):
        return self.proxyAddr
