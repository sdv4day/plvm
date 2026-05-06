
/+ dub.sdl:
    name "test_stringof"
+/
/*
测试 stringof 的输出是否恒定
*/
import std.stdio;

// 测试基础类型
pragma(msg, "=== 基础类型 ===");
pragma(msg, "void.stringof: ", void.stringof);
pragma(msg, "bool.stringof: ", bool.stringof);
pragma(msg, "int.stringof: ", int.stringof);
pragma(msg, "uint.stringof: ", uint.stringof);
pragma(msg, "long.stringof: ", long.stringof);
pragma(msg, "ulong.stringof: ", ulong.stringof);
pragma(msg, "char.stringof: ", char.stringof);
pragma(msg, "string.stringof: ", string.stringof);
pragma(msg, "wstring.stringof: ", wstring.stringof);
pragma(msg, "dstring.stringof: ", dstring.stringof);
pragma(msg);

// 测试类型别名
pragma(msg, "=== 类型别名 ===");
alias MyInt = int;
pragma(msg, "MyInt.stringof: ", MyInt.stringof);
pragma(msg, "is(MyInt == int): ", is(MyInt == int));
pragma(msg);

// 测试 const/immutable
pragma(msg, "=== 类型修饰符 ===");
pragma(msg, "const(int).stringof: ", const(int).stringof);
pragma(msg, "immutable(string).stringof: ", immutable(string).stringof);
pragma(msg, "is(const(int) == int): ", is(const(int) == int));
pragma(msg, "is(immutable(string) == string): ", is(immutable(string) == string));
pragma(msg);

// 测试类型比较在 is() 中的行为
pragma(msg, "=== is() 匹配 ===");
pragma(msg, "is(const int == int): ", is(const int == int));
pragma(msg, "is(immutable long == long): ", is(immutable long == long));
pragma(msg, "is(MyInt == int): ", is(MyInt == int));
pragma(msg);

void main()
{
    writeln("=== 运行时测试 ===");
    
    writeln("void.stringof: ", void.stringof);
    writeln("int.stringof: ", int.stringof);
    writeln("string.stringof: ", string.stringof);
    
    alias MyInt = int;
    writeln("MyInt.stringof: ", MyInt.stringof);
    
    writeln("const(int).stringof: ", const(int).stringof);
    
    writeln("\nis(MyInt == int): ", is(MyInt == int));
    writeln("is(const(int) == int): ", is(const(int) == int));
}
