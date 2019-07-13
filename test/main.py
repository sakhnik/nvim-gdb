"""Test program."""


def _bar(i):
    return i * 2


def _foo(num):
    if num == 0:
        return 0
    return num + _bar(num - 1)


def _main():
    for i in range(10):
        _foo(i)
    for i in range(0xffffff):
        pass


if __name__ == "__main__":
    _main()
