---
title: Golang笔记-多进程编程理论
tags: [Golang,笔记,多进程]
comments: true
categories: [Golang]
date: 2018-04-24 12:30:56
---
进程间的通讯常被称为IPC（Interprocess Communication）。Linux操作系统中分为基于通讯的IPC方法、基于信号的IPC方法以及基于同步的IPC方法。  基于通讯的IPC方法又分为以数据传送为手段的IPC方法和以共享内存为手段的IPC方法。  
* 数据传送：管道（用以被传送子节流），消息队列（用以被传送结构化的消息对象）。
* 共享内存：共享内存区，最快的一种IPC方法。
* 基于信号：信号（signal）机制。
* 基于同步：信号灯（semaphore）。

Go语言支持的IPC方法：管道、信号和Socket。
### 进程
#### 进程的定义
用于描述程序的执行过程，程序与进程形成一对相依的概念，分别描述一个程序的静态形式和动态特征。进程是操作系统进行资源分配的一个基本单位。
#### 进程的衍生
一个进程可以使用系统调用fork创建若干个新的进程，前者被称为后者的父进程，后者被称为前者的子进程。
>子进程源自它的父进程的一个副本，获得父进程的数据段、堆和栈的副本，并与父进程共享代码段。每一份副本都是独立的，子进程对属于它的副本的修改对其父进程和兄弟进程都是不可见的，反之亦然。

Linux的操作内核使用写时复制（Copy On  Write，简称COW）等技术提高进程创建的效率。被创建的子进程可以通过系统调用exec把一个新的程序加载到自己的内存中，替换掉原先在其内存中的数据段、堆、栈以及代码段，之后子进程执行被加载进来的程序。

内核启动进程作为进程树的根负责系统的初始化操作，是所有进程的祖先，其父进程是其自己。若一个进程先于它的子进程结束，那么这些子进程将会被内核启动进程“收养”，成为它的直接子进程。

#### 进程的标识
为了进程管理，内核必须对每个进程的属性和行为进行详细的记录，包括优先级、状态、虚拟地址范围以及各种访问权限等等，被记录在每个进程的进程描述符中。

进程描述符是一个复杂的数据结构，被保存在进程描述符中的进程ID（常被称为PID）是进程在操作系统中的唯一标识。进程ID为1的进程是内核启动进程。进程ID是一个非负整数且总是递增的编号，新创建的进程的ID是前一个被创建的进程的ID递增的结果。进程ID可以被重复使用。当进程ID达到最大限值，内核从头开始查找已被闲置的进程ID并使用最先找到的哪一个作为新进程的ID。进程描述符中还包含当前进程的父进程ID（常被称为PPID）。

Go中使用标准库代码包os提供的API来查看当前进程的PID和PPPID。
```code
pid := os.Getpid()
ppid := os.Getppid()
```
PID不传达与进程有关的任何信息，仅是一个用来唯一标识进程的数字。进程属性信息只被包含在内核中的、与PID对应的进程描述符中。PPID也是，可用于查找守护进程的踪迹。

进程ID对内核以外的程序非常有用，可以高效地把进程ID转换成对应进程的描述符。可以用shell命令kill终止某个进程ID所对应的进程，可以通过进程ID找到对应的进程并向它发送信号。

#### 进程的状态
可运行状态、可中断的睡眠状体、不可中断的睡眠状体、暂停状态或跟踪状态、僵尸状态和退出状态。   
* 可运行状态：（TASK_RUNNING，简称R）：处在该状态的进程将要、立即或正在CPU上运行。运行时机不确定由进程调度器来决定。
* 可中断的睡眠状态（TASK_INTERRUPTIBLE，简称S）：当进程正在等待某个事件（网络连接或信号灯）的发生时会进入此状体。会被放入对应事件的等待队列中，事件发生时，一个或多个进程就会被唤醒。
* 不可中断睡眠状态（TASK_UNINTERRUPTIBLE，简称D）:与可中断的睡眠状态的唯一区别是不可被打断，意味着处在此种状态的进程不会对任何信号作出响应。发送给处于此状态中进程的信号直到该进程转出该状态才会被传递过去。处于此状体的进程通常是由于在等待一个特殊的事件。例如等待同步的I/O操作（磁盘I/O等）的完成。
* 暂停状态或跟踪状态（TASK_STOPPED或TASK_TRACED，简称T）：向进程发送SIGSTOP信号就会使该进程处于暂停状态，除非该进程正处于不可中断的睡眠状态。向处于暂停状态的进程发动SIGCONT信号会使进程转向可运形状体。处于被跟踪状态的进程会暂停并等待跟踪它的进程对它进行操作。跟踪状态与暂停状态非常相似，但是，向处于跟踪状态的进程发送SIGCONT信号并不能使它被恢复。只有当调试进程进行了相应的系统调用或退出之后，它才能够被恢复。
* 僵尸进程（TASK_DEAD-EXIT_ZOMBIE，简称Z）：处于此状态的进程即将要结束。该进程占用的绝大多数资源也都已经被回收。还有一些信息还未被删除，例如退出码以及一些统计信息。保留这些信息考虑到该进程的父进程可能需要它们。由于此时的进程主体已经被删除而只留下了一个空壳，故此状态常被称为僵尸状态。
* 退出状态（TASK_DAED-EXIT_DEAD，简称X）：在进程退出过程中，有可能连退出码和统计信息都不需要被保留。造成原因可能是显示地让该进程的父进程忽略掉SIGCHLD信号（当一个进程消亡的时候，内核会给其父进程发送一个SIGCHLD信号以告之），也可能是该进程已经被分离（让子进程和父进程分别独立的运行）。分离后的子进程将不会再使用和执行父进程共享的代码段中的指令，而是加载并运行一个全新的程序。在此情况下，改进程在退出的时候就不会转入僵尸状态，而会直接转入退出状态。处于退出状态的进程会被结束掉，所占用的系统资源会被操作系统自动回收。

