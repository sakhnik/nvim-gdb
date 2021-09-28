
import time
import pytest
import config

test_exec = []
if "cmake" in config.BACKEND_NAMES:
    test_exec = ['build/cmake_test_exec']
    

def test_cmake_completion(eng):
    eng.exe("cd src")
    eng.exe("e test.cpp")

    execs = eng.eval("ExecsCompletion('../','','')")
    assert(execs == test_exec+['../a.out'])

    eng.exe("bd")
    eng.exe("cd ../")
