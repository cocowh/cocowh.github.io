---
title: Golang笔记-channel
tags: [chan,通道]
comments: true
categories: [Golang]
date: 2018-05-02 17:03:49
---
channel——提倡“以通信作为手段来共享内存”最直接和最重要的体现。
Go使用通道类型值在不同的goroutine之间传递值。channel类似一个类型安全的通用型管道。

channel提供了一种机制，既可以同步两个并发执行的函数，又可以让这两个函数通过相互传递特定类型的值来通信。

## 基本概念
channel既值通道类型，指代可以传递某种类型的值的通道。通道即某一个通道类型的值，是该类型的一个实例。
### 1.类型表示法
属于引用类型。泛化的通道类型的声明：
>`chan T`

声明别名类型：
>`chan IntChan chan int`

声明一个chan int类型的变量：
>`var intChan chan int`

通道类型是双向的，既可以向此类通道发送元素值，也可以从那里接收元素值。使用`<-`接收操作符声明单向的通道类型，下面会i只能用于发送值的通道类型的泛化表示：
>`chan <- T`    //发送通道类型

声明只能从其中接收元素值的通道类型：
>`<-chan T`     //接收通道类型

### 2.值表示法
通道类型的变量在被初始化前，值为nil。通道类型的变量是用来传递值的而不是存储值的。通道类型并没有对应的值表示法。其值具有即时性，无法准确用字面量来表达。

### 3.操作的特性
通道是在多个goroutine之间传递数据和同步的重要手段，对通道操作的本身也是同步的。在同一时刻，仅有一个goroutine能向一个通道发送元素值，同时也仅有一个goroutine能从它那里接收元素值。通道中，各个元素值都是严格按照发送到此的先后顺序排列的，最早发送至通道的元素值会最先被接收。通道相当于一个FIFO的消息队列。通道中的元素具有原子性，是不可被分割的。通道中的每一个元素值都只可能被某一个goroutine接收，已被接受的值会立刻从通道中删除。

### 4.初始化通道
引用类型的值都需要内建函数make来初始化。
>`make(chan int, 10)`

初始化一个在同一时刻最多可以缓冲10个元素值且元素类型为int的通道类型。
>`make(chan int)`

一个通道值的缓冲容量总是固定不变的，省略参数二意味着初始化的这个通道永远无法缓冲任何元素值。发送给它的元素值应该被立刻取走，否则发送方的goroutine就会暂停（阻塞），直到有接收方接收这个元素值。

将第二个参数值大于0的通道称为缓冲通道，未给定第二个参数值或给定值为0的通道称为非缓冲通道。

### 5.接收元素值
```code
strChan := make(chan string, 3) //声明一个双向通道类型strChan

elsm, ok := <- strChan
elem := <- strChan //从该通道中接收元素值，无值时goroutine被阻塞直到有值时被唤醒
```
从未初始化的通道中接收值会造成当前goroutine永久阻塞。

### 6.Happens before
对于一个缓冲通道有：  
* 发送操作会使通道复制被发送的元素。若因通道的缓冲空间已满而无法立即复制，则阻塞正在进行发送操作的goroutine。复制的目的地址有两种。当通道已空且有接收方在等待元素值时，它会是最早等待的那个接收方持有的内存地址，否则会是通道持有的缓冲中的内存地址。
* 接收操作会使通道给出一个已发送它的元素值的副本，若因通道的缓冲空间已空而无法立即给出，则阻塞正在进行接收操作的goroutine。一般情况下，接收方会从通道持有的缓冲中得到元素值。
* 对于同一个元素值来说，把它发送给某个通道的操作，一定会在从该通道中接收它的操作完成之前完成。在通道完全复制一个元素值之前，任何goroutine都不可能从它那里接收到这个元素值的副本。

