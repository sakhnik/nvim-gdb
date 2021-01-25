-- PDB specifics
-- vim: set et ts=2 sw=2:

c = {}

function c.get_error_formats()
  -- Return the list of errorformats for backtrace, breakpoints.
  return {[[%m\ at\ %f:%l]], [[%[>\ ]%#%f(%l)%m]]}

  -- (Pdb) break
  -- Num Type         Disp Enb   Where
  -- 1   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:14
  -- 2   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:4
  -- (Pdb) bt
  --   /usr/lib/python3.9/bdb.py(580)run()
  -- -> exec(cmd, globals, locals)
  --   <string>(1)<module>()
  --   /tmp/nvim-gdb/test/main.py(22)<module>()
  -- -> _main()
  --   /tmp/nvim-gdb/test/main.py(16)_main()
  -- -> _foo(i)
  --   /tmp/nvim-gdb/test/main.py(11)_foo()
  -- -> return num + _bar(num - 1)
  -- > /tmp/nvim-gdb/test/main.py(5)_bar()
end

return c
