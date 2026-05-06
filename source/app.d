module plvm.test_app;

import plvm;
import std.stdio;
import std.conv : text, to;

struct TestStats
{
    int total;
    int passed;
    int failed;
}

TestStats stats;

size_t findEntry(BytecodeProgram program, string funcName)
{
    foreach (ref f; program.functions)
    {
        if (f.name == funcName)
            return f.entryPoint;
    }
    if (program.functions.length > 0)
        return program.functions[0].entryPoint;
    return 0;
}

Value executeVMScript(string src, string funcName)
{
    BytecodeProgram program = Compiler.compileSource(src);
    VirtualMachine vm = new VirtualMachine();
    vm.setMaxSteps(500000);
    vm.loadProgram(program);
    size_t entry = findEntry(program, funcName);
    return vm.execute(entry);
}

void runWithVM(T)(string src, T expected, string funcName, string desc)
{
    stats.total++;
    try
    {
        Value result = executeVMScript(src, funcName);
        T actual = valueToD!T(result);

        if (actual != expected)
        {
            writefln("  [× #%d] %s: 期望=%s  实际=%s", stats.total, desc, expected, actual);
            stats.failed++;
        }
        else
        {
            writefln("  [✓ #%d] %s: 结果=%s", stats.total, desc, actual);
            stats.passed++;
        }
    }
    catch (Exception e)
    {
        writefln("  [× #%d] %s: 异常 - %s", stats.total, desc, e.msg);
        stats.failed++;
    }
}

void runVoidVM(string src, string funcName, string desc)
{
    stats.total++;
    try
    {
        executeVMScript(src, funcName);
        stats.passed++;
    }
    catch (Exception e)
    {
        writefln("  [× #%d] %s: 异常 - %s", stats.total, desc, e.msg);
        stats.failed++;
    }
}

