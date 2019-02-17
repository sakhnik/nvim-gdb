
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
            self.cursor.hide()
            return self.running

    def pausedJump(self, matcher, line):
        m = matcher.search(line)
        if m:
            self.win.jump(m.group(1), int(m.group(2)))
            return self.paused

    def queryB(self, matcher, line):
        if matcher.search(line):
            self.win.queryBreakpoints()
            return self.paused

    # Process a line of the debugger output through the SCM.
    def feed(self, lines):
        for line in lines:
            self.log(line)
            # If there is a matcher matching the line, call its handler.
            for matcher, func in self.state:
                newState = func(matcher, line)
                if newState:
                    self.state = newState
                    self.log("new state: {}".format(str(newState)))
                    break
