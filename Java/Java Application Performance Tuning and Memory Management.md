
# Bytecode and Just in Time Compilation

Bytecode is executed by the JVM. Compiler converts java code into bytecode which is a set of instructions that the JVM can understand and execute. Bytecode is platform independent - the same code can run on different operating systems - "write once, run anywhere". 

JIT compiles bytecode into the machine code that can be run by the processor. It runs complex optimizations to generate efficient machine code. There are two JIT compilers: C1 and C2. C1 is designed to run faster and produces less optimized code. C2 produces a better optimized code but it takes more time. Compiled code is stored in code cache.

Useful flags:
- -XX:+UnlockDiagnosticVMOptions
- -XX:+LogCompilation
- -XX:+PrintCompilation
- -XX:+PrintCodeCache
- -client - use client compiler only
- -server - use server compiler
- -d64 - user 64 bit server compiler
- -XX:-TieredCompilation - disable tiered compilation
- -XX:+PrintFlagsFinal
- -XX:CompileThreshold=1000

Useful commands:
- jinfo -flag CICompilerCount pid
- jps

32 bit JVM:
- might be faster if heap < 3GB
- Max heap size = 4GB
- Client compiler only

64 bit JVM:
- Might be faster if using long/double
- Necessary if heap > 4GB
- Max heap size - OS dependent
- Client & server compilers

# The heap and the stack

Stack:
- every thread has its own stack
- new data is pushed on the top
- data is popped from the top
- for storing local primitives 
- pointer (reference) to complex objects

Heap:
- stores complex objects
- is shared between all the threads

Links:
- [Chapter 6. The Java Virtual Machine Instruction Set (oracle.com)](https://docs.oracle.com/javase/specs/jvms/se11/html/jvms-6.html)
- [Java Virtual Machine Technology Overview (oracle.com)](https://docs.oracle.com/en/java/javase/21/vm/java-virtual-machine-technology-overview.html#GUID-982B244A-9B01-479A-8651-CB6475019281)
- [Byte Buddy - runtime code generation for the Java virtual machine](https://bytebuddy.net/#/)
- [ASM (ow2.io)](https://asm.ow2.io/)
- [Javassist by jboss-javassist](https://www.javassist.org/)
- [15 Codecache Tuning (Release 8) (oracle.com)](https://docs.oracle.com/javase/8/embedded/develop-apps-platforms/codecache.htm)

# Source
[Course: Java Application Performance Tuning and Memory Management](https://eylearning.udemy.com/course/java-application-performance-and-memory-management/learn/lecture/14402490#overview)