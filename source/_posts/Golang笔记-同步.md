---
title: Golang笔记-同步
tags: [Golang,同步,锁,原子操作,条件变量]
comments: true
categories: [Golang]
date: 2018-05-05 18:49:17
---
## 锁
### 互斥锁
传统并发程序对共享资源进行访问控制的主要手段，由标准库代码包sync中的Mutex结构体类型表示。其有两个公开的指针方法——Lock和Unlock，前者用于锁定当前的互斥量，后者用于对当前的互斥量进行解锁。

sync.Mutex类型的零值表示未锁定的互斥量。声明：
```code
var mutex sync.Mutex
```
一般在锁定互斥量后，紧接着使用defer语句保证该互斥锁的及时解锁。
```
var mutex sync.Mutex

func write () {
    mutex.Lock()
    defer mutex.Unlock()
    //todo
}
```
锁定操作和解锁操作应该成对出现，锁定了一个已锁定的互斥锁，进行重复锁定操作的goroutine将被阻塞，直到该互斥锁回到解锁状态。

code example:
```code
package main

import (
	"fmt"
	"sync"
	"time"
)

func main() {
	var mutex sync.Mutex
	fmt.Println("Lock the lock. (main)")
	mutex.Lock()
	fmt.Println("The lock is locked. (main)")
	for i := 1; i <= 3; i++ {
		go func(i int) {
			fmt.Printf("Lock the lock. (g%d)\n", i)
			mutex.Lock()
			fmt.Printf("The lock is locked. (g%d)\n", i)
		}(i)
	}
	time.Sleep(time.Second)
	fmt.Println("Unlock the lock. (main)")
	mutex.Unlock()
	fmt.Println("The lock is unlocked. (main)")
	time.Sleep(time.Second)
}
```
result:
```code
[root@localhost lock]# go run repeatedlylock.go
Lock the lock. (main)
The lock is locked. (main)
Lock the lock. (g1)
Lock the lock. (g2)
Lock the lock. (g3)
Unlock the lock. (main)
The lock is unlocked. (main)
The lock is locked. (g1)
```
对一个未锁定的互斥锁进行解锁操作，会引发一个运行时恐慌，Go 1.8之前可使用defer语句避免，Go 1.8开始此类恐慌变成不可恢复。

### 读写锁
读写锁即针对读写操作的互斥锁，可以针对读操作和写操作进行锁定和解锁操作。读写锁控制下的多个写操作都是互斥的，并且写操作与读操作之间也是互斥的，多个读操作之间不存在互斥关系。

读写锁由结构体sync.RWMutex表示，类型的零值已是可用的读写锁实例。包含两对方法：
```code
func (*RWMutex) Lock()
func (*RWMutex) Unlock()
```
和
```code
func (*RWMutex) RLock()
func (*RWMutex) RUnlock()
```
前一对方法的名称和签名与互斥锁的两个方法完全一致，分别代表对写操作的锁定（写锁定）和解锁（写解锁）。后一对方法表示了对读操作的锁定（读锁定）和解锁（读解锁）。

写解锁会试图唤醒所有因欲进行读操作而被阻塞的goroutine，读解锁只会在已无任何读锁定的情况下，试图唤醒一个因欲进行写操作而被阻塞的goroutine。`对一个未被写锁定的读写锁进行写解锁，或者对一个未被读锁定的读写锁进行读解锁，都会引发一个不可恢复的运行时恐慌。`

对于一个读写锁来说，施加于其上的读锁定可以有多个，只有对互斥锁进行等量的读解锁，才能够让某一个写锁定获得进行的机会，否则会使欲进行写锁定的gouroutine一直处于阻塞状态。

code example：
```code
package main

import (
	"fmt"
	"sync"
	"time"
)

func main() {
	var rwm sync.RWMutex
	for i := 0; i < 3; i++ {
		go func(i int) {
			fmt.Printf("Try to lock for reading... [%d]\n", i)
			rwm.RLock()
			fmt.Printf("Locked for reading. [%d]\n", i)
			time.Sleep(time.Second * 2)
			fmt.Printf("Try to unlock for reading... [%d]\n", i)
			rwm.RUnlock()
			fmt.Printf("Unlocked for reading. [%d]\n", i)
		}(i)
	}
	time.Sleep(time.Millisecond * 100)
	fmt.Println("Try to lock for writing...")
	rwm.Lock()
	fmt.Println("Locked for writing.")
}
```
result：
```code
[root@localhost rlock]# go run rlock.go
Try to lock for reading... [0]
Try to lock for reading... [2]
Locked for reading. [2]
Try to lock for reading... [1]
Locked for reading. [1]
Locked for reading. [0]
Try to lock for writing...
Try to unlock for reading... [0]
Unlocked for reading. [0]
Try to unlock for reading... [2]
Unlocked for reading. [2]
Try to unlock for reading... [1]
Unlocked for reading. [1]
Locked for writing.
```
sync.RWMutex类型还拥有一个指针方法——RLocker，该方法会返回一个实现了sync.Locker接口类型的值。该接口包含两个方法：Lock和Unlock，\*sync.Mutex类型和\*sync.RWMutex类型都是该接口类型的实现类型。调用读写锁的RLocker方法，得到的结果值是读写锁本身，结果值的Lock方法和Unlock方法分别对应了针对读写锁的读锁定操作和读解锁操作。

