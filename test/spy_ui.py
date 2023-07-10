"""A UI client for neovim used to fetch screen logs for testing."""

import logging
import os
from pynvim import attach


class SpyUI:
    """Spy UI is a UI client for neovim.

    It will attach to a running instance of neovim and capture its screen.
    """

    def __init__(self, width=80, height=25):
        """Constructor."""
        self.logger = logging.getLogger("SpyUI")
        self.logger.setLevel(logging.DEBUG)
        lhandl = logging.NullHandler() if not os.environ.get('CI') \
            else logging.FileHandler("spy_ui.log")
        fmt = "%(asctime)s [%(levelname)s]: %(message)s"
        lhandl.setFormatter(logging.Formatter(fmt))
        self.logger.addHandler(lhandl)

        self.nvim = attach('tcp', address='localhost', port=44444)
        self.width = int(width)
        self.height = int(height)
        self.logger.info("Starting SpyUI %dx%d", self.width, self.height)
        self.nvim.ui_attach(self.width, self.height, rgb=True,
                            ext_linegrid=True)
        self.grid = []
        for _ in range(self.height):
            self.grid.append([' '] * self.width)
        self.screen = self.to_str()

    def run(self):
        """Run the loop."""
        def _req(name, arg):
            # print("req", name, arg, file=sys.stderr)
            pass
        self.nvim.run_loop(_req, self._not)

    def close(self):
        """Break from the UI loop."""
        self.nvim.stop_loop()

    IGNORE_REDRAW = frozenset(
            ("mode_info_set", "mode_change", "mouse_on", "mouse_off",
             "option_set", "default_colors_set",
             "hl_group_set", "hl_attr_define",
             "cursor_goto", "grid_cursor_goto", "busy_start", "busy_stop",
             "update_fg", "update_bg", "update_sp", "highlight_set",
             "win_viewport"
             )
            )

    def _not(self, name, args):
        if name == "redraw":
            self._redraw(args)
        else:
            # print(name, args, file=sys.stderr)
            pass

    def _redraw(self, args):
        for arg in args:
            cmd = arg[0]

            def for_each_param(handler):
                for i in range(1, len(arg)):
                    handler(*arg[i])

            par = arg[1]
            if cmd in self.IGNORE_REDRAW:
                continue
            if cmd == "grid_resize":
                for_each_param(self._grid_resize)
            elif cmd == "grid_clear":
                for_each_param(self._grid_clear)
            elif cmd == "grid_line":
                for_each_param(self._grid_line)
            elif cmd == "grid_scroll":
                for_each_param(self._grid_scroll)
            elif cmd == "flush":
                screen = self.to_str()
                if screen != self.screen:
                    # print(screen)
                    self.logger.info("\n%s", self.screen)
                    self.screen = screen
            else:
                # print(cmd, par, file=sys.stderr)
                pass

    def _grid_resize(self, gr, width, height):
        assert gr == 1
        new_grid = []
        for _ in range(height):
            new_grid.append([' '] * width)
        for row in range(min(self.height, height)):
            for col in range(min(self.width, width)):
                new_grid[row][col] = self.grid[row][col]
        self.grid = new_grid
        self.width = width
        self.height = height

    def _grid_clear(self, gr):
        assert gr == 1
        for row in range(self.height):
            for col in range(self.width):
                self.grid[row][col] = ' '

    def _grid_line(self, gr, row, col, cells):
        assert gr == 1
        for cell in cells:
            text = cell[0]
            repeat = 1
            if len(cell) > 2:
                repeat = int(cell[2])
            for i in range(repeat):
                self.grid[row][col + i] = text
            col += repeat

    def _grid_scroll(self, gr, top, bot, left, right, rows, cols):
        assert gr == 1
        assert cols == 0
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


if __name__ == "__main__":
    width = os.environ.get("COLUMNS")
    if not width:
        width = 80
    height = os.environ.get("LINES")
    if not height:
        height = 25
    SpyUI(width=width, height=height).run()
