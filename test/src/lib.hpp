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