## 条件变量
标准库sync.Cond类型代表了条件变量，不同于互斥锁和读写锁，简单的声明无法创建一个可用的条件变量，需用sync.NewCond函数。函数声明为：
```code
func NewCond(l Locker) *Cond
``` 
条件变量要与互斥量组合使用，sync.NewCond函数的唯一参数是sync.Locker类型，具体的参数值既可以是一个互斥锁也可以是一个读写锁。返回一个\*sync.Cond类型的结果值，该类型有3个方法，即：Wait、Signal和Broadcast，分别代表了等待通知、单发通知和广播通知的操作。

Wait方法自动对与该条件变量关联的锁进行解锁，并使它所在的goroutine阻塞，一旦接收到通知该方法所在的goroutine就会被唤醒，该方法会立即尝试锁定该锁。方法Signal和BroadCast的作用都是发送通知，以唤醒正在为此阻塞的goroutine，前者目标只有一个，后者目标是所有。

在只需对一个或多个临界区进行保护的时候，使用锁往往会使程序的性能损耗更小。

## 原子操作
原子操作即执行过程不能被中断的操作，针对某个值的原子操作执行过程当中，CPU绝不会再去执行其他针对该值的操作，无论这些操作是否为原子操作。

Go提供的原子操作都是非侵入式的，由标准库代码包sync/atomic中的众多函数代表，可以通过调用这些函数对几种简单类型的值执行原子操作。类型包括int32、int64、uint32、uint64、uintptr和unsafe.Pointer。这些函数提供的原子操作共有5种：增或减、比较并交换、载入、存储和交换。分别提供了不同的功能，且适用的场景也有所区别。
### 增或减
用于增或减的原子操作（原子增/减操作）的函数名都以 “Add”为前缀，后跟针对具体类型的名称。原子增/减操作可实现被操作值的增大或减小。被操作值的类型只能是数值类型(int32、int64、uint32、uint64和uintptr)。例如对int32类型的变量i32的值增大3：
```code
mewi32 := atomic.AddInt32(&i32, 3)
```
对于不能被取址的数值无法进行原子操作，函数第二个参数的类型与被操作值的类型总是相同的。类似函数有atomic.AddInt64、atomic.AddUint32、atomic.AddUint64和atomic.AddUintptr。因atomic.AddUint32、atomic.AddUint64的第二个参数类型分别是uint32和uint64，无法传入通过传入一个负的数值来减小被操作值。可利用二进制补码的特性解决：
```code
atomic.AddUint32(&uint32, ^uint32(-NN-1))
atomic.AddUint64(&uint64, ^uint64(-NN-1))
//NN代表一个负整数
```
负整数的补码可通过对它按位（除符号位）求反码并加一得到，一个负整数可由对它的绝对值减一并求补码后得到的数值的二进制形式表示。
>uint32(int32(NN)) = ^uint32(-NN-1)

不存在名为atomic.AddPointer的函数，unsafe.Pointer类型的值无法被加减。

### 比较并交换
Compare And Swap简称CAS，在sync/atomic包中，此类原子操作名称以“CompareAndSwap”为前缀的若干函数代表。
针对int32类型值的函数声明如下：
```code
func CompareAndSwapInt32(addr *int32, old, new int32) (swapped bool)
```  
接受3个参数，参数一的值指向被操作值的指针值，类型为*int32。后两个参数分别代表操作的旧值和新值，类型为int32。函数被调用之后，会先判断参数addr指向的被操作值与参数old的值是否相等，判断结果为true，函数会用参数new代表的新值替换旧值，否则替换操作被忽略。函数结果swapped表示是否进行了值的替换操作。

CAS操作总是假设被操作值未曾改变（即与旧值相等），并一旦确认假设的真实性就立即进行值替换。不同于锁更加谨慎的做法，总是假设会有并发的操作修改被操作值，使用锁将相关操作放入临界区中加以保护。使用锁趋于悲观，CAS趋于乐观。

CAS可以在不创建互斥量和不形成临界区的情况下，完成并发安全的值替换操作。可以减少同步对程序性能的损耗。但在被操作的值频繁变更的情况下，CAS操作并不容易成功。有时需要使用for循环进行多次尝试。CAS操作不会让goroutine阻塞，但是仍可能使流程的执行暂时停滞，停滞大都极为短暂。若想并发安全的更新一些类型的值，总是优先选择CAS操作。

