 
Branch | Status | Description
-------| -------|------------
[master](https://github.com/sakhnik/nvim-gdb/tree/master) | [![Travis Build Status](https://travis-ci.org/sakhnik/nvim-gdb.svg?branch=master)](https://travis-ci.org/sakhnik/nvim-gdb) | Modern version implemented as a remote Python plugin
[moonscript](https://github.com/sakhnik/nvim-gdb/tree/moonscript) | [![Travis Build Status](https://travis-ci.org/sakhnik/nvim-gdb.svg?branch=moonscript)](https://travis-ci.org/sakhnik/nvim-gdb) | Experimental version implemented in Moonscript and some VimL
[legacy](https://github.com/sakhnik/nvim-gdb/tree/legacy) | [![Travis Build Status](https://travis-ci.org/sakhnik/nvim-gdb.svg?branch=legacy)](https://travis-ci.org/sakhnik/nvim-gdb) | The original version mostly in VimL and some Python

# GDB for neovim

[Gdb](https://www.gnu.org/software/gdb/), [LLDB](https://lldb.llvm.org/)
and [PDB](https://docs.python.org/3/library/pdb.html) integration with NeoVim.

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

[![nvim-gdb](https://asciinema.org/a/E8sKlS53Dm6UzK2MJjEolOyam.png)](https://asciinema.org/a/E8sKlS53Dm6UzK2MJjEolOyam?autoplay=1)

## Installation

Check the prerequisites in the script [test/prerequisites.sh](https://github.com/sakhnik/nvim-gdb/blob/master/test/prerequisites.sh).

If you use vim-plug, add the following line to your vimrc file for the mainstream version:

```vim
Plug 'sakhnik/nvim-gdb', { 'do': ':!./install.sh \| UpdateRemotePlugins' }
```

or for the original VimL version:

```vim
Plug 'sakhnik/nvim-gdb', { 'branch': 'legacy' }
```

You can use any other plugin manager too:

  - vundle
  - neobundle
  - pathogen

## Options

To disable the plugin
```vim
let g:loaded_nvimgdb = 1
```

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

| Mapping          | Command                        | Description                                                   |
|------------------|--------------------------------|---------------------------------------------------------------|
| &lt;Leader&gt;dd | `:GdbStart gdb -q ./a.out`     | Start debugging session, allows editing the launching command |
| &lt;Leader&gt;dl | `:GdbStartLLDB lldb ./a.out`   | Start debugging session, allows editing the launching command |
| &lt;Leader&gt;dp | `:GdbStartPDB python -m pdb main.py`   | Start Python debugging session, allows editing the launching command |
| &lt;F8&gt;       | `:GdbBreakpointToggle`         | Toggle breakpoint in the coursor line                         |
| &lt;F4&gt;       | `:GdbUntil`                    | Continue execution until a given line (`until` in gdb)        |
| &lt;F5&gt;       | `:GdbContinue`                 | Continue execution (`continue` in gdb)                        |
| &lt;F10&gt;      | `:GdbNext`                     | Step over the next statement (`next` in gdb)                  |
| &lt;F11&gt;      | `:GdbStep`                     | Step into the next statement (`step` in gdb)                  |
| &lt;F12&gt;      | `:GdbFinish`                   | Step out the current frame (`finish` in gdb)                  |
| &lt;c-p&gt;      | `:GdbFrameUp`                  | Navigate one frame up (`up` in gdb)                           |
| &lt;c-n&gt;      | `:GdbFrameDown`                | Navigate one frame down (`down` in gdb)                       |

## Development

The goal is to have a thin wrapper around
GDB, LLDB and PDB, just like the official
[TUI](https://sourceware.org/gdb/onlinedocs/gdb/TUI.html). NeoVim will enhance
debugging with syntax highlighting and source code navigation.

## References

* Porting to Moonscript: [2018-11-17](https://sakhnik.com/2018/11/17/nvimgdb-lua.html)
* Overview to the first anniversary: [2018-08-10](https://sakhnik.com/2018/08/10/nvim-gdb-anni.html)

## Showcase

[![nvim-gdb + llvm](https://asciinema.org/a/162697.png)](https://asciinema.org/a/162697)

[![clone + deploy + test](https://asciinema.org/a/218569.svg)](https://asciinema.org/a/218569)
