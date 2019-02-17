
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
        self.prevLine = ''

    # Add a new transition for a given state using {matcher, matchingFunc}
    # Call the handler when matched.
    def addTrans(self, state, matcher, func):
        state.append((matcher, func))

    def isPaused(self):
        return self.state == self.paused

    def isRunning(self):
        return self.state == self.running


    def pausedContinue(self, matcher, line):
        if matcher.search(line):
            self.log("pausedContinue")
            self.cursor.hide()
            return self.running

    def pausedJump(self, matcher, line):
        m = matcher.search(line)
        if m:
            fname = m.group(1)
            ln = m.group(2)
            self.log("pausedJump {}:{}".format(fname, ln))
            self.win.jump(fname, int(ln))
            return self.paused

    def queryB(self, matcher, line):
        if matcher.search(line):
            self.log('queryB')
            self.win.queryBreakpoints()
            return self.paused

    def _matchLine(self, line):
        # If there is a matcher matching the line, call its handler.
        for matcher, func in self.state:
            newState = func(matcher, line)
            if newState:
                self.state = newState
                self.log("new state: {}".format(str(newState)))
                return True
        return False

    # Process a line of the debugger output through the SCM.
    def feed(self, lines):
        for line in lines:
            self.log(line)
            if self._matchLine(line):
                self.prevLine = line
                continue
            # If the line didn't match, try concatenating with the previous line.
            self._matchLine(self.prevLine + line)
            self.prevLine = line
