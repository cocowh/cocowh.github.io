---
title: Golang笔记-goroutine
tags: [Golang,go语句,goroutine]
comments: true
categories: [Golang]
date: 2018-05-02 14:35:11
---
go语句是启用goroutine的唯一途径。
## go语句与Goroutine
一条go语句意味着一个函数或方法的并发执行，由go关键字和表达式组成。针对如下函数的调用表达式不能称为表达式语句：append、cap、complex、imag、len、make、new、real、unsafe.Alignof、unsafe.Offsetof和unsafe.Sizeof。前8个函数是Go语言的内建函数，后3个函数是标准库代码包unsafe中的函数。

>code example:
```code
go println("Go! Goroutine!")
---
go func(){
    println("Go! Goroutine!")
}()
```

Go语言的运行时系统对go语句中的函数或方法（go函数）的执行是并发的，当go语言被执行的时候，其中的go函数会被单独地放入到一个goroutine中，该go函数的执行会独立于当前goroutine的运行。go函数并发执行，但执行的先后顺序不确定。

当go函数被执行完毕的时候，相应的goroutine会进入到死亡状态（Ghead）。标志着该goroutine的一次运行的完成。作为go函数的函数或方法可以有结果声明，但是返回的结果值会在它们被执行完成时被丢弃。需要用channel将go函数的结果传递给其他程序。
```code
package main
func main(){
    go println("Go!Goroutine!")
}
```
由于执行的先后顺序不确定，go语句后无其他语句，main函数所在的G可能先于go函数所在的G执行结束，意味着可能go函数所在的G未来得及执行。

使用time包中的Sleep函数干预多个G的执行顺序。
```code
package main
import (
    "time"
)
func main(){
    go println("Go!Goroutine!")
    time.Sleep(time.Millisecond)
}
```
time.Sleep函数让调用它的goroutine暂停（进入Gwaiting状态）一段时间。此种情况最好的方法时调用runtime.Gosched()函数，暂停当前的G，让其他的G有运行的机会。
```code
package main
import (
    "fmt"
    "runtime"
)
func main(){
    names := []string{"Eric", "Harry", "Robert", "Jim", "Mark"}
    for _, name := range names {
        go func (who string) {
            fmt.Printf("Hello, %s!\n ", who)
        }(name) 
    }
    runtime.Gosched()
}
```
## 主goroutine的运作
封装main函数的goroutine是Go语言运行时系统创建的第一个goroutine(主goroutine)，主Goroutine在runtime.m0上被运行。runtime.m0在运行完runtime.g0中的引导程序之后，会接着运行主goroutine。

主goroutine不仅执行main函数。它首先：设定每一个goroutine所能申请的栈空间的最大尺寸。在32位的计算机系统中此最大尺寸为250MB，在64位的计算机系统中此尺寸为1GB。若有某个goroutine的栈空间尺寸大于这个限制，运行时系统就会发出一个栈溢出（stack overflow）的运行时恐慌。随即，Go程序的运行也会被终止。

设定好goroutine的最大栈尺寸后，主goroutine会在当前M的g0上执行系统监测任务。系统监测任务的作用是调度器查缺补漏。

此后，主goroutine会进行一系列的初始化工作，涉及的工作内容大致有。  
* 检查当前M是否为runtime.m0。若不是，说明之前的程序出现了某种问题，主goroutine会立即抛出异常，意味着Go程序的启动失败。
* 创建一个特殊的defer语句，用于在主goroutine退出时做必要的善后处理。因为主goroutine可能非正常的结束。
* 启用专用于在后台清扫内存垃圾的goroutine，并设置GC可用的标识。
* 执行main包中的init函数。

在上述初始化工作完成之后，主goroutine就会去执行main函数。在执行main函数之后，会检查主goroutine是否引发了运行时恐慌，并进行必要的处理。最后，主goroutine会结束自己以及当前进程的运行。

main函数执行期间，运行时系统会根据Go程序中的go语句，复用或新建goroutine来封装go函数。这些goroutine都会放入相应P的可运行G队列中，然后等待调度器的调度。

## runtime包与goroutine
Go的标准库代码包runtime中的程序实体，提供了各种可以使用户程序与Go运行时系统交互的功能。
### 1.runtime.GOMAXPROCS函数
用户程序在运行期间，设置常规运行时系统中的P的最大数量。调用会引起“Stop the world”，应在应用程序尽量早的调用，更好的方式是设置环境变量GOMAXPROCS。P的最大数量范围在1～256。

### 2.runtime.Goexit函数
立即使当前goroutine的运行终止，而其他goroutine并不会受此影响。runtime.Goexit函数在终止当前goroutine之前，会先执行该goroutine中所有还未执行的defer语句。

该函数将被终止的goroutine置于Gdead状态，并将其放入本地P的自由G列表，然后触发调度器的一轮调度流程。

>不应在主goroutine中调用此函数，否则引发运行时恐慌。

### 3.runtime.Gosched函数
该函数暂停当前goroutine的运行，并将其置为Grunnable状态，放入调度器的可运行G队列。经过调度器的调度，该goroutine马上会再次运行。
### 4.runtime.RunGoroutine函数
返回当前运行时系统中处于非Gdead状态的用户G的数量。这些goroutine被视为“活跃的”或者“可调度的”。返回值总会大于一（废话）。
### 5.runtime.LockOSThread函数和runtime.UnLockOSThread函数
前者的调用使当前goroutine与当前M锁定在一起，后者的调用则会解除这样的锁定。多次调用前者不会造成问题但只有最后一次生效。没有调用前者时调用后者也不会产生任何副作用。
### 6.runtime/debug.SetMaxStack函数
约束单个goroutine所能申请栈空间的最大尺寸。主goroutine会对此值进行默认设置。

函数接收一个int类型的参数，参数为欲设定的栈空间的最大字节数。执行完毕后会把之前的设定值作为结果返回。

若运行时系统在为某个goroutine增加栈空间的时候，若其实际尺寸超过设定值，就会发起一个运行时恐慌并终止程序的运行。

此函数不会像runtime.GOMAXPROCS函数对传入的参数值进行检查和纠正。

### 7.runtime/debug.SetMaxThreads函数
对Go运行时系统所时用的内核线程的数量（也为M的数量，其与内核线程一一对应）进行设置。引导程序中，该数量被设置为10000。

接收一个int类型的值，返回一个int类型的值。前者代表欲设定的新值，后者代表之前的旧值。若设定的数量小与当前正在使用的M的数量，则会引发一个运行时恐慌。函数调用后，新建M会检查当前所持M的数量，若大于M的数量的设定，运行时系统引发一个运行时恐慌。

### 8.与垃圾回收有关的一些函数
runtime/debug.SetGCPercent、runtime.GC和runtime/debug.FreeOSMemory。前者用于设定触发GC的条件，后两者用于手动触发GC。在后两个函数的执行期间，调度是停止的（阻塞）。runtime/debug.FreeOSMemory函数比runtime.GC多做一件事，在GC之后清扫一次堆内存。
