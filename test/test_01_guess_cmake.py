
import time
import pytest
import config

def ExecutablesOfBuffer(path):
    return "guess_executable_cmake#ExecutablesOfBuffer('" + path + "')"

if "cmake" not in config.BACKEND_NAMES:
    pytest.skip("skipping bashdb tests", allow_module_level=True)

def test_cmake_completion(eng):
    eng.exe("cd src")
    eng.exe("e test.cpp")

    test_exec = ['build/cmake_test_exec']

    execs = eng.eval(ExecutablesOfBuffer(''))
    assert(execs == test_exec)

    execs = eng.eval(ExecutablesOfBuffer('bu'))
    assert(execs == test_exec)

    execs = eng.eval(ExecutablesOfBuffer('./bu'))
    assert(execs == test_exec)

    execs = eng.eval(ExecutablesOfBuffer('./build/'))
    assert(execs == test_exec)

    execs = eng.eval(ExecutablesOfBuffer('./build/cm'))
    assert(execs == test_exec)

    execs = eng.eval(ExecutablesOfBuffer('./../src/build/cm'))
    assert(execs == test_exec)

    eng.exe("bd")
    eng.exe("cd ../")
