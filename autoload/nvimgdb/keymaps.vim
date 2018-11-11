
" Default configuration
let s:default_config = {
  \ 'key_until': '<f4>',
  \ 'key_continue': '<f5>',
  \ 'key_next': '<f10>',
  \ 'key_step': '<f11>',
  \ 'key_finish': '<f12>',
  \ 'key_breakpoint': '<f8>',
  \ 'key_frameup': '<c-p>',
  \ 'key_framedown': '<c-n>',
  \ 'key_eval': '<f9>',
  \ 'set_tkeymaps': function('nvimgdb#keymaps#SetT'),
  \ 'set_keymaps': function('nvimgdb#keymaps#Set'),
  \ 'unset_keymaps': function('nvimgdb#keymaps#Unset'),
  \ }

let s:default_keymaps = [
  \ ['n', 'key_until', ':GdbUntil'],
  \ ['n', 'key_continue', ':GdbContinue'],
  \ ['n', 'key_next', ':GdbNext'],
  \ ['n', 'key_step', ':GdbStep'],
  \ ['n', 'key_finish', ':GdbFinish'],
  \ ['n', 'key_breakpoint', ':GdbBreakpointToggle'],
  \ ['n', 'key_frameup', ':GdbFrameUp'],
  \ ['n', 'key_framedown', ':GdbFrameDown'],
  \ ['n', 'key_eval', ':GdbEvalWord'],
  \ ['v', 'key_eval', ':GdbEvalRange'],
  \ ]

function! nvimgdb#keymaps#Set()
  for keymap in s:default_keymaps
    if has_key(t:gdb_keymaps_config, keymap[1])
      let key = t:gdb_keymaps_config[keymap[1]]
      if !empty(key)
        exe keymap[0] . 'noremap <buffer> <silent> ' . key . ' ' . keymap[2]'<cr>'
      endif
    endif
  endfor
endfunction

function! nvimgdb#keymaps#Unset()
  for keymap in s:default_keymaps
    if has_key(t:gdb_keymaps_config, keymap[1])
      let key = t:gdb_keymaps_config[keymap[1]]
      if !empty(key)
        exe keymap[0] . 'unmap <buffer> ' . key
      endif
    endif
  endfor
endfunction

let s:default_tkeymaps = [
  \ ['key_until', ':GdbUntil'],
  \ ['key_continue', ':GdbContinue'],
  \ ['key_next', ':GdbNext'],
  \ ['key_step', ':GdbStep'],
  \ ['key_finish', ':GdbFinish'],
  \ ]

function! nvimgdb#keymaps#SetT()
  " Set term-local key maps
  for keymap in s:default_tkeymaps
    if has_key(t:gdb_keymaps_config, keymap[0])
      let key = t:gdb_keymaps_config[keymap[0]]
      if !empty(key)
        exe 'tnoremap <buffer> <silent> ' . key . ' <c-\><c-n>' . keymap[1] . '<cr>i'
      endif
    endif
  endfor
  tnoremap <silent> <buffer> <esc> <c-\><c-n>
endfunction

function! nvimgdb#keymaps#DispatchSet()
  if !exists("t:gdb_keymaps_config") | return | endif
  try
    call t:gdb_keymaps_config['set_keymaps']()
  catch /.*/
  endtry
endfunction

function! nvimgdb#keymaps#DispatchUnset()
  if !exists("t:gdb_keymaps_config") | return | endif
  try
    call t:gdb_keymaps_config['unset_keymaps']()
  catch /.*/
  endtry
endfunction

function! nvimgdb#keymaps#DispatchSetT()
  if !exists("t:gdb_keymaps_config") | return | endif
  try
    call t:gdb_keymaps_config['set_tkeymaps']()
  catch /.*/
  endtry
endfunction

function! nvimgdb#keymaps#Init()
  " Make a copy of the supplied configuration if defined
  if exists('g:nvimgdb_config')
    let config = copy(g:nvimgdb_config)
  else
    let config = copy(s:default_config)
  endif

  " If there is config override defined, add it
  if exists('g:nvimgdb_config_override')
    call extend(config, g:nvimgdb_config_override)
  endif

  " See whether a global override for a specific configuration
  " key exists. If so, update the config.
  for key in keys(config)
    let varname = 'g:nvimgdb_' . key
    if exists(varname)
      let config[key] = eval(varname)
    endif
  endfor

  " Return the resulting configuration
  let t:gdb_keymaps_config = config
endfunction