进程的状态只会在可运行状态和非可运行状态之间转换。
#### 进程的空间
一个用户进程（程序的执行实例）总会生存于用户空间中，这些进程可以做很多事，但是却不能与其所在的计算机的硬件进行交互。内核可以与硬件交互，但是却生存在内核空间中。用户进程无法直接访问内核空间。用户空间和内核空间体现了Linux操作系统对物理内存的划分。即这两个空间指的都是操作系统在内存上划分出的一个范围，共同瓜分操作系统能够支配的内存区域。

内存空间中的每一个单元都是有地址的，由指针来标识和定位。这里所指的地址并非物理内存中的真实地址，被称为虚拟地址。由虚拟地址来标识的内存区域又被称为虚拟地址空间，或虚拟内存。虚拟内存的最大容量与实际可用的物理内存的大小是无关的。内核和CPU会负责维护虚拟内存与物理内存之间的映射关系。

内核为每个用户进程分配的是虚拟内存而不是物理内存，每个用户进程被分配到的虚拟内存总是在用户空间中的，而内核空间被留给内核专用。每个用户进程都会认为分配给它的虚拟内存就是整个用户空间。一个用户进程不可能操纵另一个用户进程的虚拟内存，因为后者的虚拟内存对于前者来说是不可见的。即进程间的虚拟内存几乎是彼此独立、互不干扰的。由于它们基本被映射到了不同的物理内存之上。

内核把进程的虚拟内存划分为若干页（page）。物理内存单元的划分由CPU负责。一个物理内存单元被称为一个页框（page frame）。不同进程的大多数页都会与不同的页框相对应。

进程之间共享页框是被允许的，是作为IPC方法之一的共享内存区的基础。

#### 系统调用
内核会暴露一些接口给用户进程，使用户进程能够使用操作系统更底层的功能，是用户进程能够使用内核功能（包括操纵计算机硬件）的唯一手段。用户进程使用这些接口的行为被称为系统调用，有时“系统调用”也指内核提供了这些接口。系统调用是向内核空间发出的一个明确的请求，而普通的函数只是定义了如何获取一个给定的服务。系统调用会导致内核空间中的数据的存取和指令的执行，而普通函数只能在用户空间中进行操作。系统调用是内核的一部分。

为保证操作系统的稳定性和安全，内核依据CPU提供的、可以让进程驻留的特权级别建立了两个特权状态。即内核态和用户态。大部分时间里CPU都处于用户态，这时CPU只能对用户空间进行访问，即CPU在用户态下运行的用户进程不能与内核接触。当用户进程发出一个系统调用时，内核会把CPU从用户态切换到内核态，而后会让CPU执行对应的内核函数。CPU在内核态下由权限访问内核空间。相当于使用户进程通过系统调用使用到了内核提供的功能。当内核函数被执行完毕，内核会把CPU从内核态切换回用户态，并把执行结果返回给用户进程。

>只有当CPU被切换至内核态之后才可以执行内核空间中的函数，而在内核函数执行完毕后，CPU状态也会被及时地切换回用户态。

#### 进程的切换和调度
Linux操作系统通过CPU，可以在多个进程间进行切换（也称为进程间的上下文切换），以产生多个进程在同时运行的假象。每个进程会认为自己独占CPU。在进程切换时，需要保存当前进程的运行时状态，若要执行的另一个进程不是第一次运行则需要将该进程恢复到之前被换下时的运行时状态。进程切换主要是由内核来完成，除了进程切换之外，为了使各个生存着的进程都有被u运行的机会、让它们共享CPU，内核还需考虑把哪一个进程应该作为下一个被运行的进程、应该在哪一时刻进行切换，以及切换下的进程需要在哪一时刻再被换上，等等。解决类似问题的反感和任务被统称为进程调度。

进程切换和进程调度是程序并发执行的基础。

### 关于同步
当几个进程同时对同一个资源进行访问的时候，可能造成互相的干扰，即竟态条件。造成竟态条件的根本原因在于进程在进行某些操作的时候被中断了。虽然进程再次运行的时候其状态会恢复如初，但是外界环境很可能已经在这极短的时间内改变了。

我们把执行过程中不能被中断的操作称为原子操作（atomic operation），把只能被串行化的访问或执行的某个资源或某段代码称为临界区（critical section）。原子操作是不能被中断的，临界区对是否可以被中断没有强制的规定。只要保证一个访问者在临界区中的时候其他访问者不被允许进入。所有的系统调用都属于原子操作，执行不会被中断。

原子操作必须由一个单一的汇编指令代表，并且需要得到芯片级别的支持。原子操作能够做到绝对的并发安全，并且比其他同步机制要快很多。原子操作只适合细粒度的简单操作。Go在CPU和各个操作系统的底层支撑之上提供了对原子操作的支持。由标准库代码包`sync/atomic`中的一些函数代表。

让要求被串行执行的若干代码形成临界区的做法更通用，保证只有一个进程或线程在临界区之内的做法是——互斥（mutual exclusion，简称mutex）。实现互斥的方法必须确保排他原则（exclusion principle），并且保证不能依赖于任何计算机硬件（包括CPU）。即互斥方法必须有效且通用。

### 管道
管道（pipe）是一种半双工（单向）通讯方式。只能用于父进程与子进程以及同祖先的子进程之间的通讯。例如shell:
>`ps aux | grep go`

shell为每个命令都创建一个进程，然后把左边的命令的标准输出用管道与右边的命令的标准输入连接起来。优点简单，缺点只能单向通讯以及通讯双方关系上的严格限制。

使用标准库代码包os/exec中的API，可以执行操作系统命令并在此之上建立管道。
>`cmd := exec.Command("echo","-n","command from golang.")`

cmd同操作系统命令
>`echo -n "command from golang"`

对应。

