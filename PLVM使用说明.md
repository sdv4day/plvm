# PLVM 脚本引擎使用说明

## 目录
1. [概述](#概述)
2. [基础类型](#基础类型)
3. [控制流程](#控制流程)
4. [数组操作](#数组操作)
5. [结构体](#结构体)
6. [枚举类型](#枚举类型)
7. [Host 函数注册与调用](#host-函数注册与调用)
8. [完整示例](#完整示例)

---

## 概述

PLVM 是一个轻量级、可嵌入的 D 语言语法脚本引擎，支持 D 语言的核心特性子集。

### 特点
- 轻量级设计，零外部依赖
- 支持 D 语言 BetterC 子集
- 支持 Host 函数注册和调用
- 内置数组和结构体支持
- 支持步数限制，防止无限循环
- 完整的词法分析、语法分析、字节码编译和虚拟机执行

---

## 基础类型

### 支持的基本类型

| 类型 | 说明 | 示例 |
|------|------|------|
| `bool` | 布尔类型 | `bool flag = true;` |
| `byte` / `ubyte` | 8位整数 | `byte b = 127;` |
| `short` / `ushort` | 16位整数 | `short s = 32767;` |
| `int` / `uint` | 32位整数 | `int i = 42;` |
| `long` / `ulong` | 64位整数 | `long l = 1000L;` |
| `char` | 字符 | `char c = 'A';` |
| `string` | 字符串 | `string s = "Hello";` |

### 变量声明与赋值

```d
int x = 10;
long y;
y = 20;
string name = "World";
bool enabled = true;
```

### 运算符

#### 算术运算符
```d
int add(int a, int b) { return a + b; }
int sub(int a, int b) { return a - b; }
int mul(int a, int b) { return a * b; }
int div(int a, int b) { return a / b; }
int mod(int a, int b) { return a % b; }
int neg(int a) { return -a; }
```

#### 比较运算符
```d
bool eq(int a, int b) { return a == b; }
bool neq(int a, int b) { return a != b; }
bool lt(int a, int b) { return a < b; }
bool lte(int a, int b) { return a <= b; }
bool gt(int a, int b) { return a > b; }
bool gte(int a, int b) { return a >= b; }
```

#### 逻辑运算符
```d
bool and(bool a, bool b) { return a && b; }
bool or(bool a, bool b) { return a || b; }
bool not(bool a) { return !a; }
```

#### 位运算符
```d
int bit_and(int a, int b) { return a & b; }
int bit_or(int a, int b) { return a | b; }
int bit_xor(int a, int b) { return a ^ b; }
int bit_not(int a) { return ~a; }
int shl(int a, int b) { return a << b; }
int shr(int a, int b) { return a >> b; }
```

### 函数声明

```d
int add(int a, int b)
{
    return a + b;
}

void greet(string name)
{
    // 函数体
}

int main()
{
    return add(1, 2);
}
```

### 注释

```d
// 单行注释

/*
多行注释
跨越多行
*/

int main() // 行尾注释
{
    return 42;
}
```

---

## 控制流程

### if-else 语句

```d
int main()
{
    int x = 10;
    
    if (x > 5)
    {
        return 1;
    }
    
    if (x > 20)
    {
        return 2;
    }
    else
    {
        return 3;
    }
}
```

### while 循环

```d
int main()
{
    int sum = 0;
    int i = 0;
    while (i < 10)
    {
        sum = sum + i;
        i = i + 1;
    }
    return sum; // 返回 45
}
```

### do-while 循环

```d
int main()
{
    int sum = 0;
    int i = 0;
    do
    {
        sum = sum + i;
        i = i + 1;
    }
    while (i < 10);
    return sum;
}
```

### for 循环

```d
int main()
{
    int sum = 0;
    int i;
    for (i = 0; i < 10; i = i + 1)
    {
        sum = sum + i;
    }
    return sum;
}
```

### switch 语句

```d
int main()
{
    int x = 2;
    int result = 0;
    switch (x)
    {
        case 1:
            result = 10;
            break;
        case 2:
            result = 20;
            break;
        case 3:
            result = 30;
            break;
        default:
            result = 99;
            break;
    }
    return result; // 返回 20
}
```

### break 和 continue

```d
int main()
{
    int sum = 0;
    int i = 0;
    while (i < 20)
    {
        i = i + 1;
        if (i == 5)
            continue; // 跳过 i=5
        if (i == 15)
            break; // 在 i=15 时提前退出
        sum = sum + i;
    }
    return sum;
}
```

### 三元运算符

```d
int main()
{
    int x = 10;
    int y = x > 5 ? 100 : 0;
    return y; // 返回 100
}
```

---

## 数组操作

### 数组声明与初始化

```d
int main()
{
    // 数组字面量
    int[] arr = [1, 2, 3, 4, 5];
    
    // 空数组
    int[] emptyArr = [];
    
    return arr[0];
}
```

### 数组元素访问

```d
int main()
{
    int[] arr = [10, 20, 30, 40, 50];
    
    int first = arr[0];  // 10
    int third = arr[2];  // 30
    
    return first + third; // 返回 40
}
```

### 数组长度

```d
int main()
{
    int[] arr = [1, 2, 3, 4, 5];
    return arr.length; // 返回 5
}
```

### 数组遍历

```d
int main()
{
    int[] arr = [1, 2, 3, 4, 5];
    int sum = 0;
    int i = 0;
    
    while (i < arr.length)
    {
        sum = sum + arr[i];
        i = i + 1;
    }
    
    return sum; // 返回 15
}
```

### 数组完整示例

```d
int main()
{
    int[] numbers = [1, 2, 3, 4, 5];
    
    // 访问元素
    int first = numbers[0];
    
    // 计算数组和
    int sum = 0;
    int i = 0;
    while (i < numbers.length)
    {
        sum = sum + numbers[i];
        i = i + 1;
    }
    
    return sum; // 返回 15
}
```

---

## 结构体

### 结构体定义

```d
struct Point
{
    int x;
    int y;
}
```

### 结构体声明与赋值

```d
int main()
{
    Point p;
    p.x = 10;
    p.y = 20;
    return p.x + p.y; // 返回 30
}
```

### 结构体作为函数参数

```d
struct Point
{
    int x;
    int y;
}

int distance(Point a, Point b)
{
    int dx = a.x - b.x;
    int dy = a.y - b.y;
    return dx * dx + dy * dy;
}

int main()
{
    Point p1;
    p1.x = 0;
    p1.y = 0;
    
    Point p2;
    p2.x = 3;
    p2.y = 4;
    
    return distance(p1, p2); // 返回 25
}
```

### 结构体完整示例

```d
struct Rect
{
    int width;
    int height;
}

int area(Rect r)
{
    return r.width * r.height;
}

int main()
{
    Rect r;
    r.width = 10;
    r.height = 20;
    return area(r); // 返回 200
}
```

---

## 枚举类型

### 枚举定义

```d
enum Color
{
    Red,
    Green,
    Blue
}
```

### 枚举使用

```d
enum Color
{
    Red,
    Green,
    Blue
}

int main()
{
    Color c = Color.Green;
    int value = cast(int)c;
    
    if (c == Color.Red)
        return 0;
    else if (c == Color.Green)
        return 1;
    else if (c == Color.Blue)
        return 2;
    
    return -1;
}
```

### 枚举完整示例

```d
enum Status
{
    Ok = 0,
    Warning = 1,
    Error = 2
}

int main()
{
    Status s = Status.Warning;
    int code = cast(int)s;
    return code; // 返回 1
}
```

---

## Host 函数注册与调用

### 什么是 Host 函数

Host 函数是宿主程序中定义的函数，通过 PLVM 的 Host API 注册后，可以被脚本代码调用。

### Host API 使用

#### 1. 创建 Plvm 实例

```d
import plvm;

void main()
{
    Plvm vm = new Plvm();
}
```

#### 2. 注册 Host 函数

```d
import plvm;

int add(int a, int b)
{
    return a + b;
}

int multiply(int a, int b)
{
    return a * b;
}

void main()
{
    Plvm vm = new Plvm();
    
    vm.registerFunction("add", &add);
    vm.registerFunction("multiply", &multiply);
}
```

### Host 函数参数和返回值

Host 函数支持以下类型作为参数和返回值：

| D 类型 | PLVM 类型 |
|---------|----------|
| `int` | `Value.makeInteger()` |
| `long` | `Value.makeInteger()` |
| `uint` | `Value.makeInteger()` |
| `ulong` | `Value.makeInteger()` |
| `bool` | `Value.makeBool()` |
| `char` | `Value.makeChar()` |
| `string` | `Value.makeString()` |

### Host 函数示例

#### 示例 1：简单算术函数

```d
// Host 端代码
import plvm;

int hostAdd(int a, int b) { return a + b; }
int hostSub(int a, int b) { return a - b; }
int hostMul(int a, int b) { return a * b; }
int hostDiv(int a, int b) { return a / b; }

void main()
{
    Plvm vm = new Plvm();
    vm.registerFunction("hostAdd", &hostAdd);
    vm.registerFunction("hostSub", &hostSub);
    vm.registerFunction("hostMul", &hostMul);
    vm.registerFunction("hostDiv", &hostDiv);
    
    string script = `
        int main()
        {
            int a = hostAdd(10, 20);
            int b = hostMul(a, 2);
            return b;
        }
    `;
    
    Value result = vm.callOnce(script);
    assert(result.asInteger() == 60);
}
```

#### 示例 2：字符串处理

```d
// Host 端代码
import plvm;

string hostConcat(string a, string b)
{
    return a ~ b;
}

bool hostStartsWith(string str, string prefix)
{
    return str.length >= prefix.length && str[0..prefix.length] == prefix;
}

void main()
{
    Plvm vm = new Plvm();
    vm.registerFunction("hostConcat", &hostConcat);
    vm.registerFunction("hostStartsWith", &hostStartsWith);
    
    string script = `
        int main()
        {
            string s1 = "Hello";
            string s2 = "World";
            string s3 = hostConcat(s1, s2);
            if (hostStartsWith(s3, "Hello"))
                return 1;
            else
                return 0;
        }
    `;
    
    Value result = vm.callOnce(script);
    assert(result.asInteger() == 1);
}
```

#### 示例 3：实用工具函数

```d
// Host 端代码
import plvm;

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

void main()
{
    Plvm vm = new Plvm();
    vm.registerFunction("hostSumTo", &hostSumTo);
    vm.registerFunction("hostIsPrime", &hostIsPrime);
    vm.registerFunction("hostMax", &hostMax);
    
    string script = `
        int main()
        {
            int sum = hostSumTo(10); // 55
            bool prime5 = hostIsPrime(5); // true
            bool prime4 = hostIsPrime(4); // false
            int max = hostMax(100, 200); // 200
            
            if (prime5 && !prime4)
                return sum + max;
            else
                return 0;
        }
    `;
    
    Value result = vm.callOnce(script);
    assert(result.asInteger() == 255);
}
```

---

## 完整示例

### 示例 1：简单计算器

```d
struct Calculator
{
    int result;
}

int calculate(Calculator calc, string op, int a, int b)
{
    if (op == "+")
        return a + b;
    else if (op == "-")
        return a - b;
    else if (op == "*")
        return a * b;
    else if (op == "/")
        return a / b;
    else
        return 0;
}

int main()
{
    Calculator calc;
    calc.result = calculate(calc, "+", 10, 20);
    return calc.result;
}
```

### 示例 2：数组求和与平均

```d
int sumArray(int[] arr)
{
    int sum = 0;
    int i = 0;
    while (i < arr.length)
    {
        sum = sum + arr[i];
        i = i + 1;
    }
    return sum;
}

int main()
{
    int[] numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    int total = sumArray(numbers);
    return total; // 返回 55
}
```

### 示例 3：Host 函数与脚本结合

```d
// ==========================================
// Host 端代码 (D 程序)
// ==========================================
import plvm;

int hostFactorial(int n)
{
    if (n <= 1)
        return 1;
    return n * hostFactorial(n - 1);
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

void main()
{
    Plvm vm = new Plvm();
    vm.registerFunction("hostFactorial", &hostFactorial);
    vm.registerFunction("hostGCD", &hostGCD);
    
    // ==========================================
    // 脚本代码
    // ==========================================
    string script = `
        int main()
        {
            int fact5 = hostFactorial(5); // 120
            int gcd1 = hostGCD(12, 18); // 6
            int gcd2 = hostGCD(7, 13); // 1
            return fact5 + gcd1 + gcd2; // 127
        }
    `;
    
    Value result = vm.callOnce(script);
    assert(result.asInteger() == 127);
}
```

---

## 常见问题

### Q: 支持指针操作吗？
A: 不支持。PLVM 只支持 BetterC 子集的核心功能，不包含指针操作。

### Q: 支持类和接口吗？
A: 不支持。只支持结构体（struct）和枚举（enum）。

### Q: 支持异常处理吗？
A: 不支持。PLVM 是 BetterC 子集，不包含异常处理。

### Q: 支持动态内存分配吗？
A: 数组和结构体内置支持，但是没有 `new` 关键字。

### Q: 最大步数限制如何设置？
A: 在 VM 执行前调用 `setMaxSteps()` 方法：
```d
vm.setMaxSteps(1000000); // 限制为 100 万步
```

---

## 版本历史

### v0.1.0
- 初始版本发布
- 支持基础类型和控制流程
- 支持数组操作
- 支持结构体和枚举
- 支持 Host 函数注册和调用

---

## 技术支持

如有问题或建议，请查看项目文档或提交 Issue。

**祝您使用愉快！**
