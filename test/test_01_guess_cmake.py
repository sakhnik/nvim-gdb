
import time
import pytest
import config
import subprocess

def ExecutablesOfBuffer(path):
    return "guess_executable_cmake#ExecutablesOfBuffer('" + path + "')"

def test_cmake_completion(eng):
    subprocess.run(["cmake", "src", "-B", "src/build"])
    eng.exe("cd src")
    eng.exe("e test.cpp")

    test_exec = [['build/cmake_test_exec']]

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
