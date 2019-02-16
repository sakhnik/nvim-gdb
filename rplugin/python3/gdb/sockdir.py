import tempfile

class SockDir:
    def __init__(self):
        self.sockDir = tempfile.TemporaryDirectory(prefix='nvimgdb-sock')

    def cleanup(self):
        if self.sockDir:
            self.sockDir.cleanup()
            self.sockDir = None

    def get(self):
        return self.sockDir.name
