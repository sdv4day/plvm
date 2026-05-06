module examples.test_host_api_no_main;

/*
测试无 main 函数的脚本能否通过 Host API 调用
*/
import plvm;
import std.stdio;

int hostAdd(int a, int b) { return a + b; }
int hostMul(int a, int b) { return a * b; }

void main()
{
    writeln("测试无 main 函数的脚本");
    writeln("======================");
    
    Plvm vm = new Plvm();
    vm.registerFunction("hostAdd", &hostAdd);
    vm.registerFunction("hostMul", &hostMul);
    
    // 无 main 函数的脚本
    string script = `
        int add(int a, int b)
        {
            return hostAdd(a, b);
        }
        
        int multiply(int a, int b)
        {
            return hostMul(a, b);
        }
        
        int calculate(int x, int y)
        {
            int a = add(x, y);
            int b = multiply(a, 2);
            return b;
        }
        
        string greet(string name)
        {
            return "Hello, " ~ name;
        }
    `;
    
    writeln("加载脚本...");
    auto handle = vm.loadScript(script);
    
    // 测试调用第一个函数
    writeln("\n调用第一个函数 (add, 参数=10, 20):");
    auto result1 = vm.callFunction(handle, "add", 10, 20);
    writefln("  结果: %s", result1.asInteger());
    
    // 测试调用 calculate 函数
    writeln("\n调用 calculate 函数 (参数=5, 3):");
    auto result2 = vm.callFunction(handle, "calculate", 5, 3);
    writefln("  结果: %s", result2.asInteger());
    
    writeln("\n======================");
    writeln("所有测试完成!");
}