### 7.发送元素值
对接收操作符<-两边的表达式的求值会先于发送操作执行，在对两个表达式求值完成之前，发送操作被阻塞。
```code
package main

import (
	"fmt"
	"time"
)

var strChan = make(chan string, 3)

func main() {
	syncChan1 := make(chan struct{}, 1)
	syncChan2 := make(chan struct{}, 2)
	go func() { // 用于演示接收操作。
		<-syncChan1
		fmt.Println("Received a sync signal and wait a second... [receiver]")
		time.Sleep(time.Second)
		for {
			if elem, ok := <-strChan; ok {
				fmt.Println("Received:", elem, "[receiver]")
			} else {
				break
			}
		}
		fmt.Println("Stopped. [receiver]")
		syncChan2 <- struct{}{}
	}()
	go func() { // 用于演示发送操作。
		for _, elem := range []string{"a", "b", "c", "d"} {
			strChan <- elem
			fmt.Println("Sent:", elem, "[sender]")
			if elem == "c" {
				syncChan1 <- struct{}{}
				fmt.Println("Sent a sync signal. [sender]")
			}
		}
		fmt.Println("Wait 2 seconds... [sender]")
		time.Sleep(time.Second * 2)
		close(strChan)
		syncChan2 <- struct{}{}
	}()
	<-syncChan2
	<-syncChan2
}
```
运行结果:
```result
Sent: a [sender]
Sent: b [sender]
Sent: c [sender]
Sent a sync signal. [sender]
Received a sync signal and wait a second... [receiver]
Received: a [receiver]
Received: b [receiver]
Received: c [receiver]
Received: d [receiver]
Sent: d [sender]
Wait 2 seconds... [sender]
Stopped. [receiver]
```
由于运行时系统的调度，每次运行的输出语句顺序可能不同。

syncChan通道是为了不让主goroutine过早地结束运行。一旦goroutine过早的结束运行，Go程序的运行也就结束了。main函数最后试图从syncChan接收值两次，接收完成之前主goroutine阻塞于此。两个goroutine都像syncChan发送值后，主goroutine恢复运行，随后结束运行。

syncChan1和syncChan2的元素类型都是struct{}。代表的是不包含任何字段的结构体类型，也称空结构体类型。空结构体的变量不占内存空间，并且所有该类型的变量都拥有相同的内存地址。建议用于传递“信号”的通道都用struct{}作为元素类型，除非需要传递更多的信息。

向一个值为nil的通道类型的变量发送元素值时，当前goroutine也会被永久的阻塞。若试图从一个已关闭的通道中发送元素值，会立即引发一个运行时恐慌，即使发送通道正在因通道已满而被阻塞。为避免此类流程中段可以在select代码块中执行发送操作。

若由多个goroutine向同一个已满的通道发送元素值而被阻塞，那么当该通道中有多余空间的时候，最早被阻塞的goroutine会最先被唤醒。对接收操作也是如此。运行时系统每次只会唤醒一个goroutine。

发送方向通道发送的值会被复制，接收方接收的总是该值的副本，而不是该值本身。通道的缓冲队列属于环形队列。当接收方从通道接收到一个类型的值时，对该值的修改不会影响发送方持有的源值。

### 8.关闭通道
通过调用内建函数close关闭通道。
```code
close(strChan)
```
>`不应该在接收端关闭通道`，因无法判断发送端是否还会向该通道发送元素值。在发送端调用close以关闭通道不会对接收端接收该通道中已有的元素值产生任何影响。

调用close函数的作用是告诉运行时系统不应该再允许任何针对被关闭的通道的发送操作，该通道即将被关闭。调用close函数只是让相应的通道进入关闭状态而不是立即阻止对它的一切操作。
>对同一个通道仅允许关闭一次，对通道的重复关闭会引起运行时恐慌。调用close函数时的参数值是一个值为nil的通道类型的变量也会引发运行时恐慌。

### 长度与容量
内建函数len和cap可作用于通道之上，分别获取当前通道中的元素值数量（长度）和通道可容纳元素值的最大数量（容量）。通道的容量再初始化时已经确定，并且之后不能改变，通道的长度会随实际情况改变。

容量为0的通道为非缓冲通道，否则为缓冲通道。

## 单向channel
单向通道可分为发送通道和接收通道，无论哪一种都不应该出现在变量的声明中。单向通道应由双向通道变换而来，可以用这种变换来约束程序对通道的使用方式。例如os/isgnal.Notify函数的声明：
>`func Notify(c chan <- os.Signal, sig ...os.Signal)`

