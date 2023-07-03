import pytest
import config


def ExecutablesOfBuffer(path):
    return "guess_executable_cmake#ExecutablesOfBuffer('" + path + "')"


if "cmake" not in config.BACKEND_NAMES:
    pytest.skip("skipping cmake tests", allow_module_level=True)


def test_cmake_completion(eng, cd_to_cmake):

    test_exec = ['build/cmake_test_exec']

    execs = eng.eval(ExecutablesOfBuffer(''))
    assert execs == test_exec

    execs = eng.eval(ExecutablesOfBuffer('bu'))
    assert execs == test_exec

    execs = eng.eval(ExecutablesOfBuffer('./bu'))
    assert execs == test_exec

    execs = eng.eval(ExecutablesOfBuffer('./build/'))
    assert execs == test_exec

    execs = eng.eval(ExecutablesOfBuffer('./build/cm'))
    assert execs == test_exec

    execs = eng.eval(ExecutablesOfBuffer('./../src/build/cm'))
    assert execs == test_exec

    assert cd_to_cmake
