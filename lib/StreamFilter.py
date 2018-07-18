#!/usr/bin/env python3

class BaseMatcher:
    def match(self, ch):
        return self

class StringMatcher(BaseMatcher):
    def __init__(self, s, hold, succeed, fail):
        self.s = s
        self.hold = hold
        self.succeed = succeed
        self.fail = fail
        self.idx = 0

    def match(self, ch):
        if self.s[idx] == ch:
            ++self.idx
            if self.idx == len(self.s):
                self.idx = 0
                return succeed
            return hold
        self.idx = 0
        return fail

class StreamFilter:
    def __init__(self):
        self.state = []
        self.state.append(StringMatcher('\n(gdb) server nvim-gdb-', 0, 1, -1))
        self.state.append(StringMatcher('\n(gdb) ', 0, 1, -1))

    def Check(self, ch):
        return True
