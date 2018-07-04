---
title: Golang笔记-测试
tags: [Golang,测试]
comments: true
categories: [Golang]
date: 2018-04-21 18:37:28
---
## 程序测试
可使用go test命令或者标准库提供的testing代码包。
### 功能测试
测试源码文件应该与被测试源码文件处于同一代码包内。testing中的API和go test命令协同使用，testing提供自动化测试支持，自动执行目标代码包中的任何测试函数。
#### 功能测试函数
功能测试程序以函数为单位，被用于测试程序实体功能的函数的名称和签名形如:     
`func TestXxx (t *testing.T)`
#### 常规记录
参数t上的Log和Logf方法一般用于记录一些常规信息，以展示测试程序的运行过程以及被测试程序的实时状态。  
>t.Logf方法与fmt.Printf函数的使用方法类似。  
t.Log方法于fmt.Println函数的使用方法类似。

```code
t.Log(Test tcp listener & sender(serverAddr= ","127.0.0.1:8000",")...")
t.Log(Test tcp listener & sender(serverAddr= %s","127.0.0.1:8000")
```
#### 错误记录
Error,Errorf方法，当测试的程序实体的状态不正确的时候，及时对当前的错误状态进行记录。
```code
actLen := Len(s)
if acrLen != expLen {
    t.Errorf("Error:The length of slice should be %d but %d.\n", expLen, actLen)
}
```
>t.Error方法相当于先后对t.Log和t.Fail方法进行调用。  
t.Errof相当于先后t.Logf和t.Fail方法进行调用。
#### 致命错误记录
Fatal和Fatalf方法用于记录致命状体错误，即错误无法进行的错误。
```code
if listener == nil {
    t.Fatalf("Listener startup failing!(addr = %s)!n\", severAddr)
}
```
>t.Fatal相当于先后调用t.Log和t.FailNow。  
t.Fatalf相当于先后调用t.Logf和t.FailNow方法。
#### 失败标记
t.FailNow与t.Fail的不同:前者被调用时会立即终止当前测试函数的执行，使当前测试运行的程序转去执行其他的测试函数。
>只能在运行测试函数的Coroutine中调用t.FailNow方法，不能在测试代码创建的Goroutine中调用，但不会报错，因不产生任何结果。
#### 失败判断
调用t.Failed方法，返回bool结果，代表当前测试函数中的测试是否已被标记为失败。
#### 忽略测试
t.SkipNow:当前测试函数为已经被忽略的并且立即终止该函数的执行，测试运行程序转去执行其他测试函数。同t.FailNow，只能在运行测试函数的Goroutine中被调用。

>t,Skip方法相当于先后对t.Log和t.SkipNow进行调用。  
t.Skipf方法相当于先后对t.Logf和t.SkipNow进行调用。

t.Skipped方结果告知当前测试是否已被忽略。
#### 并行运行
t.Parallel:标记当前测试函数为可并行运行的，使测试运行程序可以并发地执行它以及其他可并行运行的测试函数。
#### 功能测试的运行
go test命令。  

`go test 代码包 代码包`:运行代码包中的测试。  

`go test 测试源码文件 被测试源码文件`:部分测试，仅运行测试源码文件的测试。  

`go test -run=Prime 代码包`:-run标记值为正则表达式，名称与正则表达时匹配的功能测试函数才会在当次的测试运行过程中被执行。

默认通过方法t.Log和t.Logf记录测试不会显示，使用标记`-v(冗长模式)`在测试运行结束后打印出所有在测试运行过程中被记录的日志。 
`go test -v 代码包 代码包`
#### 测试运行时间
`go  test -timeout`:在达到其值所代表的时间上限时测试还未结束引发一个运行时恐慌。
```code
go test -timeout 100ms 代码包
```
`go test -short`:让测试尽快结束。  
代码包testing中的Short函数表明是否在执行`go test`命令的时候加入了`-short`标记，返回bool值。
```code
if testing.Short() {
    multiSend(severAddr, "SenderT", 1, (2 * time.Second), showLog)
} else {
    multiSend(severAddr, "SenderT1", 1, (2 * time.Second), showLog)
    multiSend(severAddr, "SenderT2", 1, (2 * time.Second), showLog)
}
```
#### 测试的并发执行
`go test -parallel`:设置允许并发执行的功能测试函数的最大数量。在多核CPU或者多CPU的计算机上，使用并发执行的方式执行测试。  

