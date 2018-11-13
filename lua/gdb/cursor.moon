fmt = string.format

class Cursor
    new: =>
        @buf = -1
        @line = -1
        @sign_id = 4999

    hide: =>
        V.exe ('sign unplace ' .. @sign_id)

    show: =>
        -- to avoid flicker when removing/adding the sign column(due to the change in
        -- line width), we switch ids for the line sign and only remove the old line
        -- sign after marking the new one
        old_sign_id = @sign_id
        @sign_id = 4999 + 4998 - old_sign_id
        if @line != -1 and buf != -1
            V.exe fmt('sign place %d name=GdbCurrentLine line=%d buffer=%d',
                @sign_id, @line, @buf)
        V.exe ('sign unplace ' .. old_sign_id)

    set: (buf, line) =>
        @buf = buf
        @line = line

Cursor
