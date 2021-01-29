local C = {}

C.command_map = {}

-- Adapt command if necessary.
function C:translate_command(command)
  cmd = self.command_map[command]
  if cmd ~= nil then
    return cmd
  end
  return command
end

return C