前提：功能测试函数的开始处加入`t.Parallel()`。调用`t.Parallel`方法时，执行功能测试函数的测试运行程序会阻塞，等待其他同样满足并发执行条件的测试函数被清点且阻塞后，命令根据`-parallel`标记的值全部或者部分地并发执行这些功能测试函数中的在语句`t.Parallel()`之后的那些代码。

`-parallel`的默认值是通过标准库代码包runtime的函数GOMAXPROCS设置的值。即使给予`-parallel`标记的值，真正能够并发执行功能测试函数的数量也不会比默认值多。通常不需要在命令中加入`-parallel`标记。

### 基准测试
Benchmark Test，通过一些科学手段实现对一类测试对象的某项性能指标进行可测量、可重复和可比对的测试。即性能测试。
#### 编写基准测试函数
```code
func BenchmarkXxxx(b *testing.B)
```
有Log*、Error*、Fatal*、Fail*、Skip* 系列方法。 同*testing.T类型的同名方法相同。
#### 计时器
`b.StartTimer()`:开始对当前的测试函数的执行进行计时。总会在开始执行基准函数的时候被自动的调用，此函数用于计时器被停止后重新启动。  

`b.StopTimer()`:使当前函数的计时器停止。

`b.ResetTimer()`:重置当前基准测试函数，即将函数的执行时间重值为0。
```code
package **
import (
    "testing"
    "time"
)

func BenchMark(b *testing.B) {
    customTimerTag := false
    if customTimerTag {
        b.StopTimer()
    }
    time.Sleep(time.Second)
    if customTimerTag {
        b.StartTimer()
    }
}
```
>`[root@localhost bmt]# go test -bench="." -v`

```code
Benchmark-2   	       1	1000200756 ns/op
PASS
ok  	testing/bmt	1.009s
```
>testing包中限制：在基准测试函数单次执行时间超过指定值（默认1s，可由`-benchtime`标记自定义）的情况下，只执行该基准测试函数一次，即在不超过此执行时间上限的情况下尽可能多地执行一个基准测试函数。

#### 内存分配统计
`b.ReportAllocs()`:判断在启动当前测试的`go test`命令的后面是否有`-benchmark`标记，返回bool值。  

`b.SetBytes()`:接受一个int64类型的值，用于记录在单次操作中被处理的字节的数量。帮助统计被测试的程序实体的实际性能。
```code
func BenchMark(b *testing.B) {
    customTimerTag := false
    if customTimerTag {
        b.StopTimer()
    }
    b.SetBytes(12345678)
    time.Sleep(time.Second)
    if customTimerTag {
        b.StartTimer()
    }
}
```
>`[root@localhost bmt]# go test -bench="." -v`

```code
Benchmark-2   	       1	1000449919 ns/op	  12.34 MB/s
PASS
ok  	testing/bmt	1.047s
```
`12.34 MB/s`:每秒被处理的字节的数量（MB为单位）。等于测试运行程序在执行（可能是多次）Benchmark函数的过程中每秒调用b.SetBytes方法的次数乘以传入的整数值。
#### 基准测试的运行
go test命令运行基准测试的标记：

标记名称 | 标记描述 
:-: | :- 
`-bench regexp` | 默认情况下不会运行任何基准测试，使用该标记以执行匹配“regexp”处的正则表达式所代表的基准测试函数。若需要运行所有的基准测试函数，可以写为:`-bench .`或`-bench=.`。 
`-benchmem` | 在输出内容中包含基准测试的内存分配统计信息。 
`-benchtime t` | 间接地控制单个基准测试函数的操作次数。`t`指执行单个测试函数的累计耗时上限，默认`1s`。

