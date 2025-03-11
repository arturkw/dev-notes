
# Threads
## Methods `.interrupt()` and `.isInterrupted()`
```
public class Main {  
  
    public static void main(String[] args) {  
        Thread thread = new Thread(() -> {  
            boolean doWork = true;  
            while (doWork) {  
                try {  
                    Thread.sleep(500);  
                } catch (InterruptedException e) {  
                    doWork = false;  
                }  
                if (Thread.currentThread().isInterrupted()) {  
                    doWork = false;  
                    System.out.println("Computation interrupted..");  
                }  
            }  
        });  
  
        thread.start();  
        thread.interrupt();  
    }  
  
}
```


## Daemon Threads
Background threads that do not prevent the application from exiting if the main thread terminates. 

## Parallelization and Aggregation
Inherent cost of parallelization and aggregation:
- breaking task into subtasks
- threads creation for each tasks
- time between `thread.start` to thread getting scheduled
- time until the last thread finishes and signals 
- time until the aggregation thread runs and merges sub results into result

## Stack and Heap

### Stack
- Memory region where:
	- methods are called
	- arguments are passed
	- local variables are stored
- Stack + instruction pointer = state of each tread's execution

### Heap
- Objects (String, Object, Collection, ..)
- Member of classes
- static variables
- Governed and managed by Garbage Collector

## Atomic operations
- all read/write operations to primitive types except long/double are atomic
- if long/double variable is declared as `volatile` read/write operations are atomic

## Deadlock
```
/*

 * Copyright (c) 2019-2023. Michael Pogrebinsky - Top Developer Academy

 * https://topdeveloperacademy.com

 * All rights reserved

 */

  

import java.util.Random;

  

/**

 * Locking Strategies & Deadlocks

 * https://www.udemy.com/java-multithreading-concurrency-performance-optimization

 */

public class Main {

    public static void main(String[] args) {

        Intersection intersection = new Intersection();

        Thread trainAThread = new Thread(new TrainA(intersection));

        Thread trainBThread = new Thread(new TrainB(intersection));

  

        trainAThread.start();

        trainBThread.start();

    }

  

    public static class TrainB implements Runnable {

        private Intersection intersection;

        private Random random = new Random();

  

        public TrainB(Intersection intersection) {

            this.intersection = intersection;

        }

  

        @Override

        public void run() {

            while (true) {

                long sleepingTime = random.nextInt(5);

                try {

                    Thread.sleep(sleepingTime);

                } catch (InterruptedException e) {

                }

  

                intersection.takeRoadB();

            }

        }

    }

  

    public static class TrainA implements Runnable {

        private Intersection intersection;

        private Random random = new Random();

  

        public TrainA(Intersection intersection) {

            this.intersection = intersection;

        }

  

        @Override

        public void run() {

            while (true) {

                long sleepingTime = random.nextInt(5);

                try {

                    Thread.sleep(sleepingTime);

                } catch (InterruptedException e) {

                }

  

                intersection.takeRoadA();

            }

        }

    }

  

    public static class Intersection {

        private Object roadA = new Object();

        private Object roadB = new Object();

  

        public void takeRoadA() {

            synchronized (roadA) {

                System.out.println("Road A is locked by thread " + Thread.currentThread().getName());

  

                synchronized (roadB) {

                    System.out.println("Train is passing through road A");

                    try {

                        Thread.sleep(1);

                    } catch (InterruptedException e) {

                    }

                }

            }

        }

  

        public void takeRoadB() {

            synchronized (roadB) {

                System.out.println("Road B is locked by thread " + Thread.currentThread().getName());

  

                synchronized (roadA) {

                    System.out.println("Train is passing through road B");

  

                    try {

                        Thread.sleep(1);

                    } catch (InterruptedException e) {

                    }

                }

            }

        }

    }

}
```

## Locks
Do not forget to use `finally` block:
```
void foo() {
...
	try {
		lock.lock();
		//do stuff
	} finally {
		lock.unlock();
	}
...
}
```

Query methods:
- `getQueuedThreads()`
- `getOwner()`
- `isHeldByCurrentThread()`
- `isLocked()`

Lock fairness: `ReentrantLock(true)` (may reduce throughput)

`lock.lockInterruptibly()` - works as `.lock()` but allows to interrupt thread:
```
@Override
public void run() {
	while(true) {
		try {
			lock.lockInterruptibly();
			....		
		} catch(InterruptedException e) {
			//handle thread interruption 
		}
	}
}
```

`tryLock()`

### ReentrantReadWriteLock
Exclusion between readers and writers:
- if write lock is acquired, no thread can acquire a read lock
- if at least one thread holds read lock, no thread can acquire a write lock

## Semaphores
Differences with Locks
- semaphore doesn't have 'owner' thread
- Many threads can acquire a permit
- the same thread can acquire the semaphore multiple times
- semaphore can be release by any thread (even by a thread that hasn't acquired it)

### Producer - Consumer

```
Semaphore full = new Semaphore(0);
Semaphore empty = new Semapthore(CAPACITY);
Queue queue = new ArrayDeque();
Lock lock = new ReentrantLock();
```

Producer:
```
while(true) {
	Iten item = produceItem();
	empty.acquire();
	lock.lock();
	queue.offer(item);
	lock.unlock();
	full.release();
}
```

Consumer:
```
while(true) {
	full.acquire();
	lock.lock();
	Item item = queue.poll();
	lock.unlock();
	consume(item);
	empty.release();
}
```

## Condition 
```
Lock lock = new ReentrantLock();
Condition condition = lock.newCondition();

Thread 1:
lock.lock();
try {
	while(someCondition()) {
		condition.await();
	}
} finally {
	lock.unlock();
}

Thread 2:
lock.lock();
try {
	...
	condition.signal();
} finally {
	lock.unlock();
}
```

## wait(), notify(), notifyAll()

```

```

## Lock free
## Thread per task model vs thread per core model