第一个参数的类型是发送通道类型，调用时应该传入一个双向通道，自动把它转换为单向通道。Notify函数中的代码只能向通道c发送元素值，而不能从其中接收元素值。从该通道c中接收元素值会造成编译错误。函数之外不受此约束。但Notify函数对c进行发送操作，函数外的代码应该对其进行接收操作，函数外的发送操作会造成干扰。
```code
package main

import (
	"fmt"
	"time"
)

var strChan = make(chan string, 3)

func main() {
	syncChan1 := make(chan struct{}, 1)
	syncChan2 := make(chan struct{}, 2)
	go receive(strChan, syncChan1, syncChan2) // 用于演示接收操作。
	go send(strChan, syncChan1, syncChan2)    // 用于演示发送操作。
	<-syncChan2
	<-syncChan2
}

func receive(strChan <-chan string,
	syncChan1 <-chan struct{},
	syncChan2 chan<- struct{}) {
	<-syncChan1
	fmt.Println("Received a sync signal and wait a second... [receiver]")
	time.Sleep(time.Second)
	for {
		if elem, ok := <-strChan; ok {
			fmt.Println("Received:", elem, "[receiver]")
		} else {
			break
		}
	}
	fmt.Println("Stopped. [receiver]")
	syncChan2 <- struct{}{}
}

func send(strChan chan<- string,
	syncChan1 chan<- struct{},
	syncChan2 chan<- struct{}) {
	for _, elem := range []string{"a", "b", "c", "d"} {
		strChan <- elem
		fmt.Println("Sent:", elem, "[sender]")
		if elem == "c" {
			syncChan1 <- struct{}{}
			fmt.Println("Sent a sync signal. [sender]")
		}
	}
	fmt.Println("Wait 2 seconds... [sender]")
	time.Sleep(time.Second * 2)
	close(strChan)
	syncChan2 <- struct{}{}
}
```
使用单向通道改进发送元素值demo，此代码对接收和发送进行了参数约束，规定了参数中通道的方向。

>通道允许的数据传递方向是其类型的一部分，对于两个通道类型而言，数据传递方向的不同，意味着它们类型的不同。利用函数声明将双向通道转换为单向通道的做法，只是一个语法糖，不能利用函数声明将一个单向通道转换成双向通道，这样做会得到一个编译错误。

## for语句与channel
使用for语句的range子句持续地从一个通道接收元素值。
```code
var ch chan int
//todo
for e := range ch {
	fmt.Printf("Element:%v\n", e)
}
```
range子句的迭代目标不能是一个发送通道，同从发送通道中接收元素值会造成一个编译错误。

从还未初始化的通道中接收元素值会导致当前goroutine的永久阻塞，使用for语句会阻塞在range子句处。

## select语句
select语句是一种仅能用于通道发送和接收操作的专用语句。一条select语句执行时，会选择其中的某一个分支并执行。类似switch语句但选择分支的方法完全不同。
### 组成和编写方法
每个分支以case开始，跟在每个case后面的只能是针对某个通道的发送语句或接收语句，在select关键字后没有像switch语句那样的表达式，直接跟花括号。
```code
var intChan = make(chan int, 10)
var strChan = make(chan string, 10)
select {
	case e1 := <-intChan:
		fmt.Printf("The first case was selected.e1=%v.\n", e1)
	case e2 := <-strChan:
		fmt.Printf("The second case was selected.e2=%v.\n", e2)
	default:
		fmt.Println("Default!")
}
```
select语句中所有普通case都不满足选择条件，default case会被选中。
### 分支选择规则
在开始执行select语句时，所有根在case关键字后的发送语句或接收语句中的通道表达式和元素表达式都会先求值（求之顺序从左到右、自上而下），无论它们所在的case是否有可能被选择。
```code
package main

import "fmt"

var intChan1 chan int
var intChan2 chan int
var channels = []chan int{intChan1, intChan2}

var numbers = []int{1, 2, 3, 4, 5}

func main() {
	select {
	case getChan(0) <- getNumber(0):
		fmt.Println("The 1th case is selected.")
	case getChan(1) <- getNumber(1):
		fmt.Println("The 2nd case is selected.")
	default:
		fmt.Println("Default!")
	}
}

func getNumber(i int) int {
	fmt.Printf("numbers[%d]\n", i)
	return numbers[i]
}

func getChan(i int) chan int {
	fmt.Printf("channels[%d]\n", i)
	return channels[i]
}
```
运行结果：
```code
channels[0]
numbers[0]
channels[1]
numbers[1]
Default!
```
因为intChan1和intChan2未被初始化，向它们发送的元素值会永久阻塞，即两个case语句被阻塞，select语句执行default case，才会有最后一行输出。