```code
[root@localhost src]# go test -bench=Prime cnet/ctcp
BenchmarkPrimeFuncs-2   	       1	3006791258 ns/op
--- BENCH: BenchmarkPrimeFuncs-2
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=2, NUM_CPU=2, NUM_GOROUTINE=6]
PASS
ok  	cnet/ctcp	5.023s
```
>结构体类型testing.B的字段N可以用于设置对基准测试函数中的某一个代码块重复执行的次数：

```code
for i := 0; i < b.N; i++ {
    //todo
}
```
>`[root@localhost src]# go test -bench=Prime -benchtime 1s -v cnet/ctcp`

```code
=== RUN   TestPrimeFuncs
--- PASS: TestPrimeFuncs (2.00s)
	tcp_test.go:27: Test tcp listener & sender (serverAddr=127.0.0.1:8080)... [GOMAXPROCS=2, NUM_CPU=2, NUM_GOROUTINE=4]
BenchmarkPrimeFuncs-2   	       1	3003077128 ns/op
--- BENCH: BenchmarkPrimeFuncs-2
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=2, NUM_CPU=2, NUM_GOROUTINE=6]
PASS
ok  	cnet/ctcp	5.020s
```
>`[root@localhost src]# go test -bench=Prime -benchmem  cnet/ctcp`

```code
BenchmarkPrimeFuncs-2   	       1	3002297558 ns/op	   22184 B/op	     108 allocs/op
--- BENCH: BenchmarkPrimeFuncs-2
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=2, NUM_CPU=2, NUM_GOROUTINE=3]
PASS
ok  	cnet/ctcp	5.048s
```
 `22184 B/op`:每次操作分配的字节的平均数为22184个。  
 `108 allocs/op`:没次操作分配内存的次数为108次。

 `-cpu`标记:自定义测试运行次数并在测试运行期间多次改变Go语言最大并发处理数。  
* 设置Go最大并发处理数，即调用runtime.GOMAXPROCS函数并把对应的整数作为参数传入。
* 运行目标代码包内的所有功能测试。

>测试运行程序对`-cpu`标记的处理方式与`-parallel`标记正好相反。后者默认使用最大并发处理数，前者直接设置它。前者不会影响后者的默认值。

>`[root@localhost src]# go test -bench=Prime -cpu=1,2,4,8,12,16,20 cnet/ctcp`

```code
BenchmarkPrimeFuncs       	       1	3007500941 ns/op
--- BENCH: BenchmarkPrimeFuncs
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=20, NUM_CPU=2, NUM_GOROUTINE=4]
BenchmarkPrimeFuncs-2     	   10000	    137119 ns/op
--- BENCH: BenchmarkPrimeFuncs-2
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=2, NUM_CPU=2, NUM_GOROUTINE=6]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=2, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=2, NUM_CPU=2, NUM_GOROUTINE=3]
BenchmarkPrimeFuncs-4     	   10000	    183526 ns/op
--- BENCH: BenchmarkPrimeFuncs-4
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=4, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=4, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=4, NUM_CPU=2, NUM_GOROUTINE=3]
BenchmarkPrimeFuncs-8     	   10000	    157748 ns/op
--- BENCH: BenchmarkPrimeFuncs-8
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=8, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=8, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=8, NUM_CPU=2, NUM_GOROUTINE=3]
BenchmarkPrimeFuncs-12    	   10000	    154919 ns/op
--- BENCH: BenchmarkPrimeFuncs-12
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=12, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=12, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=12, NUM_CPU=2, NUM_GOROUTINE=3]
BenchmarkPrimeFuncs-16    	   10000	    152336 ns/op
--- BENCH: BenchmarkPrimeFuncs-16
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=16, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=16, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=16, NUM_CPU=2, NUM_GOROUTINE=3]
BenchmarkPrimeFuncs-20    	   10000	    134758 ns/op
--- BENCH: BenchmarkPrimeFuncs-20
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=20, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=20, NUM_CPU=2, NUM_GOROUTINE=3]
	tcp_test.go:57: Benchmark tcp listener & sender (serverAddr=127.0.0.1:8081)... [GOMAXPROCS=20, NUM_CPU=2, NUM_GOROUTINE=3]
PASS
ok  	cnet/ctcp	26.474s
```

