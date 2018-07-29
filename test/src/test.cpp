#include "lib.hpp"

unsigned Bar(unsigned i)
{
    return i * 2;
}

unsigned Foo(unsigned n)
{
    if (!n)
        return 0;
    return n + Bar(n - 1);
}

int main()
{
    for (int i = 0; i < 10; ++i)
    {
        Foo(i);
    }
    Lib::Baz();
    for (unsigned i = 0; i < 0xffffffff; ++i);
    return 0;
}
