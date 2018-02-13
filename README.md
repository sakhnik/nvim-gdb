# GDB for neovim

[Gdb](https://www.gnu.org/software/gdb/) and [LLDB](https://lldb.llvm.org/) integration with NeoVim.

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

[![nvim-gdb](https://asciinema.org/a/E8sKlS53Dm6UzK2MJjEolOyam.png)](https://asciinema.org/a/E8sKlS53Dm6UzK2MJjEolOyam?autoplay=1)

[![nvim-gdb + llvm](https://asciinema.org/a/162697.png)](https://asciinema.org/a/162697)

## Installation

If you use vim-plug, add the following line to your vimrc file:

```vim
Plug 'sakhnik/nvim-gdb'
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

## Usage

See `:help nvimgdb` for the complete online documentation. Most notable commands:

| Mapping          | Command                        | Description                                                   |
|------------------|--------------------------------|---------------------------------------------------------------|
| &lt;Leader&gt;dd | `:GdbStart gdb -q -f ./a.out`  | Start debugging session, allows editing the launching command |
| &lt;Leader&gt;dl | `:GdbStartLLDB lldb ./a.out`   | Start debugging session, allows editing the launching command |
| &lt;F8&gt;       | `:GdbToggleBreakpoint`         | Toggle breakpoint in the coursor line                         |
| &lt;F5&gt;       | `:GdbContinue`                 | Continue execution (`continue` in gdb)                        |
| &lt;F10&gt;      | `:GdbNext`                     | Step over the next statement (`next` in gdb)                  |
| &lt;F11&gt;      | `:GdbStep`                     | Step into the next statement (`step` in gdb)                  |
| &lt;F12&gt;      | `:GdbFinish`                   | Step out the current frame (`finish` in gdb)                  |
| &lt;c-p&gt;      | `:GdbFrameUp`                  | Navigate one frame up (`up` in gdb)                           |
| &lt;c-n&gt;      | `:GdbFrameDown`                | Navigate one frame down (`down` in gdb)                       |

## Development

The goal is to have a thin wrapper around
GDB and LLDB, just like the official
[TUI](https://sourceware.org/gdb/onlinedocs/gdb/TUI.html). NeoVim will enhance
debugging with syntax highlighting and source code navigation.