标记名称 | 使用示例 | 说明 
 :-: | :-: | :-
`-parallel` | `-parallel 4` | 功能：设置并发执行的功能测试函数的最大数量。  默认值：调用runtime.GOMAXPROCS(0)的结果，即最大并发处理数量。先决条件：功能测试函数开始处调用结构体testing,T类型的参数值的Parallel方法。生肖的测试：功能测试。
`-cpu` | `-cpu 1,2,4` | 功能：根据标记的值，迭代设置Go语言并发处理最大书并执行全部功能测试或全部基准测试。默认值：“”，即空字符串。先决条件：无。生效的测试：功能测试和基准测试。

>这两个标记的作用域都是代码包，只能用于控制某一个代码包内的测试的流程。多个代码包的功能测试是可并发执行，基准测试串行执行。

### 样本测试
编写不需要testing代码包的API，使用`go test`命令解析和执行。
#### 编写样本测试函数
名称以`Example`开始，函数体最后可有若干个注释行，用于比较该测试函数被执行期间，标准输出上出现的内容是否与预期相符。

注释被正确解析需满足:  
* 必须出现在函数体的末尾，与结束符`}`之间没有代码。
* 在第一行注释中紧跟在注释前导符`//`之后的永远应该是`Output:`。
* 在`Output:`右边的内容以及后续注释中的内容都分别代表了标准输出中的一行内容。

```code
package et

import (
	"fmt"
	"testing"
)

func ExampleHello() {
	for i := 0; i < 3; i++ {
		fmt.Println("Hello, Golang~")
	}

	// Output: Hello, Golang~
	// Hello, Golang~
	// Hello, Golang~
}
```
若测试函数被执行的过程中向标准输出打印的内容是`Output:`右边内容"Hello, Golang~"，则该测试函数中的测试就是通过的，否则就是失败的。
#### 样本测试的运行
>`[root@localhost et]# go test -v`

```code
=== RUN   TestOne
--- PASS: TestOne (0.00s)
	et_tsest.go:18: Hi~
=== RUN   ExampleHello
--- PASS: ExampleHello (0.00s)
PASS
ok  	testing/et	0.006s
```
修改`Output:`右边内容"Hello, Erlang"。
>`[root@localhost et]# go test -v`

```code
=== RUN   TestOne
--- PASS: TestOne (0.00s)
	et_test.go:18: Hi~
=== RUN   ExampleHello
--- FAIL: ExampleHello (0.00s)
got:
Hello, Erlang~
want:
Hello, Golang~
FAIL
exit status 1
FAIL	testing/et	0.026s
```
修改`Output:`右边内容多行，对应多行输出结果。
```code
func ExampleHello() {
	for i := 0; i < 3; i++ {
		fmt.Println("Hello, Golang~")
	}

	// Output: Hello, Golang~
	// Hello, Golang~
	// Hello, Golang~
```
>`[root@localhost et]# go test -v`

```code
=== RUN   TestOne
--- PASS: TestOne (0.00s)
	et_test.go:19: Hi~
=== RUN   ExampleHello
--- PASS: ExampleHello (0.00s)
PASS
ok  	testing/et	0.007s
```
#### 样本测试函数的命名
* 被测试对像为整个代码包，名称`Example`。
* 被测试对象为一个函数，对于函数F，名称`ExampleF`。
* 被测试对象为一个类型，对于类型T，名称`ExampleT`。
* 被测试对象为某个类型中的一个方法，对于类型T中的方法M，名称`ExampleT_M`。
* 加入后缀需用下划线“_”隔开且后缀首字母小写。针对类型T的方法M加入后缀“basic”，名称`ExampleT_M_basic`。

### 测试运行记录
在`go test`命令后跟标记的方式来启动和定制用于在测试运行时记录性能的方法。
#### 收集资源使用情况

