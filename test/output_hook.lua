local H = {}

H.result = require'result'
H.tcp_client = nil


function H.init()
  H.result.test_output = {}
  H.result.failures = 0

  if require'config'.send_output_to_tcp then
    local uv = vim.loop
    local client = uv.new_tcp()
    client:nodelay(true)
    client:connect("127.0.0.1", 11111, function(err)
      assert(not err, err)
      H.tcp_client = client
    end)
    assert(vim.wait(1000, function() return H.tcp_client ~= nil end), "Failed to connect")
  end
end

function H.write(...)
  for _, msg in ipairs({...}) do
    table.insert(H.result.test_output, msg)
    if H.tcp_client ~= nil then
      H.tcp_client:write(msg, function(err)
        assert(not err, err)
      end)
    end
  end
end

function H.flush()
end

return H
