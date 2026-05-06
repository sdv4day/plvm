module examples.example_all_features;

/*
PLVM 完整功能示例
演示数组、结构体、Host 函数等所有特性
*/

// ==========================================
// 1. 基础类型示例
// ==========================================
int basicTypes()
{
    bool flag = true;
    int x = 42;
    long y = 100L;
    char c = 'A';
    string s = "Hello";
    
    return x;
}

// ==========================================
// 2. 算术运算示例
// ==========================================
int arithmeticOps()
{
    int a = 10;
    int b = 3;
    int sum = a + b;       // 13
    int diff = a - b;      // 7
    int product = a * b;   // 30
    int quotient = a / b;  // 3
    int remainder = a % b; // 1
    int neg = -a;          // -10
    
    return sum + diff + product;
}

// ==========================================
// 3. 比较运算示例
// ==========================================
int comparisonOps()
{
    int result = 0;
    if (5 == 5) result = result + 1;
    if (5 != 3) result = result + 1;
    if (3 < 5) result = result + 1;
    if (5 > 3) result = result + 1;
    if (3 <= 5) result = result + 1;
    if (5 >= 3) result = result + 1;
    return result;
}

// ==========================================
// 4. 逻辑运算示例
// ==========================================
int logicalOps()
{
    int result = 0;
    if (true && true) result = result + 1;
    if (true || false) result = result + 1;
    if (!false) result = result + 1;
    return result;
}

// ==========================================
// 5. 数组操作示例
// ==========================================
struct Point
{
    int x;
    int y;
}

int arrayExample()
{
    int[] arr = [1, 2, 3, 4, 5];
    
    // 计算数组和
    int sum = 0;
    int i = 0;
    while (i < arr.length)
    {
        sum = sum + arr[i];
        i = i + 1;
    }
    
    return sum;
}

// ==========================================
// 6. 结构体示例
// ==========================================
struct Rect
{
    int width;
    int height;
}

int area(Rect r)
{
    return r.width * r.height;
}

int structExample()
{
    Rect r;
    r.width = 10;
    r.height = 20;
    return area(r);
}

// ==========================================
// 7. 点结构体示例
// ==========================================
Point createPoint(int x, int y)
{
    Point p;
    p.x = x;
    p.y = y;
    return p;
}

int pointExample()
{
    Point p1;
    p1.x = 0;
    p1.y = 0;
    
    Point p2;
    p2.x = 3;
    p2.y = 4;
    
    int dx = p2.x - p1.x;
    int dy = p2.y - p1.y;
    
    return dx * dx + dy * dy;
}

// ==========================================
// 8. 控制流示例
// ==========================================
int ifElseExample()
{
    int x = 15;
    if (x > 20)
        return 1;
    else if (x > 10)
        return 2;
    else
        return 3;
}

int whileExample()
{
    int sum = 0;
    int i = 0;
    while (i < 10)
    {
        sum = sum + i;
        i = i + 1;
    }
    return sum;
}

int forExample()
{
    int sum = 0;
    int i;
    for (i = 1; i <= 10; i = i + 1)
    {
        sum = sum + i;
    }
    return sum;
}

int switchExample()
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
    return result;
}

int breakContinueExample()
{
    int sum = 0;
    int i = 0;
    while (i < 20)
    {
        i = i + 1;
        if (i == 5)
            continue;
        if (i == 15)
            break;
        sum = sum + i;
    }
    return sum;
}

int ternaryExample()
{
    int x = 10;
    return x > 5 ? 100 : 0;
}

// ==========================================
// 9. 递归示例
// ==========================================
int factorial(int n)
{
    if (n <= 1)
        return 1;
    return n * factorial(n - 1);
}

int fibonacci(int n)
{
    if (n <= 1)
        return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// ==========================================
// 10. 主函数 - 运行所有示例
// ==========================================
int main()
{
    int total = 0;
    
    total = total + basicTypes();
    total = total + arithmeticOps();
    total = total + comparisonOps();
    total = total + logicalOps();
    total = total + arrayExample();
    total = total + structExample();
    total = total + pointExample();
    total = total + ifElseExample();
    total = total + whileExample();
    total = total + forExample();
    total = total + switchExample();
    total = total + breakContinueExample();
    total = total + ternaryExample();
    total = total + factorial(5);
    total = total + fibonacci(5);
    
    return total;
}