标记名称 | 标记描述
:-: | :-
`-cpuprofile cpu.out` | 记录CPU使用情况，并写到指定的文件中直到测试退出。`cpu.out`作为指定文件的文件名可以被其他任何名称代替。
`-memprofile mem.out` |记录内存使用情况，并在测试通过后将内存使用概要写到指定文件`mem.out`中。
`-memprofilerate n` | 控制着记录内存分配操作的行为，记录i将会被写到内存使用概要文件中。`n`代表着分析器的取样间隔，单位为字节，即当有n个字节的内存被分配时，分析器就会取样一次。

>`[root@localhost et]# go test -cpuprofile cpu.out et_test.go`

```code
ok  	command-line-arguments	0.043s
```
在执行命令的当前目录中窜县一个用于运行测试的可执行文件`et.test`，可通过执行文件运行相应的测试。在目标代码包的所在目录中会出现一个名为`cpu.out`的文件，使用`go tool pprof`命令对来交互式的对这个概要文件进行查阅。
>`go tool pprof ./**.test cpu.out`

标记`-cpuprofile`相当于一个开关，决定了在测试运行期间是否对CPU使用情况进行取样操作，取样操作的时间固定，每10毫秒进行一次取样，当`-cpuprofile`标记有效时，运行测试的程序会通过标准库代码包`runtime/pprof`中的API来控制该操作的启动和停止。`pprof.StartCPUProfile`用来启动CPU使用情况记录操作，`pprof.StopCPUProfile`同来停止CPU使用情况记录操作。

`-memprofile`标记有效时，测试运行程序会在测试运行的同时记录他们对内存的使用情况，即程序运行期间堆内存的分配情况，单位是字节，值越小意味着取样间隔会更短效果越好。`-memprofilerate`标记的值会赋给runtime包中的int类型的变量MemProfileRate，默认值为512*1024，即512K字节。如果设置为0则代表停止取样。
>`go test -memprofile mem.out -memprofilerate 10 测试代码包`

会生成两个文件，一个在执行该命令所在目录下的可执行文件`测试代码包.test`，每次运行会重新生成替换原文件。另一个在目标代码包所在目录下的概要文件`mem.out`，可用`go tool pprof`命令对概要文件进行查询和分析。
>`go tool pprof ./测试代码包.test 代码包路径/mem.out`

要获得最好的取样效果，可以将`-memprofilerate`标记的值设置为1，当有一个字节被分配，分析器就会进行一次取样。消耗比较大，可将`GOGC`设置为"off"，使垃圾回收器处于不可用状态。但会让程序运行在一个没有垃圾回收器的环境中，可用的内存只会不断的减少，没有可用的内存时程序会崩溃。
#### 记录程序阻塞事件
在`go test`命令添加`-blockprofile`和`-blockprofilerate`标记来达到记录线程阻塞事件。

标记名称 | 标记描述
:-: | :-
`-blockprofile block.out` | 记录Goroutine阻塞事件，并在所有测试通过后将概要信息写到指定的文件`block.out`中。
`-blockprofilerate b` | 用于控制记录Goroutine阻塞事件的时间间隔，单位为次，默认值为1

>`go test -blockprofile block.out -blockprofilerate 100 代码包`

>`go tool pprof ./代码包.test 代码包路径/block.out`

`-blockprofilerate`的值通过标准库代码包runtime中的API函数`SetBlockProfileRate`传递给Go运行时系统。传入参数0，意味着取消记录操作，传入参数1，每一个阻塞事件都将被记录。默认值1，可省略`-blockprofilerate`标记。

### 测试覆盖率
go test命令可接受的与测试覆盖率有关的标记。