可以使用exec.Cmd类型之上的Start方法启动一个操作系统命令。
```code
if err := cmd.Start();err != nil {
    fmt.Printf("Error: The command can not be startup:%s\n",err)
    return
}
```
使用cmd的值的StdoutPipe方法创建一个能够获取此命令输出的管道：
```code
stdout, err := cmd.StdoutPipe()
if err != nil {
    fmt.Printf("Error: Can not obtain the stdout pipe for command: %s\n",err)
    return
}
```
输出管道stdout类型是io.ReadCloser，这是接口类型并扩展了接口类型io.Reader。启动命令之后可以调用stdout的值的Read方法获取命令的输出：
```code
output := make([]byte,30)
n, err := stdout.Read(output)
if err != nil {
    fmt.Printf("Error: Can not read data from the pipe: %s\n",err)
    return
}
fmt.Printf("%s\n", output[:n])
----
var outputBuf bytes.Buffer  //标准库代码包bytes
for {
    tempOutput := make([]byte, 5)
    n, err := stdout.Read(tempOutput)
    if err != nil {
        if err == io.EOF {
            break
        } else {
            fmt.Printf("Error: Can not read data from the pipe: %s\n",err)
        }
    }
    if n > 0 {
        outputBuf.Write(tempOutput[:n])
    }
}
fmt.Printf("%s\n", outputBuf.String())
```
Read方法把读出的输出数据存入调用方法传递给它的字节切片中并返回一个int类型值和一个error类型值。命令输出小于output的值的长度，n的值代表命令实际输出的字节的数量。否则我们并没有完全读出输出管道中的数据，n的值等于output的值的长度，需要再去读取一次或者多次。若输出管道中没有可读数据，Read方法返回的第二个结果值为变量io.EOF的值，可判断是否被读完。

使用带缓冲的读取器从输出管道中读取数据。
```code
putputBuf := bufio.NewReader(stdout)
output, _, err := outputBuf.ReadLine()
if err != nil {
    fmt.Printf("Error: Can not read data from the pipe: %s\n", err)
    return
}
fmt.Printf("%s\n",string(output))
```
stdout的值是io.Reader类型，作为bufio.NewReader函数的参数，返回一个bufio.Reader类型的值。即缓冲读取器。默认缓冲读取器携带一个长度4096的缓冲区，长度代表了一次可以读取的字节的最大数量。cmd代表的命令只有一行输出，使用outputBuf的ReadLine方法读取。第二个bool类型结果代表当前行是否还未被读完，若为false可以利用for语句读取剩余的数据。

使用Go实现`ps aux | grep go`：  
```code
cmd1 := exec.Command("ps", "aux")
cmd2 := exec.Command("grep", "go")
stdout1, err := cmd1.StdoutPipe()
if err != nil {
    fmt.Printf("Error: Can not obtain the stdout pipe for command: %s", err)
    return
}
if err := cmd1.Start(); err != nil {
    fmt.Printf("Error: The command can not running: %s\n", err)
    return
}
outputBuf1 := bufio.NewReader(stdout1)
stdin2, err := cmd2.StdinPipe()
if err != nil {
    fmt.Printf("Error: Can not obtain the stdin pipe for command: %s\n", err)
    return
}
outputBuf1.WriteTo(stdin2)
var outputBuf2 bytes.Buffer
cmd2.Stdout = &outputBuf2
if err := cmd2.Start(); err != nil {
    fmt.Printf("Error: The command can not be startup: %s\n", err)
    return
}
err = stdin2.Close()
if err != nil {
    fmt.Printf("Error: Can not close the stdio pipe: %s\n", err)
    return
}
if err := cmd2.Wait(); err != nil {
    fmt.Printf("Error: Can not wait for the command: %s\n", err)
    return
}
```
通过StdinPipe方法在cmd2之上创建一个输入管道，然后把cmd1连接的输出管道中的数据全部写入到这个输入管道中。返回与该命令连接的输入管道，是io.WriteCloser接口类型类型的值，扩展了io.Writer接口类型，可被作为outputBuf1的WriteTo方法的参数。把所属值中缓冲的数据全部写入到参数值代表的写入器中。等于把第一个命令的输出内容通过管道传递给第二个命令。之后需启动cmd2并关闭与它连接的输入通道。调用cmd2的Wait方法阻塞其所属的命令直到完全运行结束为止，然后再读取outputBuf2的内容。

以上为`匿名管道`，对应的是`命名管道`，任何进程都可以通过命名管道交换数据，以文件的形式存在于文件系统中。linux中:
```code 
[joker@localhost Test]$ mkfifo -m 644 myfifo
[joker@localhost Test]$ tee dst.log < myfifo &
[1] 13315
[joker@localhost Test]$ cat src.log >myfifo
12345
[1]+  完成                  tee dst.log < myfifo
```
创建命名管道myfifo，将src.log的内容写道dst.log。命名管道是阻塞式的，只有在对这个命令管道的读操作和写操作都已经准备就绪之后数据才会开始流转。相对于匿名管道，命名管道的通讯双方可以毫不相干，仍是单向的。可以使用它建立非线性的连接实现数据的多路复用，需要考虑多个进程同时向命名管道写数据的情况下的操作原子性问题。

Go标准库代码包os中包含了可以创建独立管道的API。
>`reader, writer, err := os.Pipe()`

`reader`代表了该管道输出端的*os.File类型值。  

`writer`代表了该管道输入端的*os.File类型值。  

可以在其之上调用*os.File类型包含的所有方法。  

在Go底层使用系统函数来创建管道，并将两端封装成两的*os.File类型的值。

命名管道默认在其中一端还未就绪的时候阻塞另一端的进程。不能反过来使用reader或者writer，在reader上调用Write方法或在writer上调用Read方法获取的第二个结果值都将是一个非nil的error类型值。无论在哪一方调用Close方法都不会影响另一方的读取或写入数据的操作。

>在exec.Cmd类型值上调用StdinPipe或StdoutPipe方法后得到的输入管道或输出管道也是通过os.Pipe函数生成的。在两个方法内部对生成的管道做了附加处理。输入管道的输出端在所属命令启动后被立即关闭，输入端在所属命令运行结束后被关闭。输出管道的两端的自动关闭时机与输入管道相反。有些命令会等到输入管道被关闭之后才结束运行，需要在数据被读取之后尽早地手动关闭输入管道。

由于通过os.Pipe函数生成的管道在底由系统级别的管道支持，所以在使用时，要注意操作系统对管道的限制。例如匿名管道会在管道缓冲被写满之后使用写数据的进程阻塞，命名管道会在其中一端未就绪前阻塞另一端的进程。

