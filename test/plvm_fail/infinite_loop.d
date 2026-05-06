module test.plvm_fail.infinite_loop;

int main()
{
    int i = 0;
    while (true)
    {
        i = i + 1;
    }
    return i;
}
