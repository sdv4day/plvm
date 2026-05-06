module test.plvm_fail.with_dollar;

int main()
{
    int[] arr = [1, 2, 3];
    return arr[$-1]; // $运算符
    return 0;
}
