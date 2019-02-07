
# Common SCM implementation for the integrated backends
class BaseScm:
    def __init__(self, vim, cursor):
        self.vim = vim
        self.cursor = cursor
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
            self.vim.exec_lua("gdb.getWin():jump(...)", m[1], m[2], async_=True)
            return self.paused

    def queryB(self, matcher, line):
        if matcher.search(line):
            self.vim.exec_lua("gdb.getWin():queryBreakpoints()", async_=True)
            return self.paused

    # Process a line of the debugger output through the SCM.
    def feed(self, lines):
        for line in lines:
            # If there is a matcher matching the line, call its handler.
            for matcher, func in self.state:
                newState = func(matcher, line)
                if newState:
                    self.state = newState
                    break
