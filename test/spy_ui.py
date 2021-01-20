"""A UI client for neovim used to fetch screen logs for testing."""

from pynvim import attach


class SpyUI:
    """Spy UI is a UI client for neovim.

    It will attach to a running instance of neovim and capture its screen.
    """

    def __init__(self):
        """Constructor."""
        self.nvim = attach('tcp', address='localhost', port=44444)
        self.width = 80
        self.height = 25
        # Cursor row and col
        self.row = 0
        self.col = 0
        self.scroll_region = (0, 0, 0, 0)
        self.nvim.ui_attach(self.width, self.height, True)
        self.grid = []
        for _ in range(self.height):
            self.grid.append([' '] * self.width)
        self.screen = self.to_str()

    def run(self):
        """Run the loop."""
        def _req(name, arg):
            print("req", name, arg)
        self.nvim.run_loop(_req, self._not)

    def close(self):
        """Break from the UI loop."""
        self.nvim.stop_loop()

    IGNORE_REDRAW = frozenset(
            ("mode_info_set", "mode_change", "mouse_on", "mouse_off",
             "option_set", "default_colors_set",
             "hl_group_set", "hl_attr_define",
             "grid_cursor_goto", "busy_start", "busy_stop",
             "update_fg", "update_bg", "update_sp", "highlight_set",
             "win_viewport"
             )
            )

    def _not(self, name, args):
        if name == "redraw":
            self._redraw(args)
        else:
            print(name, args)

    def _redraw(self, args):
        for arg in args:
            cmd = arg[0]
            par = arg[1]
            if cmd in self.IGNORE_REDRAW:
                continue
            if cmd == "resize":
                self._resize(*par)
            elif cmd == "clear":
                self._clear()
            elif cmd == "eol_clear":
                self._eol_clear()
            elif cmd == "cursor_goto":
                self._cursor_goto(*par)
            elif cmd == "put":
                self._put(arg[1:])
            elif cmd == "set_scroll_region":
                self._set_scroll_region(*par)
            elif cmd == "scroll":
                self._scroll(*par)
            elif cmd == "flush":
                self.screen = self.to_str()
                # self._print()
            else:
                print(cmd, par)

    def _resize(self, width, height):
        new_grid = []
        for _ in range(height):
            new_grid.append([' '] * width)
        for row in range(min(self.height, height)):
            for col in range(min(self.width, width)):
                new_grid[row][col] = self.grid[row][col]
        self.grid = new_grid
        self.width = width
        self.height = height

    def _clear(self):
        for row in range(self.height):
            for col in range(self.width):
                self.grid[row][col] = ' '

    def _eol_clear(self):
        for col in range(self.col, self.width):
            self.grid[self.row][col] = ' '

    def _cursor_goto(self, row, col):
        self.row = row
        self.col = col

    def _put(self, text):
        text_row = self.grid[self.row]
        for col, char in enumerate(text):
            text_row[self.col + col] = char[0]
        self.col += len(text)

    def _set_scroll_region(self, top, bot, left, right):
        self.scroll_region = (top, bot, left, right)

    def _scroll(self, rows):
        top, bot, left, right = self.scroll_region
        if rows > 0:
            for row in range(top, bot - rows):
                rfrom = row + rows
                for col in range(left, right):
                    self.grid[row][col] = self.grid[rfrom][col]
        else:
            for row in range(bot - 1, top - rows - 1, -1):
                rfrom = row + rows
                for col in range(left, right):
                    self.grid[row][col] = self.grid[rfrom][col]

    def to_str(self):
        """Render the grid into a string."""
        lines = []
        lines.append("+" + "-" * self.width + "+")
        for row in self.grid:
            lines.append('|' + ''.join(row) + '|')
        lines.append("+" + "-" * self.width + "+")
        return "\n".join(lines)

    def _print(self):
        print("")
        print(self.to_str())


if __name__ == "__main__":
    SpyUI().run()
