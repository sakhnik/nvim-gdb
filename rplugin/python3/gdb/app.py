from gdb.cursor import Cursor
from gdb.sockdir import SockDir
import importlib


#class Context:
#    def __init__(self, vim):
#        self.vim = vim
#        self.f = None
#        self.f = open("/tmp/nvimgdb.log", "w")
#
#    def log(self, msg):
#        if self.f:
#            self.f.write("%s\n" % msg)
#            self.f.flush()

class App:
    def __init__(self, vim, backendStr):
        #self.ctxt = Context(vim)

        # Import the desired backend module
        self.backend = importlib.import_module("gdb.backend." + backendStr).init()

        # Create a temporary unique directory for all the sockets.
        self.sockDir = SockDir()

        # Initialize current line tracking
        self.cursor = Cursor(vim)

        # Initialize the SCM
        self.scm = self.backend["initScm"](vim, self.cursor)

    def cleanup(self):
        self.sockDir.cleanup()

    def getCommand(self, cmd):
        return self.backend.get(cmd, cmd)

    def dispatch(self, params):
        obj = getattr(self, params[0])
        method = getattr(obj, params[1])
        params = params[2:]
        return method(*params)
