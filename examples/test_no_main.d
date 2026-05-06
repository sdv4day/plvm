module examples.test_no_main;

// 测试脚本 - 无 main 函数，只有其他函数
int add(int a, int b)
{
    return a + b;
}

int multiply(int a, int b)
{
    return a * b;
}

int myFunc()
{
    int x = add(10, 20);
    int y = multiply(x, 2);
    return y;
}