当有多个输入端同时写入数据时，需要考虑原子性问题。操作系统提供的管道不提供原子操作支持。Go在标准库代码包io中提供一个被存于内存中的、有原子性操作保证的管道（内存管道）。生成方法:  
>`reader, writer := io.Pipe()`

`reader`代表该管道输出端的*PipeReader类型值。  

`writer`代表该管道输入端的*PipeWriter类型值。

\*PipeReader类型和\*PipeWriter类型分别对管道的输出端和输入端做了很好的限制。在\*PipeReader类型的值上只能使用Read方法从管道中读取数据，在\*PipeWriter类型的值上只能使用Write方法向管道写入数据，避免管道使用者对管道的反向使用。使用Close方法关闭管道的某一端之后，另一端在写入数据或者读取数据的时候会得到一个预定义的error类型值。可以通过调用CloseWithError来自定义另一端将会得到的error类型值。

于os.Pipe函数生成的管道相同的是，仍然需要并发的运行被用来在内存管道的两端进行操作的代码。在内存管道的内部通过充分使用sync代码包中提供的API从根本上保证操作的原子性。这种管道不是基于文件系统，没有作为中介的缓冲区，通过它传递的数据只会被复制一次，提高数据的传递效率。

### 信号
操作系统中的信号（Signal）是IPC中唯一一种异步的通讯方法。本质是用软件来模拟硬件的中断机制。被用于通知某个进程有某个事件发生。

每一个信号都有一个以“SIG”为前缀的名字，在操作系统内部，信号都由正整数代表，称为信号编号，Linux系统可使用`kill -l`命令查看所支持的信号。
```code
 1) SIGHUP	 2) SIGINT	 3) SIGQUIT	 4) SIGILL	 5) SIGTRAP
 6) SIGABRT	 7) SIGBUS	 8) SIGFPE	 9) SIGKILL	10) SIGUSR1
11) SIGSEGV	12) SIGUSR2	13) SIGPIPE	14) SIGALRM	15) SIGTERM
16) SIGSTKFLT	17) SIGCHLD	18) SIGCONT	19) SIGSTOP	20) SIGTSTP
21) SIGTTIN	22) SIGTTOU	23) SIGURG	24) SIGXCPU	25) SIGXFSZ
26) SIGVTALRM	27) SIGPROF	28) SIGWINCH	29) SIGIO	30) SIGPWR
31) SIGSYS	34) SIGRTMIN	35) SIGRTMIN+1	36) SIGRTMIN+2	37) SIGRTMIN+3
38) SIGRTMIN+4	39) SIGRTMIN+5	40) SIGRTMIN+6	41) SIGRTMIN+7	42) SIGRTMIN+8
43) SIGRTMIN+9	44) SIGRTMIN+10	45) SIGRTMIN+11	46) SIGRTMIN+12	47) SIGRTMIN+13
48) SIGRTMIN+14	49) SIGRTMIN+15	50) SIGRTMAX-14	51) SIGRTMAX-13	52) SIGRTMAX-12
53) SIGRTMAX-11	54) SIGRTMAX-10	55) SIGRTMAX-9	56) SIGRTMAX-8	57) SIGRTMAX-7
58) SIGRTMAX-6	59) SIGRTMAX-5	60) SIGRTMAX-4	61) SIGRTMAX-3	62) SIGRTMAX-2
63) SIGRTMAX-1	64) SIGRTMAX
```

支持62种信号（没有编号为32和33的信号），编号1-31的信号属于标准信号（不可靠信号），编号34-64的信号属于实时信号（可靠信号）。对于同一个进程，每种标准信号只会被记录并处理一次。若发送给某一进程的标准信号的种类有多个，被处理的顺序是完全不确定的。而多个实时信号都可以被记录，并且按照信号的发送顺序被处理。

信号的来源有键盘输入、硬件故障、系统函数调用和软件中的非法运算。进程响应信号的方式有3种：忽略、捕捉和执行默认操作。

Linux操作系统对每一个标准信号都有默认的操作方式，针对不同种类的标准信号，其默认的操作方式一定会是以下操作中的一个：终止进程、忽略该信号、终止进程并保存内存信息、停止进程、恢复停止的进程。对大多数标准信号可以自定义当进程接收到它们之后应该进行怎样的处理。自定义信号响应的唯一方法是：进程告知操作系统内核，当某种信号到来时，需要执行某种操作。在程序中，信号响应的自定义操作常由函数实现。

Go使用标准库代码包中`os/signal`中的处理信号的API对`标准信号`作出响应。指定了需要被处理的信号并用一种方式（使用到通道类型的变量）来监听信号的到来。

os.Signal接口类型:
```code
type Signal interface {
    String() string
    Signal()//to distinguish from other Stringers
}
```
`Signal`方法的声明无实际意义，作为os.Signal接口类型的一个标识。此接口的所有实现接口的Signal方法都是空方法。

所有此接口类型的实现类型的值都可以代表一个操作系统信号，每一个操作系统都需要由操作系统所支持。

标准库代码包syscall中，为不同的操作系统所支持的每一个`标准信号`都声明一个相应的同名常量(信号常量)，信号常量的类型都是syscall.Signal的，是os.Signal接口类型的一个实现，同时也是int类型的别名类型。意味着每一个信号常量都隐含着一个整数值，信号常量的整数值与其所代表的信号在所属操作系统中的编号一致。在syscall.Signal类型的String方法，有一个包级私有名为signal的数组类型的变量，每个索引值代表了一个`标准信号`的编号，对应的元素则是针对该信号的一个简短的描述。

代码包os/signal中的Notify函数用来把操作系统发送给当前进程的指定信号通知给该函数的调用方。
>`func Notify(c chan <- os.Signal, sig ...os.Signal)`

第一个参数是通道类型，该通道中只能传递os.Signal类型的值（信号值），在signal.Notify中，只能向该通道类型值放入信号值，不能从该值中取出信号值。此函数把当前进程收到的指定信号放入参数c代表的通道类型值（signal接收通道）中，调用方代码可以从signal接收通道中按顺序获取操作系统法送来的信号并进行相应的处理。

