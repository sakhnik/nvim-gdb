import os

def getPluginDir():
    path = os.path.realpath(__file__)
    for i in range(4):
        path = os.path.dirname(path)
    return path

class Client:
    def __init__(self, vim, win, proxyCmd, clientCmd, sockDir):
        self.vim = vim
        self.win = win

        # Prepare the debugger command to run
        self.command = clientCmd
        if proxyCmd:
            self.proxyAddr = sockDir.get() + '/server'
            self.command = "%s/lib/%s -a %s -- %s" % (getPluginDir(), proxyCmd, self.proxyAddr, clientCmd)
        vim.command("%dwincmd w" % win.number)
        vim.command("enew")
        self.clientBuf = vim.current.buffer

    def delBuffer(self):
        #if self.clientBuf.api.is_loaded():
        if self.vim.call("bufexists", self.clientBuf.handle):
            self.vim.command("bd! %d" % self.clientBuf.handle)

    def cleanup(self):
        if self.proxyAddr:
            os.remove(self.proxyAddr)

    def start(self):
        # Go to the yet-to-be terminal window
        self.vim.command("%dwincmd w" % self.win.number)
        self.clientId = self.vim.call("nvimgdb#TermOpen", self.command, self.vim.current.tabpage.handle)

    def interrupt(self):
        self.vim.call("jobsend", self.clientId, "\x03")

    def sendLine(self, data):
        self.vim.call("jobsend", self.clientId, data + "\n")

    def getBuf(self):
        return self.clientBuf

    def getProxyAddr(self):
        return self.proxyAddr