### 载入
sync/atomic代码包提供一系列函数可以原子地读取某个值，以“Load”为前缀。以int32类型为例：
```code
func addValue(delta int32) {
    for {
        v := atomic.LoadInt32(&value)
        if atomic.CompareAndSwapInt32(&value, v, (v + delta)){
            break
        }
    }
} 
```
atomic.LoadInt32接受一个*int32类型的指针值，返回该指针值指向的那个值。此示例原子地读取变量value的值并把它赋给变量v。在读取value时，当前计算机中的任何CPU都不会进行其他针对此值的读写操作。赋值语句和其后的if语句并不会原子地执行，在它们执行期间，CPU仍然可能进行其他针对value的读写操作，即value的值仍然能会被改变。所以if语句仍然需要CAS操作。

### 存储
对应读取操作的写入操作，sync/atomic包提供了对应的存储函数，函数名称以“Store”为前缀。

在原子地存储某个值的过程中，任何CPU都不会进行针对同一个值的读写操作。若把所有针对此值的写操作都改为原子操作，可避免出现针对此值的读操作因被并发地进行，而读到修改了一半的值的情况。

原子的值存储操作总会成功，不关心存储的值的旧值是什么。例atomic.StoreInt32接受两个参数，参数一的类型是*int32，指向被操作数的指针值，参数二是int32类型，值是欲存储的新值。

### 交换
sync/atomic代码包存在一类函数与前文的CAS操作和原子载入操作相似，称为“原子交换操作”，名称以“Swap”为前缀。

不同于CAS，原子交换操作不关心被操作值的旧值，直接设置新值，比原子存储操作多了一步：返回被操作值的旧值，比CAS操作的约束更少，比原子载入操作的功能更强。

例atomic.SwapInt32函数，接受两个参数，参数一代表被操作值的内存地址的*int32类型值，参数二表示新值。函数结果值表示该新值替换掉的旧值。该函数调用后，会把参数二的值置于参数一所表示的内存地址上，并将之前在该地址上的那个值作为结果返回。

若想以并发安全的方式操作特定的简单类型值，应首先考虑使用这些函数实现。

### 原子值
sync/atomic.Value是一个结构体类型，暂且称为“原子值类型”。用于存储需要原子读写的值。不同于sync/atomic包中的其他函数，sync/atomic.Value可接受的被操作值的类型不限。简单声明即可得到一个可用的原子值实例：
```code
var atomicVal atomic.Value
```
该类型包含两个指针方法——Load和Store。前者用于原子地读取原子值实例中存储的值，返回一个interface{}类型的结果且不接受任何参数。后者用于原子地在原子值实例中存储一个值，接受一个interface{}类型的参数而没有返回结果。在未曾通过Store方法向原子值实例存储值之前，它的Load方法总会返回nil。

原子值实例的Store方法参数值不能为nil，参数传入该方法的值与之前传入的值（若有）的类型相同。即一旦原子值实例存储了某一个类型的值，它之后存储的值就必须是该类型的。违反上述条件会引发一个运行时恐慌。

sync/atomic.Value类型的变量一旦被声明，其值就不应该复制到它处。`作为源值赋给变量、作为参数值传入函数、作为结果值从函数中返回、作为元素值通过通道传递等都会造成值的复制`，这些变量之上不应该施加这些操作。不会造成编译错误，但标准工具go  vet会报告此类不正确（具有安全隐患）的用法。sync/atomic.Value类型的指针类型的变量不存在此问题。因结构体值的复制不但会生成该值的副本，还会生成其中字段的副本，使施加于此的并发安全保护失效。向副本存储值的操作与原值无关。

对于sync包中的Mutex、RWMutex和Cond类型，go vet命令同样检查此类复制问题，解决方案是避免使用它们而是使用它们的指针值。

原子值的读写操作必是原子的，不受操作值类型的限制，比原子函数的适用场景大，某些时候可以完美替换。


`检测程序是否存在竞态条件，可在运行或者测试程序的时候追加-race标记。监测结果会被打印到输出中。`
## 只会执行一次
sync提供了具有特色的结构体类型sync.Once和它的Do方法。
```code
var once sync.Once
once.Do(func(){fmt.Println("Once!")})
```
Do接受一个无参数、无结果的函数值作为其参数，方法一旦被调用，就会去调用作为参数的那个函数。

对同一个sync.Once类型值的Do方法的有效调用次数永远会是1。无论调用这个方法多少次，无论在多次调用时传递给它的参数值是否相同，都仅有第一次调用是有效的，值有第一次调用该方法传递给它的那个函数会执行。

典型应用场景是执行仅需执行一次的任务，这样的任务并不适合在init函数中执行。例如数据库连接池的建立、全局变量的延迟初始化等。

