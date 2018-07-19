"""Test program."""


def _Bar(i):
    return i * 2


def _Foo(n):
    if n == 0:
        return 0
    return n + _Bar(n - 1)


def _main():
    for i in range(10):
        _Foo(i)
    for i in range(0xffffff):
        pass


if __name__ == "__main__":
    _main()
