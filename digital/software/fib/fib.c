volatile unsigned int* GPIO_BASE = (unsigned int*) 0x40000000;

unsigned int fib(unsigned int n)
{
    if (n == 0)
        return 0;
    else if (n == 1)
        return 1;
    return fib(n-1) + fib(n-2);
} 

unsigned int T[] = {0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144};
const unsigned int CT[] = {0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144};

int main(void)
{
    unsigned int r;

    r = ((fib(9) == 34) && (T[9] == 34) && (CT[9] == 34)) ? 1 : 0;
    (*GPIO_BASE) = r;
    return 0;
}
