local eng = require'engine'
local utils = require'nvimgdb.utils'
local conftest = require'conftest'

local function check_skip()
  if conftest.backend_names.cmake == nil then
    pending("CMake not configured")
  end
  if utils.is_windows then
    pending("CMake tests aren't supported in Windows")
  end
end

describe("cmake", function()
  setup(function()
    eng.exe("cd src")
    eng.exe("e test.cpp")
  end)

  teardown(function()
    eng.exe("bw!")
    eng.exe("cd ..")
  end)

  it("guess", function()
    check_skip()
    local test_exec = {['build/cmake_test_exec'] = true}
    local executables_of_buffer = require'nvimgdb.cmake'.executables_of_buffer
    local execs = executables_of_buffer('')
    assert.are.same(test_exec, execs)
    execs = executables_of_buffer('bu')
    assert.are.same(test_exec, execs)
    execs = executables_of_buffer('./bu')
    assert.are.same(test_exec, execs)
    execs = executables_of_buffer('./build/')
    assert.are.same(test_exec, execs)
    execs = executables_of_buffer('./build/cm')
    assert.are.same(test_exec, execs)
    execs = executables_of_buffer('./../src/build/cm')
    assert.are.same(test_exec, execs)
  end)

  it("find executables", function()
    local execs = require'nvimgdb.cmake'.find_executables('../')
    assert.are.same({['../' .. conftest.aout] = true}, execs)
  end)

  it("get executables", function()
    check_skip()
    local execs = require'nvimgdb.cmake'.get_executables('../')
    assert.are.same({'build/cmake_test_exec', '../a.out'}, execs)
  end)
end)


