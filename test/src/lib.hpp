#pragma once

namespace Lib {

int Baz()
{
    int ret{0};
    for (int i = 0; i <= 100; ++i)
    {
        ret += i;
    }
    return ret;
}

} //namespace Lib;

#include <cstdlib>

namespace Lib {

unsigned GetLoopCount(int argc, char *argv[])
{
    if (argc > 1)
    {
        return strtoul(argv[1], nullptr, 10);
    }
    return 0xffff;
}

} //namespace Lib;
