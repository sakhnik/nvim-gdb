 
Branch | Status | Description
-------| -------|------------
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

[![nvim-gdb + llvm](https://asciinema.org/a/162697.png)](https://asciinema.org/a/162697)

## Installation

If you use vim-plug, add the following line to your vimrc file:

```vim
Plug 'sakhnik/nvim-gdb', { 'branch': 'legacy' }
```

Or use any other plugin manager:

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
let g:nvimgdb_config_override = {
  \ 'key_next': 'n',
  \ 'key_step': 's',
  \ 'key_finish': 'f',
  \ 'key_continue': 'c',
  \ 'key_until': 'u',
  \ 'key_breakpoint': 'b',
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

* Overview to the first anniversary: [sakhnik.com](https://sakhnik.com/2018/08/10/nvim-gdb-anni.html)
