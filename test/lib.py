'''.'''


def _factorial(num):
    if num <= 1:
        return 1
    return num * _factorial(num - 1)
