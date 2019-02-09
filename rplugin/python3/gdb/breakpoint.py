import json

class Breakpoint:
    def __init__(self, vim, config, proxy):
        self.vim = vim
        self.config = config
        self.proxy = proxy
        self.breaks = {}    # {file -> {line -> [id]}}
        self.maxSignId = 0

    def clearSigns(self):
        for i in range(5000, self.maxSignId + 1):
            self.vim.command('sign unplace %d' % i)
        self.maxSignId = 0

    def setSigns(self, buf):
        if buf != -1:
            signId = 5000 - 1
            # Breakpoints need full path to the buffer (at least in lldb)
            bpath = self.vim.call("expand", '#%d:p' % buf)
            def getSignName(count):
                maxCount = len(self.config['sign_breakpoint'])
                idx = count if count < maxCount else maxCount - 1
                return "GdbBreakpoint%d" % idx
            for line, ids in self.breaks.get(bpath, {}).items():
                signId += 1
                cmd = 'sign place %d name=%s line=%s buffer=%d' % \
                    (signId, getSignName(len(ids)), line, buf)
                self.vim.command(cmd)
            self.maxSignId = signId

    def query(self, bufNum, fname):
        self.breaks[fname] = {}
        resp = self.proxy.query("info-breakpoints %s\n" % fname)
        if resp:
            # We expect the proxies to send breakpoints for a given file
            # as a map of lines to array of breakpoint ids set in those lines.
            br = json.loads(resp)
            err = br.get('_error', None)
            if err:
                self.vim.command("echo \"Can't get breakpoints: %s\"" % err)
            else:
                self.breaks[fname] = br
                self.clearSigns()
                self.setSigns(bufNum)
        #else
            # TODO: notify about error

    def resetSigns(self):
        self.breaks = {}
        self.clearSigns()

    def getForFile(self, fname, line):
        breaks = self.breaks.get(fname, {})
        return breaks["%d" % line]   # make sure the line is a string
