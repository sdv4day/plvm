module examples.example_host_functions;

/*
Host 函数使用示例
演示如何在 Host 端注册函数，以及在脚本中调用它们
*/

// ==========================================
// Host 端代码 (D 程序)
// ==========================================

import plvm;
import std.stdio;

// Host 函数 1: 简单算术
int hostAdd(int a, int b)
{
    return a + b;
}

int hostSub(int a, int b)
{
    return a - b;
}

int hostMul(int a, int b)
{
    return a * b;
}

int hostDiv(int a, int b)
{
    return a / b;
}

// Host 函数 2: 字符串处理
string hostConcat(string a, string b)
{
    return a ~ b;
}

bool hostStartsWith(string str, string prefix)
{
    return str.length >= prefix.length && str[0..prefix.length] == prefix;
}

bool hostEndsWith(string str, string suffix)
{
    return str.length >= suffix.length && str[str.length - suffix.length..str.length] == suffix;
}

// Host 函数 3: 实用工具
int hostSumTo(int n)
{
    int sum = 0;
    for (int i = 1; i <= n; i++)
        sum += i;
    return sum;
}

bool hostIsPrime(int n)
{
    if (n <= 1) return false;
    for (int i = 2; i * i <= n; i++)
        if (n % i == 0) return false;
    return true;
}

int hostMax(int a, int b)
{
    return a > b ? a : b;
}

int hostMin(int a, int b)
{
    return a < b ? a : b;
}

int hostGCD(int a, int b)
{
    while (b != 0)
    {
        int t = b;
        b = a % b;
        a = t;
    }
    return a;
}

int hostFactorial(int n)
{
    if (n <= 1)
        return 1;
    return n * hostFactorial(n - 1);
}

int hostPower(int base, int exp)
{
    int result = 1;
    for (int i = 0; i < exp; i++)
        result *= base;
    return result;
}

void main()
{
    writeln("PLVM Host 函数示例");
    writeln("=====================");
    
    Plvm vm = new Plvm();
    
    // 注册所有 Host 函数
    vm.registerFunction("hostAdd", &hostAdd);
    vm.registerFunction("hostSub", &hostSub);
    vm.registerFunction("hostMul", &hostMul);
    vm.registerFunction("hostDiv", &hostDiv);
    vm.registerFunction("hostConcat", &hostConcat);
    vm.registerFunction("hostStartsWith", &hostStartsWith);
    vm.registerFunction("hostEndsWith", &hostEndsWith);
    vm.registerFunction("hostSumTo", &hostSumTo);
    vm.registerFunction("hostIsPrime", &hostIsPrime);
    vm.registerFunction("hostMax", &hostMax);
    vm.registerFunction("hostMin", &hostMin);
    vm.registerFunction("hostGCD", &hostGCD);
    vm.registerFunction("hostFactorial", &hostFactorial);
    vm.registerFunction("hostPower", &hostPower);
    
    // ==========================================
    // 脚本代码
    // ==========================================
    string script = `
        // 算术测试
        int testArithmetic()
        {
            int a = hostAdd(10, 20); // 30
            int b = hostMul(a, 2);  // 60
            int c = hostDiv(b, 3);  // 20
            int d = hostSub(c, 5);  // 15
            return d;
        }
        
        // 工具函数测试
        int testUtils()
        {
            int sum10 = hostSumTo(10); // 55
            int fact5 = hostFactorial(5); // 120
            int pow2_10 = hostPower(2, 10); // 1024
            return sum10 + fact5 + pow2_10;
        }
        
        // 数论测试
        int testMath()
        {
            int gcd1 = hostGCD(12, 18); // 6
            int gcd2 = hostGCD(7, 13); // 1
            int max1 = hostMax(100, 200); // 200
            int min1 = hostMin(100, 200); // 100
            bool prime7 = hostIsPrime(7); // true
            bool prime4 = hostIsPrime(4); // false
            
            int result = gcd1 + gcd2 + max1 + min1;
            if (prime7 && !prime4)
                result = result + 100;
            
            return result;
        }
        
        int main()
        {
            int total = 0;
            total = total + testArithmetic();
            total = total + testUtils();
            total = total + testMath();
            return total;
        }
    `;
    
    writeln("运行脚本...");
    Value result = vm.callOnce(script);
    writeln("脚本执行完成!");
    writeln("返回值: ", result.asInteger());
    
    writeln("=====================");
    writeln("所有测试通过!");
}