第二个参数是一个可变长参数，在调用signal.Notify函数时，可以在第一个参数值之后附加任意个os.Signal类型的值，sig代表的参数值包含我们希望自行处理的所有信号。接收到希望自行处理的信号之后，os/signal包中的处理程序（signal处理程序）会把它封装成syscall.Signal类型的值并放入到signal接收通道中。只为第一个参数绑定实际值被当作自行处理所有信号，并把接收到的几乎所有的信号都逐一进行封装并放入到signal接收通道中。
```code
sigRecv := make(chan os.Signal, 1)
sigs := []os.Signal{syscall.SIGINT, syscall.SIGQUIT}
signal.Notify(sigRecv, sigs..)
for sig := range sigRecv {
    fmt.Printf("Received a signal :%s\n",sig)
}
```
创建调用signal.Notify函数所需的两个参数的值。sigRecv是signal接收通道，sigs切片代表了希望自定义处理的SIGINT和SIGQUIT信号。只要sigRecv的值中存在元素值，for语句就会把它们按顺序地接收并赋给迭代变量sig。在sigRecv代表的通道类型值被关闭后，for语句会立即被退出执行，不用担心程序在这里死循环。

signal处理程序在向signl接收通道发送值的时候，不会因为通道已满而产生阻塞。signal.Notify函数的调用方必须保证signal接收通道会由足够的空间缓存并传递接收到的信号。应此可以创建一个足够长的接收通道，或者只创建一个长度为1的通道并时刻准备从该通道中接收信号。

当接收到不想自定义处理的信号，执行操作系统指定的默认操作。指定了想要自行处理的信号但没有在接收到信号时执行必要的处理动作，相当于使当前进程忽略了这些信号。

在类Unix操作系统下的SIGKILL和SIGSTOP信号既不能被自行处理也不会被忽略，对他们的操作只能是执行默认操作。因为它们向系统的超级用户提供了使进程终止或停止的可靠方法，系统不允许任何程序消除或改变与这两个信号所对应的处理动作。

对于其他信号，除了能够自行处理它们之外，还可以使用os/signal包中的Stop方法在之后的任意时刻恢复针对它们的系统默认操作。其声明为：
>`func Stop(c chan <- os.Signal)`

参数声明与signal.Notify函数的第一个参数声明完全一致。函数signal.Stop取消掉在之前调用signal.Notify函数的时候告知signal处理程序需要自行处理的若干信号的行为。把当初传递给signal.Notify函数的signal接收通道作为调用signal.Stop函数的参数。调用signal.Stop函数后，作为其参数的signal接收通道将不会再被发送任何信号。这会使之前被用于从signal接收通道接收信号值的for语句一直阻塞，需要再调用signal.Stop函数之后使用内建函数close关闭该signal接收通道。此是for语句会退出执行。

只取消部分自行处理信号的行为，可再次调用signal.Notify函数并重新设定于其参数sig绑定的、以os.Signal为元素类型的切片类型值（信号集合），第一个参数的signal接收通道要相同。若signal接收通道不同，signal处理程序会将两次调用视为毫不相干，分别看待这两次调用时所设定的信号集合。

signal处理程序内部存在一个包级私有字典（信号集合字典）用于存放signal接收通道为键、以信号集合的变体为元素的键值对。调用sianal.Notify函数时，signal处理程序就会在信号集合字典中查找相应的键值对，如果键值对不存在，就向信号集合字典添加这个新的键值对，否则就更新该键值对中信号集合的变体。前者相当于向signal处理程序注册一个信号接收保证的申请，后者相当于更新该申请，signal接收通道作为调用方接收信号的为一途经，成为申请的标识。调用signal.Stop函数时，signal处理程序会删除掉信号集合字典中以该函数的参数值（某个signal接收通道）为键的键值对。

当接收到一个发送当前进程且已被标识为应用程序想要自行处理的操作系统信号之后，signal处理程序会对它进行封装，然后遍历信号集合字典中的所有键值对，并查看它们的元素中是否包含了该信号。若包含，就会立即把它发送给作为键的signal接收通道。

<!-- signal接收通道再Go提供的操作系统信号通知机制中起到了很重要的作用，能否合理地处理操作系统的信号，基本在于signal接收通道的初始化和使用的方式。 -->

使用os.StartProcess函数启动一个进程,或者使用os.FindProcess函数查找一个进程,两个函数都返回一个*os.Process类型的值(进程值)和一个error类型的值。可以调用该进程值的Signal方法向该进程发送一个信号，其接受一个os.Signal类型的参数值并返回一个error类型值。

>`ps aux | grep "mysignal" | grep -v "grep" | awk '{print $2}'`

`go run`命令程序中执行一系列的操作，包括依赖查找、编译、打包、链接等步骤，完成之后会有一个与被运行的命令源码文件的主文件名同名的可执行文件被生成在相应的临时工作目录中。实际上与`go build`命令生成的可执行文件一致，但是运行执行可执行文件而产生的进程是一个全新的进程，与代表了`go run mysignal.go`命令的进程毫不相干。即两个进程互相独立，都拥有自己的进程ID。使用`go run`命令运行mysignal.go，命令会生成并执行可执行文件mysignal，然后该可执行文件所产生的输出会通过该命令程序打印到标准输出上。即该命令程序被挂起、停止或终止后，mysignal中程序所打印的内容也再不会出现在标准输出上。

>`ps aux | grep "mysignal" | grep -v "grep" | grep -v "go run" | awk '{print $2}'`

加入`grep -v "go run"`过滤掉原先进程列表中的与`go run`命令对应的进程。

信号与管道都被称为基础的IPC方法。再基于数据传递的解决方案中，要保证数据的原子性，管道不提供这种原子性保证，Go标准库中提供的API也没有附加这种保证。

### Socket
Socket，常被译为套接字，通过网络连接来使两个或更多的进程建立通讯并相互传递数据。使通讯端的位置透明化。
#### 1.Socket的基本特征
在Linux操作系统中存在一个名为Socket的系统调用。
```code
int socket(int domain, int type, int protocol)
```
接收三个参数分别代表了这个Socket的通讯域、类型和所用协议。通讯域决定了该Socket的地址格式和通讯范围。

