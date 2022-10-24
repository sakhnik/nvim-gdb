 
[![Test](https://github.com/sakhnik/nvim-gdb/workflows/Test/badge.svg?branch=master)](https://github.com/sakhnik/nvim-gdb/actions?query=workflow%3ATest+branch%3Amaster)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/f2a7dc2640f84b2a8983ac6da004c7ac)](https://www.codacy.com/app/sakhnik/nvim-gdb?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=sakhnik/nvim-gdb&amp;utm_campaign=Badge_Grade)

# GDB for neovim

[Gdb](https://www.gnu.org/software/gdb/), [LLDB](https://lldb.llvm.org/),
[pdb](https://docs.python.org/3/library/pdb.html)/[pdb++](https://github.com/pdbpp/pdbpp)
and [BASHDB](http://bashdb.sourceforge.net/) integration with NeoVim.

## Table of contents

  * [Overview](#overview)
  * [Installation](#installation)
  * [Options](#options)
  * [Usage](#usage)
  * [Development](#development)

## Overview

Taken from the neovim: [neovim\_gdb.vim](https://github.com/neovim/neovim/blob/master/contrib/gdb/neovim_gdb.vim)

It is instantly usable: type `<leader>dd`, edit GDB launching command, hit `<cr>`.
Or type `<leader>dl` to do the same with LLDB backend.
Or type `<leader>dp` to start debugging a python program.
Or type `<leader>db` to start debugging a BASH script.

Also you can record the execution of a program with [`rr record`](https://rr-project.org/), and then replay its execution systematically with `<leader>dr`.

[![nvim-gdb](https://asciinema.org/a/E8sKlS53Dm6UzK2MJjEolOyam.png)](https://asciinema.org/a/E8sKlS53Dm6UzK2MJjEolOyam?autoplay=1)

## Installation

Check the prerequisites in the script [test/prerequisites.sh](https://github.com/sakhnik/nvim-gdb/blob/master/test/prerequisites.sh).

Use the branch `master` for NeoVim ≥ 0.7 or the branch `devel` to benefit from the latest NeoVim features.

If you use vim-plug, add the following line to your vimrc file:

```vim
Plug 'sakhnik/nvim-gdb', { 'do': ':!./install.sh' }
```

You can use any other plugin manager too:

  * vundle
  * neobundle
  * pathogen

## Options

To disable the plugin
```vim
let g:loaded_nvimgdb = 1
```

`:GdbStart` and `:GdbStartLLDB` use `find` and the cmake file API to try to
tab-complete the command with the executable for the current file. To disable
this set `g:nvimgdb_use_find_executables` or `g:nvimgdb_use_cmake_to_find_executables` to `0`.

The behaviour of the plugin can be tuned by defining specific variables.
For instance, you could overload some command keymaps:
```vim
" We're going to define single-letter keymaps, so don't try to define them
" in the terminal window.  The debugger CLI should continue accepting text commands.
function! NvimGdbNoTKeymaps()
  tnoremap <silent> <buffer> <esc> <c-\><c-n>
endfunction

let g:nvimgdb_config_override = {
  \ 'key_next': 'n',
  \ 'key_step': 's',
  \ 'key_finish': 'f',
  \ 'key_continue': 'c',
  \ 'key_until': 'u',
  \ 'key_breakpoint': 'b',
  \ 'set_tkeymaps': "NvimGdbNoTKeymaps",
  \ }
```

Likewise, you could define your own hooks to be called when the source window
is entered and left. Please refer to the online NeoVim help: `:help nvimgdb`.

## Usage

See `:help nvimgdb` for the complete online documentation. Most notable commands:

| Mapping          | Command                              | Description                                                          |
|------------------|--------------------------------------|----------------------------------------------------------------------|
| &lt;Leader&gt;dd | `:GdbStart gdb -q ./a.out`           | Start debugging session, allows editing the launching command        |
| &lt;Leader&gt;dl | `:GdbStartLLDB lldb ./a.out`         | Start debugging session, allows editing the launching command        |
| &lt;Leader&gt;dp | `:GdbStartPDB python -m pdb main.py` | Start Python debugging session, allows editing the launching command |
| &lt;Leader&gt;db | `:GdbStartBashDB bashdb main.sh`     | Start BASH debugging session, allows editing the launching command   |
| &lt;Leader&gt;dr | `:GdbStartRR`                        | Start debugging session with [`rr replay`](https://rr-project.org/). |
| &lt;F8&gt;       | `:GdbBreakpointToggle`               | Toggle breakpoint in the coursor line                                |
| &lt;F4&gt;       | `:GdbUntil`                          | Continue execution until a given line (`until` in gdb)               |
| &lt;F5&gt;       | `:GdbContinue`                       | Continue execution (`continue` in gdb)                               |
| &lt;F10&gt;      | `:GdbNext`                           | Step over the next statement (`next` in gdb)                         |
| &lt;F11&gt;      | `:GdbStep`                           | Step into the next statement (`step` in gdb)                         |
| &lt;F12&gt;      | `:GdbFinish`                         | Step out the current frame (`finish` in gdb)                         |
| &lt;c-p&gt;      | `:GdbFrameUp`                        | Navigate one frame up (`up` in gdb)                                  |
| &lt;c-n&gt;      | `:GdbFrameDown`                      | Navigate one frame down (`down` in gdb)                              |

You can create a watch window evaluating a backend command on every step.
Try `:GdbCreateWatch info locals` in GDB, for istance.

You can open the list of breakpoints or backtrace locations into the location list.
Try `:GdbLopenBacktrace` or `:GdbLopenBreakpoints`.

## Development

The goal is to have a thin wrapper around
GDB, LLDB, pdb/pdb++ and BASHDB, just like the official
[TUI](https://sourceware.org/gdb/onlinedocs/gdb/TUI.html). NeoVim will enhance
debugging with syntax highlighting and source code navigation.

The project uses GitHub actions to run the test suite on every commit automatically.
The plugin, proxy and screen logs can be downloaded as the artifacts to be analyzed
locally.

To ease reproduction of an issue, set the environment variable `CI`, and
launch NeoVim with the auxiliary script `test/nvim`. The screen cast will
be written to the log file `spy_ui.log`. Alternatively, consider recording
the terminal script with the ubiquitous command `script`.

To support development, consider donating:

  * ₿ [1E5Sny3tC5qdr1owAQqbzfyq1SFjaNBQW4](https://bitref.com/1E5Sny3tC5qdr1owAQqbzfyq1SFjaNBQW4)

## References

  * Porting to Moonscript: [2018-11-17](https://sakhnik.com/2018/11/17/nvimgdb-lua.html)
  * Overview to the first anniversary: [2018-08-10](https://sakhnik.com/2018/08/10/nvim-gdb-anni.html)

## Showcase

[![GdbStartRR](https://asciinema.org/a/506942.svg)](https://asciinema.org/a/506942)

[![nvim-gdb + llvm](https://asciinema.org/a/162697.png)](https://asciinema.org/a/162697)

[![clone + test](https://asciinema.org/a/397047.svg)](https://asciinema.org/a/397047)
