class Logger:
    def __init__(self, fname, keys):
        self.f = open(fname, "w")
        self.keys = keys

    def log(self, key, msg):
        if self.f and key in self.keys:
            self.f.write("[{}] {}\n".format(key, msg))
            self.f.flush()