`sync.Once类型提供的功能由互斥锁和原子操作实现。使用的技巧包括卫述语句、双重检查锁定，以及对共享标记的原子读写操作。`

## WaitGroup
sync.WaitGroup类型的值是并发安全的，声明后即可使用，有3个指针方法：Add、Done和Wait。

sync.WaitGroup是一个结构体类型，有一个代表计数的字节数组类型的字段，该字段用4字节表示给定的计数，另用4字节表示等待计数。当一个sync.WaitGroup类型的变量被声明之后，这两个计数都会是0。通过该值的Add方法增大或减少给定计数。
```code
var wg sync.WaitGroup
wg.Add(3)
wg.Add(-3)
```
不能让给定计数变为负数，会引发一个运行时恐慌，意味着对sync.WaitGroup类型值的错误使用。

也可通过该值的Done方法使其中的给定计数值减一。
```code
wg.Done()
wg.Done()
wg.Done()
```
同Add方法不能使给定计数变为负数。

当调用sync.WaitGroup类型值的Wait方法时，它会去检查给定计数，若该计数为0，该方法会立即返回，且不会对程序的运行产生任何影响。若计数大于0，该方法调用所在的goroutine会阻塞，同时等待计数会加1。直到该值的Add方法或Done方法被调用时发现给定计数变为0，该值才去区唤醒因此而阻塞的所有goroutine，同时清零等待计数。不论时Add方法还是Done方法，唤醒的goroutine是在从给定计数最近一次从0变为正整数到此时（给定计数重新变为0时）的时间段内，执行当前值的Wait方法的goroutine。

`sync.WaitGroup类型值一般用于协调多个goroutine的运行。`

使用规则：  
* 对同一sync.WaitGroup类型值的Add方法的第一次调用，发生在调用该值的Done方法和Wait方法之前。
* 在一个sync.WaitGroup类型值的生命周期内，其中的给定计数总是由起初的0变为某个正整数（或先后变为某几个正整数），然后再归为0。把完成这样一个变化所用的时间称为一个计数周期。
* 给定计数的每次变化都是由对Add方法或Done方法的调用引起的。
* sync.WaitGroup类型值可以复用。此类型的生命周期可以包含任意个计数周期。一个sync.WaitGroup类型值在其每个计数周期中的状态和作用都是独立的。

`对于sync.WaitGroup类型的值，也时不应该复制的，在必要时使用go vet命令检查使用此类型值的方式是否正确。`

## 临时对象池
可将sync.Pool类型值看作存放临时值的容器。此类容器是自动伸缩的、高效的、并发安全的。为描述方便将sync.Pool类型的值称为“临时对象池”，存于其中的值称为“对象值”。

使用符合字面量初始化一个临时对象池的时候，可以为它唯一的公开字段New赋值。该字段类型是func () interface {}，即一个函数类型。赋给该字段的值会被临时对象池用来创建对象值。该函数一般仅在池中无可用对象值的时候才被调用。把这个函数称为“对象值生成函数”。

sync.Pool类型有两个公开的指针方法——Get和Put。前者从池中获取一个interface {}类型的值，后者则是把一个interface {}类型的值放置于池中。

通过Get方法获取到的值是任意的。若一个临时对象池的Put方法未被调用过,且它的New字段也未曾被赋予一个非nil的函数值，那么它的Get方法返回的结果就一定是nil。Get方法回返的不一定就是存在于池中的值，若结果值是池中的，那么在该方法返回它之前，就一定会把它从池中删除。功能上类似一个通用的缓冲池。

临时对象池的第一个特征，临时对象池可以把其中的对象值产生的存储压力进行分摊。它会专门为每一个与操作它的goroutine相关联的P建立本地池。在临时对象池的Get方法被调用时，一般会先尝试从与本地P对应的本地私有池和本地共享池中或取一个对象值。若获取失败，会尝试从其他P的本地共享池中偷取一个对象值并直接返回给调用方。若仍未获取，只能希望寄托于当前临时对象池的对象值生成函数。对象值生成函数产生的对象值永远不会被放置到池中，而是被直接返回给调用方。临时对象池的Put方法会把它的参数值存放到本地P的本地池中。每个相关P的本地共享池中的所有对象值，都是在当前临时对象池的范围内共享的。即它们随时会被偷走。

临时对象池的第二个特征是对垃圾回收友好。垃圾回收的执行一般会使临时对象池中的对象值全部被移除。即使我们永远不会显示地从临时对象池取走某个对象值,该对象也不会永远待在临时对象池中，它的声明周期取决于垃圾回收任务下一次的执行时间。

不用该对从临时对象池中获取的值有任何假设，因其可能是池中的任何一个值，也可能是对象值生成函数产生的值。

`临时对象池的实例也不应该被复制，否则go vet命令将报告此问题。`

