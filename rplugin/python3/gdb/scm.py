
# Common SCM implementation for the integrated backends
class BaseScm:
    def __init__(self, vim, logger, cursor, win):
        self.vim = vim
        self.log = lambda msg: logger.log('scm', msg)
        self.cursor = cursor
        self.win = win
        self.running = []  # The running state [(matcher, matchingFunc)]
        self.paused = []   # The paused state [(matcher, matchingFunc)]
        self.state = None  # Current state (either self.running or self.paused)
        self.buffer = '\n'

    # Add a new transition for a given state using {matcher, matchingFunc}
    # Call the handler when matched.
    def addTrans(self, state, matcher, func):
        state.append((matcher, func))

    def isPaused(self):
        return self.state == self.paused

    def isRunning(self):
        return self.state == self.running

    def _get_state_name(self):
        if self.state == self.running:
            return "running"
        if self.state == self.paused:
            return "paused"
        return str(self.state)

    def pausedContinue(self, match):
        self.log("pausedContinue")
        self.cursor.hide()
        return self.running

    def pausedJump(self, match):
        fname = match.group(1)
        ln = match.group(2)
        self.log("pausedJump {}:{}".format(fname, ln))
        self.win.jump(fname, int(ln))
        return self.paused

    def queryB(self, match):
        self.log('queryB')
        self.win.queryBreakpoints()
        return self.paused

    def _search(self):
        # If there is a matcher matching the line, call its handler.
        for matcher, func in self.state:
            m = matcher.search(self.buffer)
            if m:
                self.buffer = self.buffer[m.end():]
                self.state = func(m)
                self.log("new state: {}".format(self._get_state_name()))
                return True
        return False

    # Process a line of the debugger output through the SCM.
    def feed(self, lines):
        for line in lines:
            self.log(line)
            if line:
                self.buffer += line
            else:
                self.buffer += '\n'
            while self._search():
                pass
