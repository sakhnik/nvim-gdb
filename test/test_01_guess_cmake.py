
import time
import pytest
import config


def test_(eng):
    eng.exe("cd src")
    eng.exe("e test.cpp")
    execs = eng.eval("guess_executable_cmake#ExecutablesOfBuffer('')")
    assert(execs == [['build/cmake_test_exec']])

