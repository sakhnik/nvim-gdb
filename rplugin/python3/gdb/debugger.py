'''Base class for all debugger specific responsibilities.'''


from gdb.common import Common


class Debugger(Common):
    '''Base class for all debugger specific responsibilities.'''

    def __init__(self, common, parser, client):
        super().__init__(common)
        self.parser = parser
        self.client = client

    def configure_parser(self):
        '''The method to override to configure the parser'''

    def delete_breakpoint(self, breakp):
        '''By default, this simply sends a line of text to the debugger.
        Override this in a subclass to provide more integrated functionality'''
        del_br = self.parser.command_map["delete_breakpoints"]
        self.client.send_line(f"{del_br} {breakp}")
