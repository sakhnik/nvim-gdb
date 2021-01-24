-- Manipulate keymaps: define and undefined when needed.

local C = {}
C.__index = C

-- Keymaps manager.
function C.new(config)
    local self = setmetatable({}, C)
    self.config = config
    self.dispatch_active = true
    return self
end

function C.set_dispatch_active(self, state)
    -- Turn on/off keymaps manipulation.
    self.dispatch_active = state
end

local default = {
    {'n', 'key_until', ':GdbUntil'},
    {'n', 'key_continue', ':GdbContinue'},
    {'n', 'key_next', ':GdbNext'},
    {'n', 'key_step', ':GdbStep'},
    {'n', 'key_finish', ':GdbFinish'},
    {'n', 'key_breakpoint', ':GdbBreakpointToggle'},
    {'n', 'key_frameup', ':GdbFrameUp'},
    {'n', 'key_framedown', ':GdbFrameDown'},
    {'n', 'key_eval', ':GdbEvalWord'},
    {'v', 'key_eval', ':GdbEvalRange'},
    {'n', 'key_quit', ':GdbDebugStop'},
}

function C.set(self)
    -- Set buffer-local keymaps.
    for _, tuple in ipairs(default) do
        mode, key, cmd = unpack(tuple)
        keystroke = self.config:get(key)
        if keystroke ~= nil then
            vim.api.nvim_buf_set_keymap(vim.api.nvim_get_current_buf(), mode,
                keystroke, cmd .. '<cr>', {['silent'] = true})
        end
    end
end

function C.unset(self)
    -- Unset buffer-local keymaps.
    for _, tuple in ipairs(default) do
        mode, key = unpack(tuple)
        keystroke = self.config:get(key)
        if keystroke ~= nil then
            vim.api.nvim_buf_del_keymap(vim.api.nvim_get_current_buf(), mode, keystroke)
        end
    end
end

local default_t = {
    {'key_until', ':GdbUntil'},
    {'key_continue', ':GdbContinue'},
    {'key_next', ':GdbNext'},
    {'key_step', ':GdbStep'},
    {'key_finish', ':GdbFinish'},
    {'key_quit', ':GdbDebugStop'},
}

function C.set_t(self)
    -- Set term-local keymaps.
    for _, tuple in ipairs(default_t) do
        key, cmd = unpack(tuple)
        keystroke = self.config:get(key)
        if keystroke ~= nil then
            vim.api.nvim_buf_set_keymap(vim.api.nvim_get_current_buf(), 't',
                keystroke, [[<c-\><c-n>]] .. cmd .. [[<cr>i]], {['silent'] = true})
        end
    end
    vim.api.nvim_buf_set_keymap(vim.api.nvim_get_current_buf(), 't',
        '<esc>', [[<c-\><c-n>G]], {['silent'] = true})
end

function C._dispatch(self, key)
    if self.dispatch_active then
        self.config:get_or(key, function(_) end)(self)
    end
end

function C.dispatch_set(self)
    -- Call the hook to set the keymaps.
    self._dispatch 'set_keymaps'
end

function C.dispatch_unset(self)
    -- Call the hook to unset the keymaps.
    self._dispatch 'unset_keymaps'
end

function C.dispatch_set_t(self)
    -- Call the hook to set the terminal keymaps.
    self._dispatch 'set_tkeymaps'
end

return C
