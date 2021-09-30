import time
import pytest
import config

test_exec = []
if "cmake" in config.BACKEND_NAMES:
    test_exec = ['build/cmake_test_exec']
    

def test_cmake_completion(eng, cd_to_cmake):
    execs = eng.eval("ExecsCompletion('../','','')")
    assert(execs == test_exec+['../a.out'])

    assert cd_to_cmake
