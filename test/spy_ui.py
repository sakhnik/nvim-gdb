from pynvim import attach


class SpyUI:
    def __init__(self):
        self.nvim = attach('tcp', address='localhost', port=44444)
        self.width = 80
        self.height = 25
        self.cursor = (0, 0)
        self.nvim.ui_attach(self.width, self.height, True)
        self.grid = []
        for r in range(self.height):
            self.grid.append([' '] * self.width)
        self.screen = self.to_str()

    def run(self):
        self.nvim.run_loop(self._req, self._not)

    def close(self):
        self.nvim.stop_loop()

    def _req(self, name, arg):
        print("req", name)

    IGNORE_REDRAW = frozenset( \
            ("mode_info_set", "mode_change", "mouse_on", "mouse_off",
             "option_set", "default_colors_set", "hl_group_set", "hl_attr_define",
             "grid_cursor_goto", "busy_start", "busy_stop",
             "update_fg", "update_bg", "update_sp", "highlight_set",
             "win_viewport"
             )
            )

    def _not(self, name, args):
        if name == "redraw":
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
                    pass
                else:
                    print(cmd, par)
        else:
            print(name, args)

    def _resize(self, width, height):
        new_grid = []
        for r in range(height):
            new_grid.append([' '] * width)
        for r in range(min(self.height, height)):
            for c in range(min(self.width, width)):
                new_grid[r][c] = self.grid[r][c]
        self.grid = new_grid
        self.width = width
        self.height = height

    def _clear(self):
        for r in range(self.height):
            for c in range(self.width):
                self.grid[r][c] = ' '

    def _eol_clear(self):
        row, col = self.cursor
        for c in range(col, self.width):
            self.grid[row][c] = ' '

    def _cursor_goto(self, row, col):
        self.cursor = (row, col)

    def _put(self, text):
        row, col = self.cursor
        r = self.grid[row]
        for i in range(len(text)):
            r[col + i] = text[i][0]
        self.cursor = (row, col + len(text))

    def _set_scroll_region(self, top, bot, left, right):
        self.scroll_region = (top, bot, left, right)

    def _scroll(self, rows):
        top, bot, left, right = self.scroll_region
        if rows > 0:
            for r in range(top, bot - rows):
                rfrom = r + rows
                for c in range(left, right):
                    self.grid[r][c] = self.grid[rfrom][c]
        else:
            for r in range(bot - 1, top - rows - 1, -1):
                rfrom = r + rows
                for c in range(left, right):
                    self.grid[r][c] = self.grid[rfrom][c]

    def to_str(self):
        lines = []
        lines.append("+" + "-" * self.width + "+")
        for r in range(len(self.grid)):
            lines.append('|' + ''.join(self.grid[r]) + '|')
        lines.append("+" + "-" * self.width + "+")
        return "\n".join(lines)

    def _print(self):
        print("")
        print(self.to_str())


if __name__ == "__main__":
    SpyUI().run()