通讯域 | 含义 | 地址形式 | 通讯范围
 :---: |:---: |:--- | :---
 AF_INET | IPv4域 | IPv4地址（4个字节），端口号（两个字节）| 在基于IPv4协议的网络中的任意两台计算机之上的两个应用程序
 AF_INET6 | IPv6域 | IPv6地址（16个字节），端口号（两个字节） | 在基于IPv6协议的网络中的任意两台计算机之上的两个应用程序
 AF_UNIX | Unix域 | 路径名称 | 在同一台计算机上的两个应用程序

`AF`是“address family”的缩写。

Socket的类型有SOCK_STREAM、SOCK_DGRAM、面向更底层的SOCK_RAW、针对某个新兴数据传输技术的SOCK_SEQPACKET。

特性 | SOCK_DGRAM | SOCK_RAW | SOCK_SEQPACKET | SOCK_STREAM
:---: | :---:|:---: | :---: | :---:
数据形式 | 数据报 | 数据报 | 字节流 | 字节流
数据边界 | 有 | 有 | 有 | 没有
逻辑边界 | 没有 | 没有 | 有 | 有
数据有序性 | 不能保证 | 不能保证 | 能够保证 | 能够保证
传输可靠性 | 不具备 | 不具备 | 具备 | 具备

>以数据报为数据形式意味着数据接收方的Socket接口程序可以意识到数据的边界并会对他们进行切分。省去接收方的应用程序寻找数据边界和切分数据的工作量。

>以字节流为数据形式的数据传输传输的是一个字节接着一个字节的串，类似很长的字节数组。一般情况字节流并不能出哪些字节属于哪个数据包。Socket接口程序无法从中分离出独立的数据包。这一工作由应用程序完成。SOCK_SEQPACKET类型的Socket的接口程序不同，数据发送方的Socket接口程序可以记录数据边界，即应用程序每次发送的字节流片段之间的分界点。数据边界信息随着字节流一同被发往数据接收方。数据接收方的Socket接口程序会根据数据边界把字节流切分成（或者说还原成）若干个字节流片段并按照需要依次传递给应用程序。

面向有连接的Socket之间在进行数据传输之前必须要先建立逻辑连接，之后通讯双方可以互相传输数据。连接暗含双方地址，在传输数据时不必再指定目标地址。面向无链接的Socket再进行通讯时无需建立连接，传递的每一个数据包都是独立的，被直接发送到网络上，每个数据包都含有目标地址，数据流是单向的。不能用同一个面向无连接的Socket实例既发送数据又接收数据。

SOCK_RAW类型的Socket提供了一个可以直接通过底层（TCP/IP协议栈中的网络互联层）传递数据。应用程序必须具有操作系统的超级用户权限才能够使用这种方式，使用成本相对较高，应用程序一般需要自己构建数据传输格式（像TCP/IP协议栈中的TCP协议的数据段格式和UDP协议的数据报格式）。应用程序极少使用这种类型的Socket。

一般把0作为Socket的第三个参数值，含义是让操作系统内核根据第一个参数和第二个参数的值自行决定Socket所使用的协议。既Socket的通讯域和类型与所使用的协议之间存在对应关系。

决定因素 | SOCK_DGRAM | SOCK_RAW | SOCK_SEQPACKET | SOCK_STREAM
:---: | :---: | :---: | :---: | :---:
AF_INET | UDP | IPv4 | SCTP | TC或SCTP
AF_INET6 | UDP | IPv6 | SCTP | TCP或SCTP
AF_UNIX | 有效 | 无效 | 有效 | 有效

`有效`表示该通讯域和类型的组合会使内核选择某个内部的Socket协议。  
`无效`表示该通讯域和类型的组合是不合法的。

在没有发生任何错误的情况下，系统调用socket会返回一个int类型的值，该值是作为socket唯一标示符的文件描述符。得到该标示符后，可以调用其他系统调用来进行各种相关操作，例如绑定和监听端口、发送和接收数据以及关闭Socket实例等等。

通过系统调用来操作系统提供的Socket接口，Socket接口程序与TCP/IP协议栈的实现程序一样，是Linux操作系统内核的一部分。

#### 基于TCP/IP协议栈的Socket通讯
通过Socket接口可以建立和监听TCP连接和UDP连接，可以直接与网络互联层的IP协议实现程序进行通讯。

使用标准库代码包net中的API编写服务端和客户端程序。
>`func Listen(net, laddr string)(Listener, error)`

函数net.Listen被用于获取一个监听器，接收两个string类型的参数，参数一表示以何种协议在给定的地址上监听，Go中用一些字符串字面量来表示。

字面量 | Socket协议 | 备注
 :---: | :---: | :---
 "tcp" | TCP | 无
 "tcp4" | TCP | 网络互联层协议仅支持IPv4
 "tcp6" | TCP | 网络互联层协议仅支持Ipv6
 "udp"  | UDP | 无
 "udp4" | UDP | 网络互联层协议仅支持IPv4
 "udp6" | UDP | 网络互联层协议仅支持IPv6
 "unix" | 有效 | 在通讯域协议为AF_UNIX且类型为SOCK_STREAM的时候内核采用的默认协议
 "unixgram" | 有效 | 在通讯域协议为AF_UNIX且类型为SOCK_DGRAM的时候内核采用的默认协议
 "unixpacket"  | 有效 | 在通讯域为AF_UNIX且类型为SOCK_SEQPACKET的时候内核采用的默认协议

函数net.Listen的第一个参数的值所代表的协议必须是面向流的协议，TCP和SCTP都属于面向流的协议，TCP协议实现程序无法记录和意识到任何消息边界，无法从字节流分离出消息，SCTP协议可以做到，使得应用程序无需再在发送的字节流的中间加入额外的消息分隔符，也无需再去查找所谓的消息分隔符并据此对字节流进行切分。
>net.Listen函数的第一个参数的值必须是tcp、tcp4、tcp6、unix和unixpacket中的一个。代表的都是面向流的协议。tcp表示Socket所用的TCP协议会兼容基于IPv4协议的TCP协议和基于IPv6协议的TCP协议。unix和unixpacket代表两个通讯域为Unix域的内部的Socket协议，遵循它们的Socket实例即被用于在本地计算机上的不同应用程序之间的通讯。