标记名称 | 使用示例 | 说明
:-: | :-: | :-
`-cover` | `-cover` | 启用测试覆盖率分析
`-covermode` | `-covermode=set` | 自动添加`-cover`标记并设置不同的覆盖率统计模式。支持的模式有：set:只记录语句是否被执行过，count:记录语句被执行的次数，atomic:记录语句被执行次数并保证在并发时也能正确计数。模式不能同时使用，默认set。
`-coverpkg` | `-coverpkg bufio,net` | 自动添加`-cover`标记并对该标记后所罗列的代码包中的程序进行测试覆盖率统计。默认情况下，测试运行程序只会被直接测试的代码包中的程序进行统计。意味着在测试中被间接使用到的其他代码包中的程序也可以被统计。代码包由导入路径指定，多个代码包之间“,”分隔。
`-coverprofile` | `-coverprofile cover.out` | 自动添加`-cover`标记并将所有已经通过测试的覆盖率的概要写入指定文件中。

>`root@localhost src]# go test -cover cnet/ctcp`

```code
ok  	cnet/ctcp	2.010s	coverage: 68.6% of statements
```

标记`-coverpkg`使我们可以获得间接被使用的代码包中的程序在测试期间的执行率。
>`[root@localhost src]# go test cnet/ctcp -coverpkg=bufio,net`

```code
ok  	cnet/ctcp	2.015s	coverage: 14.8% of statements in bufio, net
```

>`[root@localhost src]# go test cnet/ctcp -coverprofile=cover.out`

```code
ok  	cnet/ctcp	2.018s	coverage: 68.6% of statements
```
使用cover工具查看概要文件中的内容。  
* 根据指定的规则重写某一个源码文件中的代码，并输出到指定的目标上。
* 读取测试覆盖率的统计信息文件，并以指定的方式呈现。

重写：计数器。

可通过`-mode`标记将统计模式直接传递给cover工具，与`-covermode`标记的用法和含义一致。实际上go test命令将`-covermode`标记的值原封不动地作为运行cover工具时提送给它的`-mode`标记的值，`-mode`标记没有默认值。
>`go tool cover -mode=set -var="GoCover" -o dst.go src.go`

查看覆盖率概要文件：
>`go tool cover -func=cover.out`

`-func`标记可以让cover工具把概要文件中包含的每个函数的测试覆盖率概要信息打印到标准输出上。

>`go tool cover -html=cover.out`

`-html`标记用更加图形化的信息来反应统计情况，该命令会立即返回并且在标准输出上也不会出现任何内容，默认浏览器会被启动并显示cover工具根据概要文件生成的html格式的页面文件。被测试语句以绿色显示，未被测试的语句以红色显示，未参加测试覆盖率计算的语句以灰色表示。不同统计模式下生成的概要文件不同，对应的html文件也不同。

cover工具可接受的标记。

标记名称 | 使用示例 | 说明
:-: | :-: | :-
`-func` | `-func=cover.out` | 根据根要文件中的内容输出每一个被测试函数的测试覆盖率概要信息。
`-html` | `-html=cover.out` | 把概要文件中的内容换成HTML格式的文件，并使用默认浏览器查看它。
`-mode` | `-mode=count` | 被用于设置测试概要文件的统计模式。
`-o` | `-o=cover.out` | 把重写后的源代码的输出到指定文件中，如果不添加此标记，那么重写后的源代码会输出到标准输出上。
`-var` | `-var=GoCover` | 设置被添加到原先的源代码中的额外变量的名称

## 程序文档
使用`godoc`命令在本机启动一个可被用于查看本机所有工作区域中的所有代码包文档的web服务。
>`godoc -http=:9090 -index`

### 编写程序注释
行注释：
```code
//行注释
```
块注释：
```code
/*
块注释
*/
```
### 代码包的注释
对当前代码包的功能和用途进行总体性的介绍。被存放到当前代码包目录下的`doc.go`文件中。应有与包中其他源码文件相同的代码包声明语句，并在声明语句之上以块注释的方式插入代码包注释。

代码包注释总会出现在godoc命令生成的对应文档页面的首要位置上，即代码包注释会作为该代码包的文档的第一段说明出现。

### 程序实体的注释
程序实体的文档即是它的声明代码以及紧挨着在上面的行注释。

### 变量和变量的注释
将注释描述统一放在常量或变量之上。

### 文档中的示例
代码包的文档页面中包含有针对性的示例代码。是godoc命令程序自动从代码中的测试源码文件中取得的。