执行select语句时，运行时系统会自上而下地判断每个case中的发送或接收操作是否可以立即执行（当前goroutine不会因此操作而被阻塞	）。需要依据通道的具体特性（缓冲或非缓冲）以及那一刻的具体情况来进行。只要发现有一个case上的判断是肯定的该case就会被选中。

>当有一个case被选中时，运行时系统就会执行该case及其包含的语句，而其他case会被忽略。若同时有多个case满足条件，那么运行时系统会通过一个伪随机数算法选中一个case。若所有case都不满足选择条件并且没有default case，那么当前goroutine就会一直被阻塞于此，直到至少有一个case中的发送或接收操作可以立即进行为止。

一条select语句只能包含一个default case，可以放置在该语句的任何位置上。

### 与for语句的连用
实际场景中常常把select语句放到一个单独的goroutine中执行，即使select语句被阻塞，也不会造成死锁。常与for语句连用以便持续操作其中的通道。
```code
package main

import "fmt"

func main() {
	intChan := make(chan int, 10)
	for i := 0; i < 10; i++ {
		intChan <- i
	}
	close(intChan)
	syncChan := make(chan struct{}, 1)
	go func() {
	Loop:
		for {
			select {
			case e, ok := <-intChan:
				if !ok {
					fmt.Println("End.")
					break Loop
				}
				fmt.Printf("Received: %v\n", e)
			}
		}
		syncChan <- struct{}{}
	}()
	<-syncChan
}
```
运行结果：
```code
Received: 0
Received: 1
Received: 2
Received: 3
Received: 4
Received: 5
Received: 6
Received: 7
Received: 8
Received: 9
End.
```
## 非缓冲的channel
初始化通道时将其容量设置为0或直接忽略对容量的设置，会使该通道成为一个非缓冲通道。不同于`以异步的方式传递元素值的缓冲通道`，非缓冲通道只能`同步地传递元素值`。
### happens	before
特别之处：  
* 向此类通道发送元素值的操作会被阻塞，直到至少有一个针对该通道的接收操作进行为止。接收操作先得到元素值的副本，在唤醒发送方的goroutine之后返回。即此时接收操作会在对应的发送操作完成之前完成。
* 从此类通道接收元素值的操作会被阻塞，直到至少有一个针对该通道的发送操作进行为止。发送操作直接把元素值复制给接收方，然后在唤醒接收方所在的goroutine之后返回。即此时的发送操作会在对应的接收操作完成之前完成。

只有在针对非缓冲通道的发送方和接收方“握手”之后，元素值的传递才会进行，然后双方的操作才能进行。如果发送方或/和接收方有多个，需要排队握手。

### 同步的特征
由于非缓冲通道会以同步的方式传递元素值，在其上收发元素值的速度总是与慢的一方持平。可以通过调用内建函数cap判断一个通道是否带有缓冲。若想异步地执行发送操作，但通道确实非缓冲的，需另行异步化，例如：启用额外的goroutine执行此操作。在执行接收操作时通常无需关心通道是否带有缓冲，可以依据通道的容量实施不同的接收策略。

## time包与channel
标准库代码包time中的一些API是用通道辅助实现的，这些API可以帮助我们对通道的收发操作进行更有效的控制。
### 定时器
time包中的Timer结构体类型会被作为定时器使用，可用time.NewTimer函数和time.AfterFunc函数构建time.Timer类型的值。

