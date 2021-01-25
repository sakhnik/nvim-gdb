-- BashDB specifics
-- vim: set et ts=2 sw=2:

c = {}

function c.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  return {[[%m\ in\ file\ `%f'\ at\ line\ %l]],
          [[%m\ called\ from\ file\ `%f'\ at\ line\ %l]],
          [[%m\ %f:%l]]}

  -- bashdb<18> bt
  -- ->0 in file `main.sh' at line 8
  -- ##1 Foo("1") called from file `main.sh' at line 18
  -- ##2 Main() called from file `main.sh' at line 22
  -- ##3 source("main.sh") called from file `/sbin/bashdb' at line 107
  -- ##4 main("main.sh") called from file `/sbin/bashdb' at line 0
  -- bashdb<22> info breakpoints
  -- Num Type       Disp Enb What
  -- 1   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:16
  --         breakpoint already hit 1 time
  -- 2   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:7
  --         breakpoint already hit 1 time
  -- 3   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:3
  -- 4   breakpoint keep y   /tmp/nvim-gdb/test/main.sh:8
end

return c