第二参数laddr的值代表当前程序在网络中的标识，是Local Address的简写，格式为“host:port”,"host"代表IP地址或主机名，"port"代表当前程序欲监听的端口号。"host"处的内容必须是与当前计算机对应的IP地址或主机名，若是主机名该API中的程序会先通过DNS找到与主机名对应的IP地址，若主机名没有在DNS中注册会造成一个错误。
```code
listener, err := net.Listen("TCP", "127.0.0.1:8000")
```
返回的第一个结果是net.Listener类型，是我们欲获取的监听器，第二个结果是一个error类型值，代表可能出现的错误。
```code
conn, err := listener.Accept()
```
调用时流程会被阻塞，直到某台计算机上的某个应用程序与当前程序建立了一个TCP连接。返回的第一个结果值代表当前TCP连接的net.Conn类型值，第二个结果值是一个error类型值。

代码包net的Dial函数用于向网络中的某个地址发送数据。  
>`func Dial(network, address string)(Conn, error)`   

参数一与net.Listen函数的第一个参数含义类似，拥有更多可选值。发送数据前不一定建立连接，UDP协议和IP协议都是面向无连接型的协议，udp、udp4、udp6、ip、ip4和ip6都可以作为network的值。unixgram也是network参数的可选值之一，代表了一个基于Unix域的内部Socket协议，以数据报作为传输形式。

参数二与net.Listen函数的第二个参数laddr完全一致。名称可由raddr（Remote Address）代替。laddr与raddr相对，前者指当前程序所使用的地址（本地地址），后者指参与通讯的另一端所使用的地址（远程地址）。

客户端的地址不用给出，端口号可以由程序指定，也可由操作系统内核动态分配。使用net.Dial建立Socket连接的客户端程序，占用的端口号由操作系统内核动态分配。客户端程序的地址中的"host"是本地计算机的主机名或IP地址，由操作系统内核指定。也可以自己去指定当前程序的地址，由另外的函数建立连接。
```code
conn, err := net.Dial("tcp", "127.0.0.1:8000")
```
结果值一是net.Conn类型值，结果值二是一个error类型值。  
网络延时表现在此行代码会一直阻塞，超过等待时间后函数的执行就会结束并返回相应的error类型值。不同操作系统对基于不同协议的连接请求的超时时间有不同的设定。Go可使用net包的DialTimeout函数设置超时时间。
>`func DialTimeout(network, address string, timeout time.Duration ) (Conn, error)`

参数三设置超时间，类型为time.Duration，单位是纳秒。可用常量来表示时间，time.Nanosecond代表1纳秒，值为1。常量time.Microsecond代表1微秒，值为1000*Nanosecond，即1000纳秒。time.Second代表1秒。
```code
conn, err := net.DialTimeout("tcp", "127.0.0.1:8000", 2*time.Second)
```
此超时时间不是值此函数执行耗时，还包括DNS解析等耗时。

使用操作系统内核提供的API创建Socket等操作被隐藏在Go提供的Socket API中。

>通过调用net.Listen函数得到一个net.Listener类型值之后，调用该值的Accept方法等待客户端连接请求的到来，收到客户端的连接请求后，服务端与客户端建立TCP连接（三次握手）。成功建立连接后，通过Accept方法得到一个代表了该TCP连接的net.Conn类型值。通讯两端可以分别利用各自获得的net.Conn类型值交换数据。

Go的Socket编程API在底层获取的是一个非阻塞式的Socket实例，使用Socket接口在一个TCP连接上的数据读取操作是`非阻塞式`的。在应用程序试图通过系统调用read从Socket的接收缓冲区中读取数据时，即使接收缓冲区中没有任何数据，操作系统内核也不会使系统调用read进入阻塞状态，而是返回一个错误码为“`EAGAIN`”的错误，应用程序不会视其为真正的错误，稍等片刻后再去尝试读取。若有数据，系统调用read就会携带这些数据立即返回。即使当时接收缓冲区中只包含了一个字节的数据也会是这样，这一特性被称为`部分读`（partial read）。向发送缓冲区写入一段数据，即使发送缓冲区已经被填满系统调用write也不会被阻塞，而是直接返回错误码为“`EAGAIN`”的错误，应用程序忽略该错误并稍后再尝试写入数据。若发送缓冲区中有少许剩余空间但不足以放入这段数据，那么系统调用write会尽可能地写入一部分数据然后返回已写入的字节的数据梁，这一特性被称为`部分写`（partial write）。应用程序每次调用write之后都会区检查该结果值，并发现数据未被完全写入时继续写入剩下的数据。在非阻塞的Socket接口下，系统调用accept也会显示一致的非阻塞风格，不会被阻塞以等待新连接的到来，会直接返回错误码为“`EAGAIN`”的错误。

Go语言Socket编程API屏蔽了非阻塞式Socket接口的部分写特性，相关API直到把所有数据全部写入到Socket的发送缓冲之后才会返回，除非在写入的过程中发生了某种错误。保留了非阻塞式Socket接口的部分读特性。在TCP协议之上传输的数据是字节流形式的，数据接收方无法意识到数据的边界（消息边界），Socket编程API程序无从判断函数返回的时机。

net.Conn类型是一个接口类型，在它的方法集合中包含了8个方法。
##### Read方法
被用来从Socket的接收缓冲区读取数据。
>`Read(b []byte)(n int, err error)`

