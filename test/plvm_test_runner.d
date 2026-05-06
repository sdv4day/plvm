/+ dub.sdl:
    name "hello"
    dependency "plvm" path=".."
+/
/**
 * 测试指令
 * dub --single plvm_test_runner.d --compiler=ldc2
*/
import std.stdio;
import std.file;
import std.path;
import std.conv;
import plvm;
import plvm.parser;
import plvm.compiler;

struct TestResult
{
    string fileName;
    bool passed;
    string errorMessage;
}

class TestRunner
{
private:
    TestResult[] results;

public:
    this()
    {
    }

    TestResult[] getResults()
    {
        return results;
    }

    void runAllTests(string testDir)
    {
        writeln("开始运行 PLVM 测试...");
        writeln("测试目录: ", testDir);
        writeln();

        string passDir = buildPath(testDir, "plvm_pass");
        string failDir = buildPath(testDir, "plvm_fail");

        if (exists(passDir) && isDir(passDir))
        {
            writeln("=== 运行通过测试 ===");
            runDirectoryTests(passDir, true);
        }

        if (exists(failDir) && isDir(failDir))
        {
            writeln("=== 运行失败测试 ===");
            runDirectoryTests(failDir, false);
        }

        printSummary();
    }

private:
    void runDirectoryTests(string dir, bool expectPass)
    {
        foreach (entry; dirEntries(dir, "*.d", SpanMode.shallow))
        {
            if (entry.isFile)
            {
                runSingleTest(entry.name, expectPass);
            }
        }
    }

    void runSingleTest(string fileName, bool expectPass)
    {
        TestResult result;
        result.fileName = fileName;

        try
        {
            string source = readText(fileName);
            writeln("测试: ", baseName(fileName));

            auto ast = Parser.parseSource(source, fileName);
            auto program = Compiler.compileSource(source);

            // 尝试执行程序，设置最大步数防止无限循环
            auto vm = new VirtualMachine();
            vm.setMaxSteps(1000000); // 100万步限制
            vm.loadProgram(program);

            // 找到入口函数执行
            size_t entry = 0;
            foreach (ref func; program.functions)
            {
                if (func.name == "main" || func.name == "__anon_main__")
                {
                    entry = func.entryPoint;
                    break;
                }
            }
            if (entry == 0 && program.functions.length > 0)
                entry = program.functions[0].entryPoint;

            vm.execute(entry);

            if (expectPass)
            {
                result.passed = true;
                writeln("  ✓ 通过");
            }
            else
            {
                result.passed = false;
                result.errorMessage = "期望失败但成功了";
                writeln("  ✗ 意外通过");
            }
        }
        catch (Exception e)
        {
            if (!expectPass)
            {
                result.passed = true;
                writeln("  ✓ 预期失败: ", e.msg);
            }
            else
            {
                result.passed = false;
                result.errorMessage = e.msg;
                writeln("  ✗ 失败: ", e.msg);
            }
        }

        results ~= result;
        writeln();
    }

    void printSummary()
    {
        int total = cast(int)results.length;
        int passed = 0;
        int failed = 0;

        foreach (r; results)
        {
            if (r.passed)
                passed++;
            else
                failed++;
        }

        writeln("=== 测试摘要 ===");
        writefln("总计: %d, 通过: %d, 失败: %d", total, passed, failed);

        if (failed > 0)
        {
            writeln();
            writeln("失败的测试:");
            foreach (r; results)
            {
                if (!r.passed)
                {
                    writefln("  - %s: %s", baseName(r.fileName), r.errorMessage);
                }
            }
        }
    }
}

void main(string[] args)
{
    version(Windows)
    {
        import core.sys.windows.windows;
        SetConsoleOutputCP(65001);
        SetConsoleCP(65001);
    }
    
    string testDir = __FILE_FULL_PATH__.dirName;
    auto runner = new TestRunner();
    runner.runAllTests(testDir);
}
