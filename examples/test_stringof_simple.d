module examples.test_stringof_simple;

/+ dub.sdl:
    name "test_stringof_simple"
+/

import std.stdio;
import std.traits;

string typeToPlvmTypeNameSimple(T)()
{
    alias UT = Unqual!T;
    return UT.stringof;
}

void main()
{
    writeln("=== 测试简化版 typeToPlvmTypeName ===");
    
    writeln("void: ", typeToPlvmTypeNameSimple!void());
    writeln("bool: ", typeToPlvmTypeNameSimple!bool());
    writeln("int: ", typeToPlvmTypeNameSimple!int());
    writeln("uint: ", typeToPlvmTypeNameSimple!uint());
    writeln("long: ", typeToPlvmTypeNameSimple!long());
    writeln("ulong: ", typeToPlvmTypeNameSimple!ulong());
    writeln("char: ", typeToPlvmTypeNameSimple!char());
    writeln("string: ", typeToPlvmTypeNameSimple!string());
    writeln("wstring: ", typeToPlvmTypeNameSimple!wstring());
    writeln("dstring: ", typeToPlvmTypeNameSimple!dstring());
    
    writeln("\n=== 测试类型修饰符 ===");
    writeln("const(int): ", typeToPlvmTypeNameSimple!(const int)());
    writeln("immutable(string): ", typeToPlvmTypeNameSimple!(immutable string)());
    
    writeln("\n=== 测试类型别名 ===");
    alias MyInt = int;
    writeln("MyInt: ", typeToPlvmTypeNameSimple!MyInt());
    
    writeln("\n=== 测试自定义结构体 ===");
    struct Point { int x, y; }
    writeln("Point: ", typeToPlvmTypeNameSimple!Point());
}
