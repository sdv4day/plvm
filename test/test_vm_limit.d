/+ dub.sdl:
    name "test_vm_limit"
    dependency "plvm" path=".."
+/

import std.stdio;
import std.exception;
import std.conv;
import std.string;
import plvm;
import plvm.parser;
import plvm.compiler;
import plvm.vm;

int main()
{
    writeln("========================================");
    writeln("       PLVM 步数和超时测试           ");
    writeln("========================================");
    writeln();

    // 1. 测试正常循环
    writeln("=== 测试 1: 正常循环 (10步) ===");
    testNormalLoop();
    writeln();

    // 2. 测试无限循环被限制
    writeln("=== 测试 2: 无限循环 (100步限制) ===");
    testInfiniteLoopLimit(100);
    writeln();

    // 3. 测试不同步数限制
    writeln("=== 测试 3: 不同步数限制 ===");
    testVariousStepLimits();
    writeln();

    // 4. 验证执行步数
    writeln("=== 测试 4: 验证执行步数 ===");
    verifyExecutionSteps();
    writeln();

    writeln("========================================");
    writeln("           所有测试完成!                ");
    writeln("========================================");

    return 0;
}

void testNormalLoop()
{
    writeln("编译和执行...");
    string source = "int main() { int i = 0; int sum = 0; while (i < 10) { sum = sum + i; i = i + 1; } return sum; }";

    auto program = Compiler.compileSource(source);
    auto vm = new VirtualMachine();
    vm.setMaxSteps(1000);
    vm.loadProgram(program);

    try
    {
        Value result = vm.execute(findEntry(program));
        writefln("  ✓ 执行成功! 返回值: %s", result.asInteger());
        assert(result.asInteger() == 45);
        writeln("  ✓ 结果正确 (45)");
    }
    catch (Exception e)
    {
        writefln("  ✗ 执行失败: %s", e.msg);
        assert(false);
    }
}

void testInfiniteLoopLimit(size_t stepLimit)
{
    writefln("设置步数限制: %d", stepLimit);
    string source = "int main() { int i = 0; while (true) { i = i + 1; } return i; }";

    auto program = Compiler.compileSource(source);
    auto vm = new VirtualMachine();
    vm.setMaxSteps(stepLimit);
    vm.loadProgram(program);

    bool timedOut = false;
    try
    {
        vm.execute(findEntry(program));
    }
    catch (Exception e)
    {
        timedOut = true;
    }

    if (timedOut)
    {
        writeln("  ✓ 无限循环被正确中止!");
    }
    else
    {
        writeln("  ✗ 无限循环没有被中止!");
        assert(false);
    }
}

void testVariousStepLimits()
{
    string source = "int main() { int sum = 0; int i = 0; while (i < 5) { sum = sum + 1; i = i + 1; } return sum; }";
    auto program = Compiler.compileSource(source);

    size_t[] testLimits = [100, 200, 500, 1000, 10000];

    foreach (limit; testLimits)
    {
        writefln("  测试限制: %d 步", limit);
        auto vm = new VirtualMachine();
        vm.setMaxSteps(limit);
        vm.loadProgram(program);

        bool success = true;
        try
        {
            vm.execute(findEntry(program));
            writefln("    ✓ 在限制内执行成功!");
        }
        catch (Exception e)
        {
            success = false;
            writefln("    ✗ 被错误中止: %s", e.msg);
        }
        assert(success);
    }
}

void verifyExecutionSteps()
{
    writeln("验证短程序和长程序的步数限制...");

    string shortCode = "int main() { return 42; }";
    string mediumCode = "int main() { int sum = 0; for (int i = 0; i < 100; i++) { sum = sum + i; } return sum; }";

    // 1. 短程序应该几乎不使用步数
    auto shortProg = Compiler.compileSource(shortCode);
    auto vm1 = new VirtualMachine();
    vm1.setMaxSteps(100);
    vm1.loadProgram(shortProg);

    try
    {
        vm1.execute(findEntry(shortProg));
        writeln("  ✓ 短程序执行成功");
    }
    catch (Exception e)
    {
        writeln("  ✗ 短程序执行失败");
        assert(false);
    }

    // 2. 用极低限制测试应该会失败
    auto vm2 = new VirtualMachine();
    vm2.setMaxSteps(1);
    vm2.loadProgram(shortProg);

    bool failed = false;
    try
    {
        vm2.execute(findEntry(shortProg));
    }
    catch (Exception e)
    {
        failed = true;
    }

    if (failed)
    {
        writeln("  ✓ 极低限制正确中止执行!");
    }
    else
    {
        writeln("  ✗ 极低限制没有正确中止!");
        assert(false);
    }
}

size_t findEntry(BytecodeProgram program)
{
    foreach (ref f; program.functions)
    {
        if (f.name == "main" || f.name == "__anon_main__")
        {
            return f.entryPoint;
        }
    }
    if (program.functions.length > 0)
    {
        return program.functions[0].entryPoint;
    }
    return 0;
}
