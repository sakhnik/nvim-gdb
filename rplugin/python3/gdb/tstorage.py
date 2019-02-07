
class TStorage:
    def __init__(self, vim):
        self.vim = vim
        self.data = {}

    # Create a tabpage-specific table
    def init(self, val):
        self.data[self.vim.current.tabpage] = val

    # Access the table for the current page
    def get(self):
        return self.data[self.vim.current.tabpage]

    # Access the table for given page
    def getTab(self, tab):
        return self.data[tab]

    # Delete the tabpage-specific table
    def clear(self, tab):
        del(self.data[tab])