传递给time.NewTimer一个time.Duration类型的值，表示从定时器被初始化的那一刻起，距到期时间需要多少纳秒（ns）。
```example
timer := time.NewTimer(3*time.Hour + 36*time.Minute)
```
此timer是*time.Timer类型而非time.Timer类型。前者的方法集合包含了两个方法：Reset和Stop。Reset方法用于重置定时器（定时器可复用），返回一个bool类型的值。Stop方法用于停止定时器，返回bool类型值作为结果。为false说明该定时器已经过期或已经被停止，否则说明该定时器由于方法调用而被停止。Reset方法的返回值与当此重置操作是否成功无关，无论结果如何，一旦Reset方法调用完成，该定时器就已被重置。

在time.Timer类型中，对外通知定时器到期的途径是通道，由字段C代表。C代表一个chan time.Timer类型的带缓冲的接收通道，在值赋给C时由双向通道自动转换为接收通道。定时器内部仍然持有该通道，且并未被唤醒，可以向其发送元素值。一旦触及到期时间，定时器就会向它的通知通道发送一个元素值，代表该定时器的绝对到期时间。传入的time.Duration类型值是该定时器的相对到期时间。

可以通过`time.NewTimer(time.Duration).C`获取`绝对到期时间`，可用`time.After(time)`替换之，与前者等价。time.After函数会新建一个定时器，并把它的字段C作为结果返回，为超时的设定提供了一种快捷方式。

从一个被调用Stop方法停止的未到期定时器的C字段中接收元素不会有任何结果且会使当前goroutine永久阻塞。在重置定时器前不要再次对它的C字段执行接收操作。`若定时器到期了，未及时从其C字段接收元素值，该字段就一直缓冲着那个元素值，即使在该定时器重置之后也是如此，由于C（通知通道的容量）为1，会影响重置后的定时器再次发送到期通知。虽不造成阻塞，但后续通知会被直接丢掉。若想复用定时器，应该确保旧的通知已被接收。`

传入的代表相对时间的值应该为一个整数，否则定时器在被初始化或重置之时就会立即到期。

`tme.AfterFunc`函数是另一种新建定时器的方法，接收两个参数，第一个参数代表相对到期时间,第二个参数指定到期时间需要执行的函数。同样返回新建的定时器，在定时器到期时，并不会向它的通知通道发送元素值，取而代之的是新启用一个goroutine执行调用方传入的函数。无论它是否被重置以及被重置多少次都会是这样。

### 断续器
time包的结构体类型time.Ticker表示了断续器的静态结构。包含的字段与time.Timer一致，行为不同。定时器在重置之前只会到期一次，断续器则会在到期后立即进入下一个周期并等待再次到期，周而复始直到停止。

断续器传达到期通知的默认途径也是字段C，每隔一个相对到期时间，断续器就会向此通道发送一个代表了当次的绝对到期时间的元素值。字段C的容量仍然是1。若断续器在向其通知通道发送新的元素值的时候发现旧值还未被接收，就会取消当此的发送操作。与定时器一致。
```example
var ticker  *time.Ticker = time.NewTicker(time.Second)
```
*time.Ticker类型的方法集合中只有一个方法stop，功能是停止断续器。与定时器的stop方法功能相同。一旦断续器被停止，就不会再向其通知通道发送任何元素值了，若此时字段C中已经有了一个元素值，那么该元素值就会一直在那里，直至被接收。
```code
package main

import (
	"fmt"
	"time"
)

func main() {
	intChan := make(chan int, 1)
	ticker := time.NewTicker(time.Second)
	go func() {
		for _ = range ticker.C {
			select {
			case intChan <- 1:
			case intChan <- 2:
			case intChan <- 3:
			}
		}
		fmt.Println("End. [sender]")
	}()
	var sum int
	for e := range intChan {
		fmt.Printf("Received: %v\n", e)
		sum += e
		if sum > 10 {
			fmt.Printf("Got: %v\n", sum)
			break
		}
	}
	fmt.Println("End. [receiver]")
}
```
某次运行结果：
```code
Received: 3
Received: 3
Received: 1
Received: 3
Received: 3
Got: 13
End. [receiver]
```
当累计接收的值大于10时，停止接收通道，主goroutine运行后面语句打印`End. [receiver]`然后结束主goroutine，主goroutine启动的运行匿名函数的goroutine会因主goroutine的结束而结束，不会打印出`End. [sender]`。