接受一个[]byte类型的参数，参数值相当于一个被用来存放从连接上接收到的数据的“容器”。长度由应用程序决定，Read会最多从连接中读取数量等于该参数值的长度的若干字节，并把它们依次放置到该参数值中的相应元素位置上。传递给Read方法的参数值应该是一个不包含任何非零值元素的切片值。一般情况，Read方法只有在把参数值填满之后才会返回。当未填满参数值且参数值靠后部分存在遗留元素时，通过返回的第一个结果值进行真正数据的识别，结果值n代表了实际读取到的字节的个数，即Read方法向参数值中填充的字节的个数。
```code
b := make([]byte, 10)
n, err := conn.Read(b)
content := string(b[:n])
```
若Socket编程API程序在从Socket的接收缓冲区中去读取数据的时候发现TCP连接已经被另一端关闭，则会立即返回一个err处理or类型值，与`io.EOF`变量的值是相等的，象征着文件内容的完结，此处意味着在TCP连接上再无可被读取的数据，即TCP连接已经无用，可以被关闭。若第二个结果值与io.EOF变量的值相等，则应该中止后续的数据读取操作，并关闭该TCP连接。
```code
var dataBuffer bytes.Buffer
b := make([]byte, 10)
for {
    n, err := conn.Read(b)
    if err != nil {
        if err == io.EOF {
            fmt.Println("The connection is closed.")
            conn.Close()
        } else {
            fmt.Printf("Read Error : %s\n", err)
        }
        break
    }
    dataBuffer.Write(b[:n])
}
```
可利用标准库代码包`bufio`（Buffered I/O）中的API实现一些较复杂的数据切分操作，提供了与带缓存的I/O操作有关的支持。net.Conn类型实现了接口类型`io.Reader`中唯一的方法Read，使用`bufio.NewReader`函数（接收一个io.Reader类型的参数值）包装变量conn：
```code
reader := bufio.NewReader(conn)
```
调用reader变量的值之上的ReadBytes方法依次获取经过切分之后的数据。该方法接受一个byte类型的参数值，该参数值是通讯两端协商一致的边界消息。
```code
line, err := reader.ReadBytes('\n')
```
每次调用之后会得到一段以该i边界消息为结尾的数据。消息边界的定位比较复杂，HTTP协议规定消息头部信息的末尾是连续的两个空行“\r\n\r\n”，获取消息的头部信息后，相关程序通过其中名为“Cotent-Length”的信息项的值得到HTTP消息的数据部分的长度。bufio代码包提供了高级的API如`bufio.NewScanner`、`bufio.Sacnner`等函数处理。

##### Write方法
被用来向Socket的发送缓冲区写入数据。
>`Write(b []byte)(n int, err error)`

屏蔽了很多非阻塞式Socket接口的细节，可以简单地调用它不用做其他额外的处理，除非操作超时异常。使用bufio的`bufio.NewWriter`函数（接收接收一个io.Writer类型的参数值）包装变量conn。
```code
writer := bufio.NewWriter(conn)
```
writer的值可被看作针对变量conn代表的TCP连接的缓冲写入器。可以调用其上的以“Write”为名称前缀的方法分批次地向其中的缓冲区写入数据，也可调用`ReadFrom`方法直接从其他`io.Reader`类型值中读出并写入数据，调用Reset方法以达到重置和复用它的目的。写入全部数据后，调用`Flush`方法，保证其中的所有数据都被真正地写入到它的代理对象中。调用`bufio.NewWriterSize`函数初始化一个缓冲写入器，类似`bufio.NewWriter`，自定义将要生成的缓冲写入器的缓冲区容量，解决缓冲写入器的缓冲区容量（默认4096字节）小于写入的数据的字节数量的问题。否则`Write`方法试图把这些数据的全部或一部分直接写入到它代理的对象中，而不会先在自己的缓冲写入器中缓存这些数据。

##### Close方法
关闭当前的连接。不接受任何参数并返回一个error类型值。调用后该连接值上的Read方法、Write方法或Close方法的任何调用都会立即返回一个error类型值。

当调用Close方法时，Read方法或Write方法正在被程序调用且还未执行结束，会立即结束执行并返回非nil的error类型值，即使它们正处于阻塞状态。

##### LocalAddr和RemoteAddr方法
不接受任何参数并返回一个met.Addr类型的结果。代表了参入当前通讯的某一端的应用程序在网络中的地址。LocalAddr返回代表本地地址的net.Addr类型值，RemoteAddr返回代表远程地址的net.Addr类型值。net.Addr类型是一个接口类型，方法集合中有两个方法——Network和String，前者返回当前连接所使用的协议的名称，后者返回相应的地址。
```code
conn.LocalAddr().Network()  //协议名称
conn.RemoteAddr().String()  //于服务端获取另一端（客户端）应用程序的网络地址
conn.LocalAddr().String()   //于客户端获取操作系统内核为该客户端程序分配的网络地址
```

##### SetDeadline、SetReadDeadline、SetWriteDeadline方法
接收一个time.Time类型值，返回一个error类型值。

`SetDeadline`:设置在当前连接上的I/O（包括但不限于读和写）操作的超时时间。为绝对时间对之后的每个I/O操作都起作用，循环从一个连接上读取数据，设定超时时间需要在每次迭代中的读取数据操作之前都设定一次。
```code
b := make([]byte, 10)
for {
    conn.SetDeadline(time.Now().Add(2 * time.Second))
    n, err := conn.Read(b)
    //todo
}
```
>`conn.SetDeadline(time.Time{})`//传入time.Time类型的零值取消超时时间

`SetReadDeadline`:针对读操作，即连接值的Read方法的调用的超时时间。

`SetWriteDeadline`:针对写操作，即连接值的Write方法的调用的超时时间。

SetDeadline方法相当于先后以同样的参数值对SetReadDeadline和SetWriteDeadline方法进行调用。

>在服务端程序中，为了快速，独立地处理已经建立的每一个连接，应该尽量让这些处理过程并发地执行。否则处理已建立的第一个连接的时候，后续连接只能排队等待。

Go语言标准库中，一些实现了某种网络通讯功能的代码包都是以net代码包所提供的Socket编程API为基础，如net/http代码包。标准库代码包net/rpc中的API为我们提供了在两个Go语言程序之间建立通讯和交换数据的另一种方式——远程过程调用（Remote Procedure Call）。基于TCP/IP协议，使用net包以及net/http包提供的API。

阅读`gpoc/src/multiproc/socket/tcpsock.go`小demo加深socket编程理解。