int main()
{
    version(Windows)
    {
        import core.sys.windows.windows;
        SetConsoleOutputCP(65001);
        SetConsoleCP(65001);
    }

    writeln("╔══════════════════════════════════════════════════════╗");
    writeln("║         PLVM 语法全面测试 (D编译器作为Oracle)        ║");
    writeln("╚══════════════════════════════════════════════════════╝\n");

    // ===================================================================
    // 一、基本类型测试
    // ===================================================================
    writeln("── 一、基本类型测试 ──");
    {
        enum src = `
bool testBoolTrue()  { return true; }
bool testBoolFalse() { return false; }
int  testIntRet()    { int x = 42; return x; }
int  testNegInt()    { int x = -10; return x; }
int  testZero()      { return 0; }
long testLongMin()   { long x = -2147483648; return x; }
long testLongMax()   { long x = 2147483647; return x; }
ulong testUlong()    { ulong x = 12345678901; return x; }
char testChar()      { char x = 'A'; return x; }
`;

        enum bool eBoolTrue  = (){ mixin(src); return testBoolTrue();  }();
        enum bool eBoolFalse = (){ mixin(src); return testBoolFalse(); }();
        enum int  eIntRet    = (){ mixin(src); return testIntRet();    }();
        enum int  eNegInt    = (){ mixin(src); return testNegInt();    }();
        enum int  eZero      = (){ mixin(src); return testZero();      }();
        enum long eLongMin   = (){ mixin(src); return testLongMin();   }();
        enum long eLongMax   = (){ mixin(src); return testLongMax();   }();
        enum ulong eUlong    = (){ mixin(src); return testUlong();     }();
        enum char eChar      = (){ mixin(src); return testChar();      }();

        runWithVM(src, eBoolTrue,  "testBoolTrue",  "bool true");
        runWithVM(src, eBoolFalse, "testBoolFalse", "bool false");
        runWithVM(src, eIntRet,    "testIntRet",    "int 返回");
        runWithVM(src, eNegInt,    "testNegInt",    "int 取负");
        runWithVM(src, eZero,      "testZero",      "int 零值");
        runWithVM(src, eLongMin,   "testLongMin",   "long 最小值");
        runWithVM(src, eLongMax,   "testLongMax",   "long 最大值");
        runWithVM(src, eUlong,     "testUlong",     "ulong 大值");
        runWithVM(src, eChar,      "testChar",      "char 字符");
    }

    // ===================================================================
    // 二、字符串类型测试
    // ===================================================================
    writeln("── 二、字符串类型测试 ──");
    {
        enum src = `
string testHello()       { return "hello"; }
string testEmpty()       { return ""; }
string testConcat()      { string a = "abc"; string b = "def"; return "result"; }
string testUnicode()     { return "你好世界"; }
`;

        enum string eHello   = (){ mixin(src); return testHello();   }();
        enum string eEmpty   = (){ mixin(src); return testEmpty();   }();
        enum string eResult  = (){ mixin(src); return testConcat();  }();
        enum string eUnicode = (){ mixin(src); return testUnicode(); }();

        runWithVM(src, eHello,   "testHello",   "string hello");
        runWithVM(src, eEmpty,   "testEmpty",   "string 空串");
        runWithVM(src, eResult,  "testConcat",  "string 拼接");
        runWithVM(src, eUnicode, "testUnicode", "string Unicode");
    }

    // ===================================================================
    // 三、算术运算测试
    // ===================================================================
    writeln("── 三、算术运算测试 ──");
    {
        enum src = `
int testAdd()     { return 3 + 4; }
int testSub()     { return 10 - 3; }
int testMul()     { return 6 * 7; }
int testDiv()     { return 20 / 4; }
int testMod()     { return 17 % 5; }
int testNegExpr() { return -(5 + 3); }
int testComplex() { return (2 + 3) * 4 - 5; }
int testDivTrunc(){ return 7 / 2; }
`;

        enum int eAdd      = (){ mixin(src); return testAdd();      }();
        enum int eSub      = (){ mixin(src); return testSub();      }();
        enum int eMul      = (){ mixin(src); return testMul();      }();
        enum int eDiv      = (){ mixin(src); return testDiv();      }();
        enum int eMod      = (){ mixin(src); return testMod();      }();
        enum int eNegExpr  = (){ mixin(src); return testNegExpr();  }();
        enum int eComplex  = (){ mixin(src); return testComplex();  }();
        enum int eDivTrunc = (){ mixin(src); return testDivTrunc(); }();

        runWithVM(src, eAdd,      "testAdd",      "加法 +");
        runWithVM(src, eSub,      "testSub",      "减法 -");
        runWithVM(src, eMul,      "testMul",      "乘法 *");
        runWithVM(src, eDiv,      "testDiv",      "除法 /");
        runWithVM(src, eMod,      "testMod",      "取模 %");
        runWithVM(src, eNegExpr,  "testNegExpr",  "一元取负");
        runWithVM(src, eComplex,  "testComplex",  "复合算术");
        runWithVM(src, eDivTrunc, "testDivTrunc", "整数除法截断");
    }

    // ===================================================================
    // 四、比较运算测试
    // ===================================================================
    writeln("── 四、比较运算测试 ──");
    {
        enum src = `
int testEQ_T()  { if (5 == 5) return 1; return 0; }
int testEQ_F()  { if (5 == 3) return 1; return 0; }
int testNE_T()  { if (5 != 3) return 1; return 0; }
int testNE_F()  { if (5 != 5) return 1; return 0; }
int testLT_T()  { if (3 < 5) return 1; return 0; }
int testLT_F()  { if (5 < 3) return 1; return 0; }
int testGT_T()  { if (5 > 3) return 1; return 0; }
int testGT_F()  { if (3 > 5) return 1; return 0; }
int testLE_T()  { if (3 <= 3) return 1; return 0; }
int testLE_F()  { if (5 <= 3) return 1; return 0; }
int testGE_T()  { if (5 >= 5) return 1; return 0; }
int testGE_F()  { if (3 >= 5) return 1; return 0; }
`;

        enum int eEQ_T = (){ mixin(src); return testEQ_T(); }();
        enum int eEQ_F = (){ mixin(src); return testEQ_F(); }();
        enum int eNE_T = (){ mixin(src); return testNE_T(); }();
        enum int eNE_F = (){ mixin(src); return testNE_F(); }();
        enum int eLT_T = (){ mixin(src); return testLT_T(); }();
        enum int eLT_F = (){ mixin(src); return testLT_F(); }();
        enum int eGT_T = (){ mixin(src); return testGT_T(); }();
        enum int eGT_F = (){ mixin(src); return testGT_F(); }();
        enum int eLE_T = (){ mixin(src); return testLE_T(); }();
        enum int eLE_F = (){ mixin(src); return testLE_F(); }();
        enum int eGE_T = (){ mixin(src); return testGE_T(); }();
        enum int eGE_F = (){ mixin(src); return testGE_F(); }();

        runWithVM(src, eEQ_T, "testEQ_T", "== 为真");
        runWithVM(src, eEQ_F, "testEQ_F", "== 为假");
        runWithVM(src, eNE_T, "testNE_T", "!= 为真");
        runWithVM(src, eNE_F, "testNE_F", "!= 为假");
        runWithVM(src, eLT_T, "testLT_T", "<  为真");
        runWithVM(src, eLT_F, "testLT_F", "<  为假");
        runWithVM(src, eGT_T, "testGT_T", ">  为真");
        runWithVM(src, eGT_F, "testGT_F", ">  为假");
        runWithVM(src, eLE_T, "testLE_T", "<= 为真");
        runWithVM(src, eLE_F, "testLE_F", "<= 为假");
        runWithVM(src, eGE_T, "testGE_T", ">= 为真");
        runWithVM(src, eGE_F, "testGE_F", ">= 为假");
    }

    // ===================================================================
    // 五、逻辑运算测试
    // ===================================================================
    writeln("── 五、逻辑运算测试 ──");
    {
        enum src = `
int testAndTT() { if (true && true)   return 1; return 0; }
int testAndTF() { if (true && false)  return 1; return 0; }
int testAndFF() { if (false && false) return 1; return 0; }
int testOrTT()  { if (true || true)   return 1; return 0; }
int testOrTF()  { if (true || false)  return 1; return 0; }
int testOrFF()  { if (false || false) return 1; return 0; }
int testNotT()  { if (!false) return 1; return 0; }
int testNotF()  { if (!true)  return 1; return 0; }
`;

        enum int eAndTT = (){ mixin(src); return testAndTT(); }();
        enum int eAndTF = (){ mixin(src); return testAndTF(); }();
        enum int eAndFF = (){ mixin(src); return testAndFF(); }();
        enum int eOrTT  = (){ mixin(src); return testOrTT();  }();
        enum int eOrTF  = (){ mixin(src); return testOrTF();  }();
        enum int eOrFF  = (){ mixin(src); return testOrFF();  }();
        enum int eNotT  = (){ mixin(src); return testNotT();  }();
        enum int eNotF  = (){ mixin(src); return testNotF();  }();

        runWithVM(src, eAndTT, "testAndTT", "&& TT");
        runWithVM(src, eAndTF, "testAndTF", "&& TF");
        runWithVM(src, eAndFF, "testAndFF", "&& FF");
        runWithVM(src, eOrTT,  "testOrTT",  "|| TT");
        runWithVM(src, eOrTF,  "testOrTF",  "|| TF");
        runWithVM(src, eOrFF,  "testOrFF",  "|| FF");
        runWithVM(src, eNotT,  "testNotT",  "! false→true");
        runWithVM(src, eNotF,  "testNotF",  "! true→false");
    }

    // ===================================================================
    // 六、控制流测试 — if-else
    // ===================================================================
    writeln("── 六、控制流测试 (if-else) ──");
    {
        enum src = `
int testIfTrue()  { if (1) { return 100; } return 0; }
int testIfFalse() { int x = 5; if (x < 3) { return 1; } return 99; }
int testIfElseT() { int x = 10; if (x > 5) { return 10; } else { return 0; } }
int testIfElseF() { int x = 2;  if (x > 5) { return 10; } else { return 0; } }
int testChain()   { int x = 75;
    if (x >= 90) { return 4; }
    else if (x >= 80) { return 3; }
    else if (x >= 70) { return 2; }
    else if (x >= 60) { return 1; }
    else { return 0; }
}
`;

        enum int eIfTrue  = (){ mixin(src); return testIfTrue();  }();
        enum int eIfFalse = (){ mixin(src); return testIfFalse(); }();
        enum int eIfElseT = (){ mixin(src); return testIfElseT(); }();
        enum int eIfElseF = (){ mixin(src); return testIfElseF(); }();
        enum int eChain   = (){ mixin(src); return testChain();   }();

        runWithVM(src, eIfTrue,  "testIfTrue",  "if (true)");
        runWithVM(src, eIfFalse, "testIfFalse", "if (false)");
        runWithVM(src, eIfElseT, "testIfElseT", "if-else true分支");
        runWithVM(src, eIfElseF, "testIfElseF", "if-else false分支");
        runWithVM(src, eChain,   "testChain",   "if-else if 链");
    }

    // ===================================================================
    // 七、控制流测试 — 循环 (while, do-while, for)
    // ===================================================================
    writeln("── 七、控制流测试 (循环) ──");
    {
        enum src = `
int testWhile()     { int i = 0; int s = 0; while (i < 5) { s = s + i; i = i + 1; } return s; }
int testWhileZero() { int i = 10; while (i < 5) { return 1; } return 0; }
int testDoWhile()   { int i = 0; int s = 0; do { s = s + i; i = i + 1; } while (i < 5); return s; }
int testDoOnce()    { int x = 0; do { x = 99; } while (false); return x; }
int testFor()       { int s = 0; int i; for (i = 1; i <= 5; i = i + 1) { s = s + i; } return s; }
int testInfiniteBreak() { int x = 0; while (true) { x = 42; break; } return x; }
`;

        enum int eWhile     = (){ mixin(src); return testWhile();     }();
        enum int eWhileZero = (){ mixin(src); return testWhileZero(); }();
        enum int eDoWhile   = (){ mixin(src); return testDoWhile();   }();
        enum int eDoOnce    = (){ mixin(src); return testDoOnce();    }();
        enum int eFor       = (){ mixin(src); return testFor();       }();
        enum int eInfiniteBreak  = (){ mixin(src); return testInfiniteBreak();  }();

        runWithVM(src, eWhile,         "testWhile",         "while 求和 0..4");
        runWithVM(src, eWhileZero,     "testWhileZero",     "while 条件假→不执行");
        runWithVM(src, eDoWhile,       "testDoWhile",       "do-while 求和 0..4");
        runWithVM(src, eDoOnce,        "testDoOnce",        "do-while 至少执行一次");
        runWithVM(src, eFor,           "testFor",           "for 求和 1..5");
        runWithVM(src, eInfiniteBreak, "testInfiniteBreak", "while(true)+break");
    }

    // ===================================================================
    // 八、控制流测试 — switch
    // ===================================================================
    writeln("── 八、控制流测试 (switch) ──");
    {
        enum src = `
int testSwitch1() { int x = 2; int r = 0;
    switch (x) { case 1: r = 10; break; case 2: r = 20; break; case 3: r = 30; break; default: r = 0; break; }
    return r;
}
int testSwitchDefault() { int x = 99; int r = 0;
    switch (x) { case 1: r = 10; break; case 2: r = 20; break; default: r = 88; break; }
    return r;
}
`;

        enum int eSwitch1       = (){ mixin(src); return testSwitch1();       }();
        enum int eSwitchDefault = (){ mixin(src); return testSwitchDefault(); }();

        runWithVM(src, eSwitch1,       "testSwitch1",       "switch case 2");
        runWithVM(src, eSwitchDefault, "testSwitchDefault", "switch default");
    }

    // ===================================================================
    // 九、控制流测试 — break/continue
    // ===================================================================
    writeln("── 九、控制流测试 (break/continue) ──");
    {
        enum src = `
int testBreak() { int sum = 0; int i = 0;
    while (i < 100) { i = i + 1; sum = sum + i; if (i == 5) break; }
    return sum;
}
int testContinue() { int sum = 0; int i = 0;
    while (i < 8) { i = i + 1; if (i == 4) continue; sum = sum + i; }
    return sum;
}
int testBoth() { int sum = 0; int i = 0;
    while (i < 10) { i = i + 1; if (i == 5) continue; if (i == 8) break; sum = sum + i; }
    return sum;
}
`;

        enum int eBreak    = (){ mixin(src); return testBreak();    }();
        enum int eContinue = (){ mixin(src); return testContinue(); }();
        enum int eBoth     = (){ mixin(src); return testBoth();     }();

        runWithVM(src, eBreak,    "testBreak",    "break 提前退出 (sum 1..5)");
        runWithVM(src, eContinue, "testContinue", "continue 跳过4 (sum 1..8-4)");
        runWithVM(src, eBoth,     "testBoth",     "break+continue 组合");
    }

    // ===================================================================
    // 九点五、嵌套循环测试
    // ===================================================================
    writeln("── 九点五、嵌套循环测试 ──");
    {
        enum src = `
int testNestedWhile() {
    int sum = 0;
    int i = 0;
    while (i < 3) {
        int j = 0;
        while (j < 3) {
            sum = sum + i * 3 + j;
            j = j + 1;
        }
        i = i + 1;
    }
    return sum;
}
int testNestedFor() {
    int sum = 0;
    int i; int j;
    for (i = 0; i < 3; i = i + 1) {
        for (j = 0; j < 4; j = j + 1) {
            sum = sum + 1;
        }
    }
    return sum;
}
int testMixedLoop() {
    int sum = 0;
    int i = 0;
    while (i < 2) {
        int j;
        for (j = 0; j < 3; j = j + 1) {
            sum = sum + i + j;
        }
        i = i + 1;
    }
    return sum;
}
int testNestedBreak() {
    int sum = 0;
    int i = 0;
    while (i < 5) {
        int j = 0;
        while (j < 5) {
            if (j == 2) break;
            sum = sum + 1;
            j = j + 1;
        }
        i = i + 1;
    }
    return sum;
}
int testLabeledBreak() {
    int result = 0;
    int i = 0;
    while (i < 3) {
        int j = 0;
        while (j < 3) {
            if (i == 1 && j == 1) {
                result = 99;
                break;
            }
            j = j + 1;
        }
        if (result == 99) break;
        i = i + 1;
    }
    return result;
}
`;
        enum int eNestedWhile   = (){ mixin(src); return testNestedWhile();   }();
        enum int eNestedFor     = (){ mixin(src); return testNestedFor();     }();
        enum int eMixedLoop     = (){ mixin(src); return testMixedLoop();     }();
        enum int eNestedBreak   = (){ mixin(src); return testNestedBreak();   }();
        enum int eLabeledBreak  = (){ mixin(src); return testLabeledBreak();  }();

        runWithVM(src, eNestedWhile,   "testNestedWhile",   "嵌套 while 循环");
        runWithVM(src, eNestedFor,     "testNestedFor",     "嵌套 for 循环 (3x4=12)");
        runWithVM(src, eMixedLoop,     "testMixedLoop",     "while+for 混合循环");
        runWithVM(src, eNestedBreak,   "testNestedBreak",   "嵌套循环内层 break");
        runWithVM(src, eLabeledBreak,  "testLabeledBreak",  "模拟标签 break");
    }

    // ===================================================================
    // 九点六、循环边界与特殊情况测试
    // ===================================================================
    writeln("── 九点六、循环边界与特殊情况测试 ──");
    {
        enum src = `
int testWhileFalse() {
    while (false) { return 1; }
    return 0;
}
int testDoWhileFalse() {
    int x = 0;
    do { x = 42; } while (false);
    return x;
}
int testForEmpty() {
    int s = 0;
    int i;
    for (i = 0; i < 0; i = i + 1) { s = s + 1; }
    return s;
}
int testForNoBody() {
    int i;
    for (i = 0; i < 10; i = i + 1) { }
    return i;
}
int testWhileDecrement() {
    int sum = 0;
    int i = 5;
    while (i > 0) {
        sum = sum + i;
        i = i - 1;
    }
    return sum;
}
int testForStep2() {
    int sum = 0;
    int i;
    for (i = 0; i < 10; i = i + 2) {
        sum = sum + i;
    }
    return sum;
}
int testForNegative() {
    int sum = 0;
    int i;
    for (i = 10; i > 0; i = i - 1) {
        sum = sum + 1;
    }
    return sum;
}
int testLoopEarlyReturn() {
    int i = 0;
    while (i < 100) {
        if (i == 5) return i;
        i = i + 1;
    }
    return -1;
}
`;
        enum int eWhileFalse     = (){ mixin(src); return testWhileFalse();     }();
        enum int eDoWhileFalse   = (){ mixin(src); return testDoWhileFalse();   }();
        enum int eForEmpty       = (){ mixin(src); return testForEmpty();       }();
        enum int eForNoBody      = (){ mixin(src); return testForNoBody();      }();
        enum int eWhileDecrement = (){ mixin(src); return testWhileDecrement(); }();
        enum int eForStep2       = (){ mixin(src); return testForStep2();       }();
        enum int eForNegative    = (){ mixin(src); return testForNegative();    }();
        enum int eEarlyReturn    = (){ mixin(src); return testLoopEarlyReturn(); }();

        runWithVM(src, eWhileFalse,     "testWhileFalse",     "while(false) 不执行");
        runWithVM(src, eDoWhileFalse,   "testDoWhileFalse",   "do-while(false) 执行一次");
        runWithVM(src, eForEmpty,       "testForEmpty",       "for 条件初始为假");
        runWithVM(src, eForNoBody,      "testForNoBody",      "for 空循环体");
        runWithVM(src, eWhileDecrement, "testWhileDecrement", "while 递减循环 5+4+3+2+1");
        runWithVM(src, eForStep2,       "testForStep2",       "for 步长为2 (0+2+4+6+8)");
        runWithVM(src, eForNegative,    "testForNegative",    "for 递减循环 10次");
        runWithVM(src, eEarlyReturn,    "testLoopEarlyReturn", "循环中提前 return");
    }

    // ===================================================================
    // 十、函数测试
    // ===================================================================
    writeln("── 十、函数测试 ──");
    {
        enum src = `
int add(int a, int b)    { return a + b; }
int mul(int a, int b)    { return a * b; }
int testCall()           { return add(5, 7); }
int testMultiParam()     { return mul(add(2, 3), 4); }
int testNested()         { return add(mul(3, 4), add(1, 2)); }

int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}
int testRecursive() { return factorial(5); }

int fib(int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
}
int testFib() { return fib(6); }
`;

        enum int eCall       = (){ mixin(src); return testCall();       }();
        enum int eMultiParam = (){ mixin(src); return testMultiParam(); }();
        enum int eNested     = (){ mixin(src); return testNested();     }();
        enum int eRecursive  = (){ mixin(src); return testRecursive();  }();
        enum int eFib        = (){ mixin(src); return testFib();        }();

        runWithVM(src, eCall,       "testCall",       "简单函数调用 add(5,7)");
        runWithVM(src, eMultiParam, "testMultiParam", "多参数嵌套 mul(add(2,3),4)");
        runWithVM(src, eNested,     "testNested",     "嵌套调用 add(mul,add)");
        runWithVM(src, eRecursive,  "testRecursive",  "递归 factorial(5)");
        runWithVM(src, eFib,        "testFib",        "递归 fib(6)");
    }

    // ===================================================================
    // 十一、变量测试
    // ===================================================================
    writeln("── 十一、变量测试 ──");
    {
        enum src = `
int testVarDecl()    { int x = 10; int y = 20; return x + y; }
int testAssign()     { int x = 5; x = 42; return x; }
int testMultiAssign(){ int a = 1; int b = 2; int c = 3; a = b + c; return a; }
int testReassign()   { int x = 10; x = x + 5; x = x * 2; return x; }
`;

        enum int eVarDecl     = (){ mixin(src); return testVarDecl();     }();
        enum int eAssign      = (){ mixin(src); return testAssign();      }();
        enum int eMultiAssign = (){ mixin(src); return testMultiAssign(); }();
        enum int eReassign    = (){ mixin(src); return testReassign();    }();

        runWithVM(src, eVarDecl,     "testVarDecl",     "多变量声明");
        runWithVM(src, eAssign,      "testAssign",      "变量赋值");
        runWithVM(src, eMultiAssign, "testMultiAssign", "多变量运算赋值");
        runWithVM(src, eReassign,    "testReassign",    "重复赋值 x=x+5; x=x*2");
    }

    // ===================================================================
    // 十二、注释测试
    // ===================================================================
    writeln("── 十二、注释测试 ──");
    {
        // 单行注释
        enum src1 = `
int testLineComment() {
    // 这是单行注释
    int x = 42;
    return x;
}
`;
        enum int eLineComment = (){ mixin(src1); return testLineComment(); }();
        runWithVM(src1, eLineComment, "testLineComment", "// 单行注释");

        // 多行注释
        enum src2 = `
int testBlockComment() {
    /* 这是多行注释
       跨越多行 */
    int x = 99;
    return x;
}
`;
        enum int eBlockComment = (){ mixin(src2); return testBlockComment(); }();
        runWithVM(src2, eBlockComment, "testBlockComment", "/* */ 多行注释");

        // 行尾注释
        enum src3 = `
int testEndComment() {
    int x = 10; // 行尾注释
    x = x + 5; /* 块行尾 */
    return x;
}
`;
        enum int eEndComment = (){ mixin(src3); return testEndComment(); }();
        runWithVM(src3, eEndComment, "testEndComment", "行尾注释 // + /**/");

        // 注释在代码前
        enum src4 = `
int testPreComment() {
    // 预处理说明
    /* 另一个说明 */
    int result = 0;
    // 累加
    result = 7;
    return result;
}
`;
        enum int ePreComment = (){ mixin(src4); return testPreComment(); }();
        runWithVM(src4, ePreComment, "testPreComment", "代码前混合注释");
    }

    // ===================================================================
    // 十三、三元表达式测试
    // ===================================================================
    writeln("── 十三、三元表达式测试 ──");
    {
        enum src = `
int testTernaryT()  { return (5 > 3) ? 100 : 0; }
int testTernaryF()  { return (5 < 3) ? 100 : 0; }
int testNestedTern(){ int x = 15; return x > 10 ? (x > 20 ? 3 : 2) : 1; }
`;

        enum int eTernaryT   = (){ mixin(src); return testTernaryT();   }();
        enum int eTernaryF   = (){ mixin(src); return testTernaryF();   }();
        enum int eNestedTern = (){ mixin(src); return testNestedTern(); }();

        runWithVM(src, eTernaryT,   "testTernaryT",   "三元 true→100");
        runWithVM(src, eTernaryF,   "testTernaryF",   "三元 false→0");
        runWithVM(src, eNestedTern, "testNestedTern", "嵌套三元");
    }

    // ===================================================================
    // 十四、数组操作测试
    // ===================================================================
    writeln("── 十四、数组操作测试 ──");
    {
        enum src = `
int testArrayCreate() {
    auto a = [1, 2, 3, 4, 5];
    return cast(int)a.length;
}
int testArrayGet() {
    auto a = [10, 20, 30, 40, 50];
    return a[2];
}
int testArraySet() {
    auto a = [1, 2, 3];
    a[1] = 99;
    return a[1];
}
int testArrayLength() {
    auto a = [1, 2, 3, 4, 5, 6, 7];
    return cast(int)a.length;
}
int testArraySum() {
    auto a = [1, 2, 3, 4, 5];
    int sum = 0;
    int i = 0;
    while (i < cast(int)a.length) {
        sum = sum + a[i];
        i = i + 1;
    }
    return sum;
}
int testArrayModify() {
    auto a = [0, 0, 0, 0, 0];
    int i = 0;
    while (i < cast(int)a.length) {
        a[i] = i * 2;
        i = i + 1;
    }
    return a[3];
}
`;
        enum int eArrayCreate  = (){ mixin(src); return testArrayCreate();  }();
        enum int eArrayGet     = (){ mixin(src); return testArrayGet();     }();
        enum int eArraySet     = (){ mixin(src); return testArraySet();     }();
        enum int eArrayLength  = (){ mixin(src); return testArrayLength();  }();
        enum int eArraySum     = (){ mixin(src); return testArraySum();     }();
        enum int eArrayModify  = (){ mixin(src); return testArrayModify();  }();

        runWithVM(src, eArrayCreate,  "testArrayCreate",  "数组创建与长度");
        runWithVM(src, eArrayGet,     "testArrayGet",     "数组索引读取 a[2]");
        runWithVM(src, eArraySet,     "testArraySet",     "数组索引赋值 a[1]=99");
        runWithVM(src, eArrayLength,  "testArrayLength",  "数组 .length 属性");
        runWithVM(src, eArraySum,     "testArraySum",     "数组遍历求和");
        runWithVM(src, eArrayModify,  "testArrayModify",  "数组元素修改");
    }

    // ===================================================================
    // 十四点五、数组高级操作测试
    // ===================================================================
    writeln("── 十四点五、数组高级操作测试 ──");
    {
        enum src = `
int testArrayCopy() {
    auto a = [1, 2, 3];
    auto b = a;
    b[0] = 99;
    return a[0];
}
int testArrayFind() {
    auto a = [5, 3, 8, 1, 9, 2];
    int target = 8;
    int i = 0;
    int found = -1;
    while (i < cast(int)a.length) {
        if (a[i] == target) {
            found = i;
            break;
        }
        i = i + 1;
    }
    return found;
}
int testArrayReverse() {
    auto a = [1, 2, 3, 4, 5];
    int i = 0;
    int j = cast(int)a.length - 1;
    while (i < j) {
        int tmp = a[i];
        a[i] = a[j];
        a[j] = tmp;
        i = i + 1;
        j = j - 1;
    }
    return a[0];
}
int testArrayMinMax() {
    auto a = [3, 7, 2, 9, 1, 8, 4];
    int minVal = a[0];
    int maxVal = a[0];
    int i = 1;
    while (i < cast(int)a.length) {
        if (a[i] < minVal) minVal = a[i];
        if (a[i] > maxVal) maxVal = a[i];
        i = i + 1;
    }
    return minVal * 10 + maxVal;
}
int testArrayBubbleSort() {
    auto a = [5, 3, 8, 1, 9, 2, 7, 4, 6];
    int n = cast(int)a.length;
    int i = 0;
    while (i < n - 1) {
        int j = 0;
        while (j < n - i - 1) {
            if (a[j] > a[j + 1]) {
                int tmp = a[j];
                a[j] = a[j + 1];
                a[j + 1] = tmp;
            }
            j = j + 1;
        }
        i = i + 1;
    }
    return a[0] * 100 + a[4] * 10 + a[8];
}
int testArrayCountEven() {
    auto a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    int count = 0;
    int i = 0;
    while (i < cast(int)a.length) {
        if (a[i] % 2 == 0) count = count + 1;
        i = i + 1;
    }
    return count;
}
`;
        enum int eArrayCopy      = (){ mixin(src); return testArrayCopy();      }();
        enum int eArrayFind      = (){ mixin(src); return testArrayFind();      }();
        enum int eArrayReverse   = (){ mixin(src); return testArrayReverse();   }();
        enum int eArrayMinMax    = (){ mixin(src); return testArrayMinMax();    }();
        enum int eArrayBubbleSort = (){ mixin(src); return testArrayBubbleSort(); }();
        enum int eArrayCountEven  = (){ mixin(src); return testArrayCountEven();  }();

        runWithVM(src, eArrayCopy,       "testArrayCopy",       "数组复制（引用语义）");
        runWithVM(src, eArrayFind,       "testArrayFind",       "数组查找元素");
        runWithVM(src, eArrayReverse,    "testArrayReverse",    "数组原地反转");
        runWithVM(src, eArrayMinMax,     "testArrayMinMax",     "数组求最小最大值");
        runWithVM(src, eArrayBubbleSort, "testArrayBubbleSort", "数组冒泡排序");
        runWithVM(src, eArrayCountEven,  "testArrayCountEven",  "数组统计偶数");
    }

    // ===================================================================
    // 十五、复合测试 — 算法
    // ===================================================================
    writeln("── 十五、复合测试 (算法) ──");
    {
        // 阶乘(迭代)
        enum src1 = `
int factorialIter(int n) {
    int result = 1;
    int i = 1;
    while (i <= n) { result = result * i; i = i + 1; }
    return result;
}
int testFactIter() { return factorialIter(5); }
`;
        enum int eFactIter = (){ mixin(src1); return testFactIter(); }();
        runWithVM(src1, eFactIter, "testFactIter", "阶乘(迭代) 5! = 120");

        // 级数求和
        enum src2 = `
int sumRange(int from, int to) {
    int sum = 0;
    int i = from;
    while (i <= to) { sum = sum + i; i = i + 1; }
    return sum;
}
int testSumRange() { return sumRange(1, 100); }
`;
        enum int eSumRange = (){ mixin(src2); return testSumRange(); }();
        runWithVM(src2, eSumRange, "testSumRange", "1..100 求和 = 5050");

        // 最大公约数
        enum src3 = `
int gcd(int a, int b) {
    while (b != 0) { int t = b; b = a % b; a = t; }
    return a;
}
int testGcd() { return gcd(48, 18); }
`;
        enum int eGcd = (){ mixin(src3); return testGcd(); }();
        runWithVM(src3, eGcd, "testGcd", "GCD(48,18) = 6");
    }

    // ===================================================================
    // 十六、宿主函数测试
    // ===================================================================
    writeln("── 十六、宿主函数测试 ──");
    {
        static int addHost(int a, int b) { return a + b; }
        static int mulHost(int a, int b) { return a * b; }
        static long sumToHost(long n) {
            long s = 0;
            for (long i = 1; i <= n; i++) s += i;
            return s;
        }

        auto plvm = new Plvm();
        plvm.registerFunction!addHost("addHost");
        plvm.registerFunction!mulHost("mulHost");
        plvm.registerFunction!sumToHost("sumToHost");

        {
            enum int expected = addHost(10, 20); // 30
            auto result = plvm.callOnce(
                "int main() { return addHost(10, 20); }", "main");
            assertTest(result.asInteger(), expected, "宿主 addHost(10,20)");
        }
        {
            enum int expected = mulHost(6, 7); // 42
            auto result = plvm.callOnce(
                "int main() { return mulHost(6, 7); }", "main");
            assertTest(result.asInteger(), expected, "宿主 mulHost(6,7)");
        }
        {
            enum long expected = sumToHost(100); // 5050
            auto result = plvm.callOnce(
                "long main() { return sumToHost(100); }", "main");
            assertTest(result.asInteger(), expected, "宿主 sumToHost(100)");
        }
    }

    // ===================================================================
    // 十七、结构体测试
    // ===================================================================
    writeln("── 十七、结构体测试 ──");
    {
        static struct Point { int x; int y; }
        static struct Rect { int w; int h; }

        auto plvm = new Plvm();
        plvm.registerStruct!Point("Point");
        plvm.registerStruct!Rect("Rect");

        {
            auto result = plvm.callOnce(
                "struct Point { int x; int y; } " ~
                "int main() { Point p; p.x = 10; p.y = 20; return p.x + p.y; }", "main");
            assertTest(result.asInteger(), 30, "结构体 Point 字段赋值与读取");
        }
        {
            auto result = plvm.callOnce(
                "struct Rect { int w; int h; } " ~
                "int main() { Rect r; r.w = 5; r.h = 8; return r.w * r.h; }", "main");
            assertTest(result.asInteger(), 40, "结构体 Rect 面积计算");
        }
    }

    // ===================================================================
    // 十八、枚举测试
    // ===================================================================
    writeln("── 十八、枚举测试 ──");
    {
        enum Color { Red = 0, Green = 1, Blue = 2 }

        auto plvm = new Plvm();
        plvm.registerEnum!Color("Color");

        {
            auto result = plvm.callOnce(
                "int main() { int c = Color.Green; return c; }", "main");
            assertTest(result.asInteger(), 1, "枚举 Color.Green = 1");
        }
        {
            auto result = plvm.callOnce(
                "int main() { int c = Color.Blue; return c + 10; }", "main");
            assertTest(result.asInteger(), 12, "枚举 Color.Blue + 10 = 12");
        }
        {
            auto result = plvm.callOnce(
                "int main() { int c = Color.Red; if (c == 0) return 99; return 0; }", "main");
            assertTest(result.asInteger(), 99, "枚举与0比较");
        }
    }

    // ===================================================================
    // 十九、短路径逻辑测试
    // ===================================================================
    writeln("── 十九、短路径逻辑测试 ──");
    {
        enum src = `
int expensive()  { return 123; }
int testSCAndF() { if (false && expensive()) return 1; return 0; }
int testSCOrT()  { if (true || expensive()) return 1; return 0; }
`;

        enum int eSCAndF = (){ mixin(src); return testSCAndF(); }();
        enum int eSCOrT  = (){ mixin(src); return testSCOrT();  }();

        runWithVM(src, eSCAndF, "testSCAndF", "短路 && 左假→跳过右");
        runWithVM(src, eSCOrT,  "testSCOrT",  "短路 || 左真→跳过右");
    }

    // ===================================================================
    // 测试 executeModule 和 executeModuleWithEntry
    // ===================================================================
    writeln("\n=== 测试 executeModule 和 executeModuleWithEntry ===");

    Plvm plvm = new Plvm();

    // 测试 executeModule
    {
        string script1 = "int main() { return 42; }";
        auto handle1 = plvm.loadScript(script1);
        auto result1 = plvm.executeModule(handle1);
        assertTest(result1.asInteger(), 42L, "executeModule: main返回42");
    }

    // 测试 executeModule 带参数
    {
        string script2 = "int add(int a, int b) { return a + b; } int main() { return add(10, 20); }";
        auto handle2 = plvm.loadScript(script2);
        auto result2 = plvm.executeModule(handle2);
        assertTest(result2.asInteger(), 30L, "executeModule: 调用add函数");
    }

    // 测试 callFunction - 宿主直接调用脚本函数
    {
        string script = "int add(int a, int b) { return a + b; } int multiply(int x, int y) { return x * y; }";
        auto handle = plvm.loadScript(script);
        
        // 直接调用 add 函数
        auto resultAdd = plvm.callFunction(handle, "add", 10, 20);
        assertTest(resultAdd.asInteger(), 30L, "callFunction: add(10, 20) = 30");
        
        // 直接调用 multiply 函数
        auto resultMul = plvm.callFunction(handle, "multiply", 6, 7);
        assertTest(resultMul.asInteger(), 42L, "callFunction: multiply(6, 7) = 42");
        
        // 带负数参数调用
        auto resultNeg = plvm.callFunction(handle, "add", -5, 10);
        assertTest(resultNeg.asInteger(), 5L, "callFunction: add(-5, 10) = 5");
    }

    // 测试 callFunction - 多参数函数
    {
        string script = "int sum3(int a, int b, int c) { return a + b + c; }";
        auto handle = plvm.loadScript(script);
        
        auto result = plvm.callFunction(handle, "sum3", 1, 2, 3);
        assertTest(result.asInteger(), 6L, "callFunction: sum3(1, 2, 3) = 6");
    }

    // 测试 callOnce 带参数 - 一次性调用脚本函数
    {
        string script = "int add(int a, int b) { return a + b; }";
        
        // 一次性调用：编译 + 执行 + 传递参数
        auto result = plvm.callOnce(script, "add", 100, 200);
        assertTest(result.asInteger(), 300L, "callOnce: add(100, 200) = 300");
    }

    // 测试 callOnce 带多个参数
    {
        string script = "int calc(int a, int b, int c) { return (a + b) * c; }";
        
        auto result = plvm.callOnce(script, "calc", 2, 3, 4);
        assertTest(result.asInteger(), 20L, "callOnce: calc(2, 3, 4) = 20");
    }

    // 测试 executeModuleWithEntry
    {
        string script3 = `
            int funcA() { return 100; }
            int funcB() { return 200; }
            int main() { return 300; }
        `;
        auto handle3 = plvm.loadScript(script3);
        
        // 查找 funcA 的入口点
        size_t entryA = 0;
        size_t entryB = 0;
        foreach (ref f; handle3.program.functions)
        {
            if (f.name == "funcA") entryA = f.entryPoint;
            if (f.name == "funcB") entryB = f.entryPoint;
        }
        
        auto resultA = plvm.executeModuleWithEntry(handle3, entryA);
        assertTest(resultA.asInteger(), 100L, "executeModuleWithEntry: funcA返回100");
        
        auto resultB = plvm.executeModuleWithEntry(handle3, entryB);
        assertTest(resultB.asInteger(), 200L, "executeModuleWithEntry: funcB返回200");
    }

    // 测试 executeModuleWithArgs - 带参数执行
    {
        string script4 = "int multiply(int x, int y) { return x * y; }";
        auto handle4 = plvm.loadScript(script4);
        
        size_t entry = 0;
        foreach (ref f; handle4.program.functions)
        {
            if (f.name == "multiply") entry = f.entryPoint;
        }
        
        // 使用 executeModuleWithArgs 传递参数
        Value[] args = [Value.makeLong(7), Value.makeLong(8)];
        auto result = plvm.executeModuleWithArgs(handle4, entry, args);
        assertTest(result.asInteger(), 56L, "executeModuleWithArgs: multiply(7, 8) = 56");
    }

    // ===================================================================
    // 总结
    // ===================================================================
    writeln("\n╔══════════════════════════════════════════════════════╗");
    writef("║  总计: %3d   通过: %3d   失败: %3d", stats.total, stats.passed, stats.failed);
    if (stats.failed > 0)
        writeln("  ║");
    else
        writeln("      ║");
    writeln("╚══════════════════════════════════════════════════════╝");

    return stats.failed > 0 ? 1 : 0;
}

void assertTest(T)(T actual, T expected, string desc)
{
    stats.total++;
    if (actual != expected)
    {
        writefln("  [× #%d] %s: 期望=%s  实际=%s", stats.total, desc, expected, actual);
        stats.failed++;
    }
    else
    {
        writefln("  [✓ #%d] %s: 结果=%s", stats.total, desc, actual);
        stats.passed++;
    }
}
