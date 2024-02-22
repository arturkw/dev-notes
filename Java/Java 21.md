# Virtual Threads

Use builders to create Platform Thread:
```
var builder = Thread.ofPlatform().name("platform thread", 1);
for (int i = 0; i < 10; i++) {
   int j = i;
   Thread thread = builder.unstarted(() -> System.out.println(j));
   thread.start();
}
```

or Virtual Thread:
```
var latch = new CountDownLatch(10);
var builder = Thread.ofVirtual().name("virtual-", 1);
for (int i = 0; i < MAX_VIRTUAL; i++) {
   int j = i;
   Thread thread = builder.unstarted(() -> {
	   System.out.println(j);
	   latch.countDown();
	});
	thread.start();
}	
latch.await();
```

**Virtual Threads** vs **Platfrom Threads**
- by default do not have any name
- are deamon threads 
- are executed by Platform Thread (known as Carrier Thread, Fork Join Pool), I/O or sleep operations are parked.
- the Virtual Threads ARE NOT faster than Platform Threads.
- Virtual Threads have resizable stack. Platform Threads have fixed stack.
- PT are scheduled by the OS Scheduler.
- VT are scheduled by JVM, dedicated **ForkJoinPool** to schedule VT (core pool size = available processors).
- VT have default priority. Can not be modified.
- VT are configured via `jdk.virtualThreadScheduler.parallelism` and `jdk.virtualThreads.maxPoolSize`
- pinning VT: thread can not be unmounted from its carrier if executes **synchronized** method/blocks or native functions. Use **Locks** for resource synchronization if possible.
- use `jdk.tracePinnedThreads=full` to trace pinned threads
