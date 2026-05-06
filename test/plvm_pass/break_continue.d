int main()
{
    int sum = 0;
    int i = 0;
    while (i < 10)
    {
        i = i + 1;
        if (i == 5)
            continue;
        if (i == 8)
            break;
        sum = sum + i;
    }
    return sum;
}
