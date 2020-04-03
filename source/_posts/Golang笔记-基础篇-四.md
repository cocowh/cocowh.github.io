---
title: Golang笔记-基础篇(四)
tags: [Golang,笔记,基础]
comments: true
categories: [Golang]
date: 2018-04-13 19:23:05
---

## Go流程控制像C，也有很多方面与C不同：  

* 没有do和while循环，只有更加广义的for。
* switch更加灵活，可以被用于进行类型判断。
* 与for类似，if和switch语句都可以接受一个可选的初始化语句。
* 支持在break语句和continue语句之后跟一个可选的标记（Label）语句，表示需要终止或继续的代码块。
* 有类似多路转接器的select语句。
* 语句可以被用于地启用Coroutine。
* 使用defer语句可以更方便地执行异常捕获和资源回收任务。

## 基本流程控制
### 代码块和作用域

由花括号“{”和“}”括起来的若干表达式和语句的序列。不包含任何内容为空代码块。  
隐式代码块：  

* Go语言源码，全域代码块。
* 代码包，代码包代码块。
* 源码文件，源码文件代码块。
* 每个if语句、for语句、switch语句和select语句都是一个代码块。
* 每个switch或select语句中的字句都是一个代码块。

每一个标识符都有它的作用域，使用代码块表示作用域范围：  

* 预定义标识符作用域全局代码块。
* 代表常量、类型、变量或函数的、被声明在顶层的标识符的作用域时代码包代码块。
* ...

可以重声明外层代码块声明过的标识符，将外层同名标识符屏蔽。

>Go通过标示符首字母的大小写控制对应程序实体的访问权限，标示符首字母大写则其对应的程序实体可被本代码包之外的代码访问到，即可导出的。小写则对应的程序实体就只能被本包内的代码访问。

### if语句
#### 组成和编写方法

条件表达式可不用括号括起来，条件表达式之后和else关键字之后必须由花括号括起来。

```code
if 100 < number {
    //todo
} else {
    //todo
}
---
if diff := 100 - number; 100 < number {
    //todo
} else if 200 < diff{
    //todo
} else {
    //todo
}
```

if语句接受一条初始化语句。

#### 惯用法

作为卫述语句用来检查关键的先决条件的合法性并在检查未通过的情况下立即终止当前代码块的执行的语句。

```code
/*
标准库代码包os函数
func Open(name string) (file *File, err error)
/*
f, err := os.Open(name)
if err != nil {
    return err
}
---
func update(id int,deptment) bool{
    if id <= 0 {
        return false
    }
    return true
}
->
func update(id int,deptment) errorl{
    if id <= 0 {
        return errors.New("The id is INVALID")
    }
    //todo
    return nil
}
```

### switch语句
#### 组成和编写方式

同其他（C/C++等）语言，判定条件无括号。

#### 表达式switch语言

选择case执行后直接忽略其他case，而不需要break打断，没有case选择执行则执行default case，default case非必须作为最后一个case出现。不同于其他语言，break的使用方法也有些不一样。条件表达式可不用括号括起来，可接受一条初始化语句。

```code
switch content := getContent(); content {
    default:
        ftm.Println("Unknown language")
    case "PHP":
        ftm.Println("Protect Hair Prefact")
    case "Java":
        ftm.Println("shit language")
}
```

在除了最后一条case语句的每一条case语句中的语句列表的最后一条语句可以是fallthrough语句，会将流程控制权转移到下一条case语句上。可以把多个case值放在一个case上。break语句被执行，包含它的switch语句、for语句或selet语句的执行会被立即终止执行，流程控制权被转移到这些语句后面的语句上。

```code
switch content := getContent(); content {
    default:
        fmt.Println("wuhua is cool")
    case "smart":
        fallthrough
    case "fool":
        break
        fmt.Println("Bye")
    case "cute", "handsome", "honest":
        fmt.Println("yes, he is")
}
```
#### 类型switch语句

对类型进行判断而不是值。

```code
switch v.(type) {
    case string:
        fmt.Printf("The string is '%s'.\n",v.(string))
    case int, uint, int8, uint64:
        fmt.Printf("The integer is %d.\n",v)
    default:
        fmt.Printf("Unsupported value.(type = %T).\n",v)
}
=>
switch i := v.(type) {
    case string:
        fmt.Printf("The string is '%s'.\n", i)
    case int, uint, int8, uint64:
        fmt.Printf("The integer is %d.\n", i)
    default:
        fmt.Printf("Unsupported value.(type = %T).\n", i)
}
```

>fallthrough语句不允许出现在类型switch语句中的任何case语句的语句列表中。

#### 惯用法

替换串连if语句。在switch表达式缺失时，判定目标被时为布尔值true。

```code
switch number := 1995; {
    case number < 1990:
        fmt.Println("90前")
    case number >= 2000:
        fmt.Println("00后")
    default:
        fmt.Println("90后")
}
```

### for语句
#### 组成和编写方法

同其他语言。若无条件，则true将会作为缺省的条件。

#### for子句

一条for语句可以携带一个for字句提供条件对迭代进行控制。由初始化字句、条件、后置字句组成，同其他语言。省略括号。

```code
for i := 0; i < 100; i++ {
    number++
}
---
var j uint = 1;
for ;j % 5 != 0; j *= 3{
    number++
}
---
for k := 1; k % 5 != 0; {
    k *= 3
    number++
}
```
#### range子句

for语句可携带一个range子句，迭代出一个数组或切片值中的每个元素、一个字符串中的每个字符或者一个字典之中的每个键值对。

```code
ints := []int{1, 2, 3, 4, 5}
for i,d := range ints {
    fmt.Printf("%d: %d\n", i, d)
}
---
ints := []int{1, 2, 3, 4, 5}
length := len(ints)
indexesMirror := make([]int, length)
elementsMirror := make([]int, length)
var i int
for indexesMirror[length - i - 1],elementsMirror[length - i - 1] = range ints{
    i++
}
```

随着range表达式的结果值的不同，range字句会有不同的表现：  

* 数组、数组指针、切片，range循环的迭代产出值可以是一个也可以是两个。迭代顺序与索引递增顺序一致。第一个产出值为索引，第二个为索引对应元素值。
* 字符串，遍历其Unicode代码点。第一个产出值为索引，第二个为索引对应元素值，类型为rune。
* 字典，迭代顺序不固定，迭代过程中键值对被删除，相应的迭代值不会被产出，新增，相应的迭代值是否被产出不确定。第一个产出值为键值对中键的值，第二个为与键对应元素值。
* 通道类型，迭代效果类似于连续不断的从该通道中接收元素值，直到通道被关闭。若通道为nil，range表达式被永远阻塞。每次迭代，仅会产出一个通道类型值。

#### 惯用法

```code
m := map[uint]string{1:"A", 6:"C", 7:"B"}
var maxKey uint
for k := range m {
    if k > maxKey {
        maxKey = k
    }
}
---
var values []string
for _, v := range m {
    values = append(values, v)
}
```

使用break终止for循环，可配合标记（Lable）语句一起使用。一条标记语句可以成为goto语句、break语句、continue语句的目标。标记语句中的标记只是一个标识符，可以放在任何语句的左边以作为这个语句的标签，标记和被标记的语句之间用冒号“:”来分隔。例如：

```code
L:
    for k, v := range namesCount{
        //todo
    } 
```

在break语句后跟标记，意味着终止执行的对象就是标记代表的那条语句。continue只在for语句中使用，会是直接包含它的那个for循环直接进入下一次迭代。在continue后跟标记，意味着跳过后面的执行语句，开始执行标记代表的那条语句。

```code
var namesCount map[string]int
//为用户昵称及其重复次数，统计只包含中文的用户昵称的计数信息
targetsCount := make(map[string]int)    
for k,v := range namesCount {
    matched := true
    for _,r := range k {
        if r < '\u4e00' || r > '\u9fbf' {
            matched = false
            break
        }
    }
    if !matched {
        continue
    }
    targetsCounts[v] = v
}
---
targetsCount := make(map[string]int)    
L:
    for k,v := range namesCount {
        for _,r := range k {
            if r < '\u4e00' || r > '\u9fbf' {
               continue L
            }
        }
        targetsCounts[v] = v
    }
```

使用for循环反转一个切片类型值中的所有元素值：

```code
for i, j := 0, len(numbers) - 1; i < j; i ,j = i + 1, j -1{
    numbers[i], numbers[j] = numbers[j], numbers[i]
}
```
### goto语句

把流程控制权限无条件转移到标记所代表的语句上。

#### 组成和编写方法
只能与标记语句连用。需要注意goto语句跳过的某些声明语句，导致标签所代表的语句缺少应有的变量。标记语句的直属代码块应为goto语句的直属代码块的外层代码块。


```code
    if n % 3 != 0 {
        goto L
    }
    switch {
        case n % 7 == 0:
            n = 200
            fmt.Printf("%v is a common multiple of 7 and 3.\n", n)
        default:
    }
L1:
    fmt.Printf("%v isn't a multiple of 3.\n ", n)
```

#### 惯用法

```code
//查找name中的第一个非法字符并返回
//如果返回的是空字符就是明name中不包含任何非法字符
func findEvildoer(name string) string {
    var evildoer string
    for _, r := range name {
            switch {
                case r >= '\u0041' && r <= '\u005a': //a-z
                case r >= '\u0061' && r <= '\u007a': //A-z
                case r >= '\u4e00' && r <= '\u9fbf': //中文字符
                default:
                    evildoer = string(r)
                    goto L1
            }
    }
    goto L2
L1:
    fmt.Printf("The first evildoer of name '%s' is '%s' !\n", name, evildoer)
L2:
    return evildoer
}
---
func findEvildoer(name string) string {
    var evildoer string
L1:
    for _, r := range name {
            switch {
                case r >= '\u0041' && r <= '\u005a': //a-z
                case r >= '\u0061' && r <= '\u007a': //A-z
                case r >= '\u4e00' && r <= '\u9fbf': //中文字符
                default:
                    evildoer = string(r)
                    break L1
            }
    }
    if evildoer != ""{
        fmt.Printf("The first evildoer of name '%s' is '%s' !\n", name, evildoer)
    }
    return evildoer
}
---
func checkValidity(name string) error {
    var srrDetail string
    for i, r := range name {
        switch {
            case r >= '\u0041' && r <= '\u005a': //a-z
            case r >= '\u0061' && r <= '\u007a': //A-z
            case r >= '\u4e00' && r <= '\u9fbf': //中文字符
            case r == '_' || r == '-' || r == '.':
            default:
                    errDetail = "The name contains some illagal characters."
                    goto L
        }
        if i == 0 {
            switch r {
                case '_':
                errDetail = "The name can not begin with a '_'."
                goto L
                case '-':
                errDetail = "The name can not begin with a '-'."
                goto L
                case '.':
                errDetail = "The name can not begin with a '.'."
                goto L
            }
        }
    }
    return nil
L:
    return errors.New("Validity check failure:" + errDetail)
}
```

和其它语言编程风格一样，为代码简洁清晰，有节制使用goto。

## defer语句

特有的流程控制语句，被用于预定对一个函数的调用，称为延迟函数，只能出现在方法或者函数的内部。

```code
defer fmt.Println("The finishing touches.")
```

外围函数（调用defer的函数）执行的结束会由于defer语句的执行而被推迟，所有的defer语句执行完，外围函数才执行结束。  

使用defer语句执行释放资源或异常处理等收尾任务。

defer语句调用函数的参数会按普通从上到下的执行顺序初始化，但defer语句调用的函数仅在外围函数的执行将要结束时才会执行，可将defer语句置于函数或方法体内任何位置。多个defer语句的函数的顺序调用，按LIFO的执行顺序，但参数按FIFO的顺序初始化。

```code
defer func(){
    fmt.Println("The finishing touches.")
}()//调用匿名函数
---
func start(tag string) string{
    fmt.Ptintf("start function %s.\n", tag)
    return tag
}
func finish(tag string) {
    fmt.Printf("finish function %s.\n", tag)
}
func tag(){
    defer finish(start("sign"))
    fmt.println("record the tag  sign")
}
/*
    start function sign
    record the tag sign
    finish function sign
*/
---
func printNumbers() {
    for i := 0; i < 5; i++ {
        defer fmt.Printf("%d ", i)
    }
}
/*
    4 3 2 1 0
*/
---
func printNumbers() {
    for i := 0; i < 5; i++ {
       defer func() {
           fmt.Printf("%d ", i)
       }()
    }
}
/*
    5 5 5 5 5
*/
//defer 在循环结束后执行，此时i = 5，未传参，引入的是外层变量i。
---
func modify(n int) (number int) {
    defer func(plus int) (result int) {
        result = n + plus   //result初始0，result = 2 + 3 = 5
        number += result    //number = 1 + 5 = 6
        return
    }(3)
    number++    //指定结果初始零值0，number = 0 + 1 = 1
    return
}
/*
    modify(2) = 6
*/ 
```


## 异常处理
### error
使用error类型值表明非正常的状态。属于预定义标识符，代表Go语言内建的接口类型。

```code
type error interface {
    Error() string
}
```

Error为方法调用提供当前错误的详细信息。任何数据类型只要实现这个可以返回string类型值的Error方法就可以成为一个error接口类型的实现。标准库代码包errors提供用于创建error类型值的函数New。

```code
func New(text string) error {
    return &errorString{text}
}
type errorString struct {
    s string
}
func (e *errorString) Error () string {
    return e.s
}
```

传递给errors.New函数的参数值是调用它的Error方法的时候返回的结果值，即传递给errors.New的参数值是其返回的error类型值的字符串表示形式。

```code
err := fmt.Errorf("%s\n", "A normal error.")
```

fmt>Errorf函数根据格式说明符和后续参数生成一个字符串类型值，用此字符串类型值初始化一个error类型值并作为结果值返回给调用方。fmt.Errorf函数内部，创建和初始化error类型值的操作通过调用errors.New函数完成。  

可根据需要定义自己的error类型。例如osPathError：

```code
type PathError struct {
    Op string   //"Open", "unlink",etc
    Path string //The associated file
    Err error   //Returned bu the system call
}
func (e *PathError) string {
    return e.Op + " " + e.Path + ": " + e.Err.Error()
}
```

对此例，通常为遵循面向接口编程的原则，函数或方法中的相关结果声明的类型应该是error类型，不该是某一个error类型的实现类型。需要先判定获取到的error类型值的动态类型，再依此来进行必要的类型转换和后续操作。

```code
file, err := os.Open("/etc/profile")
if err != nil {
    if pe, ok := err.(*os.PathError); ok{
        fmt.Printf("Path Error: %s (op = %s, path = %s)", pe,Err, pe.Op, pe.Path)
    } else {
        fmt.Printf("Uknown Error: %s", err)
    }
}
```

### panic和recover

不应该通过调用painc函数来报告普通的错误，而应该把它作为报告致命错误的一种方式。

#### painc

用于报告程序运行期间的、不可恢复的错误状态，停止当前控制流程的执行并报告一个运行时的恐慌。接受任意类型的参数值，通常是string或者error类型。  

运行时恐慌会沿着调用栈方向进行传达，直至到达当前Goroutine(Go程，一个能够独占一个系统线程并在其中运行程序的独立环境)调用栈的顶层。此时当前Goroutine的调用栈的所有函数的执行都被停止，意味着程序崩溃。运行时恐慌也可以由Go语言的运行时系统来引发。

#### recover

运行时恐慌一旦被引发就会像调用方传递直至程序崩溃。recover函数可以“拦截”运行时恐慌，将当前程序从运行时恐慌的状态中恢复并重新获得流程控制权。  
defer语句重的延迟函数总会执行，只有在defer语句的延迟函数中调用recover函数才能够起到“拦截”运行时恐慌的作用。

```code
package main
//import **
func main() {
    fetchDemo()
    fmt.Println("The main function is excuted.")
}
func fetchDemo(){
    defer func(){
        if v := recover(); v!= nil {
            fmt.Printf("Recovered a painc.[index = %d]\n", v)
        }打印语句
    }()
    ss := []string{"A", "B", "C"}
    fmt.Printf("Fetch the elements in %v one by one...\n",ss)
    fetchElement(ss, 0)
    fmt.Println("The elements fetching is done.")
}
func fetchElement(ss []string, index int) (element string) {
    if index >= len(ss) {
        fmt.Printf("Occur a panic! [index = %d]\n", index)
        panic(index)
    }
    fmt,Printf("Fetching the element...[index = %d]\n",index)
    element = ss[index]
    defer fmt.Printf("The element is \"%s\".[index = %d]", element, index)打印语句
    fetchElement(ss, index + 1)
    return
}
/*
1:  Fetch the elements in [A B C ] one by one...
2:  Fetching the element...[index = 0]
3:  Fetching the element...[index = 1]
4:  Fetching the element...[index = 2]
5:  Occur a panic! [index = 3]
6:  The element is "C".[index = 2]
7:  The element is "B".[index = 1]
8:  The element is "A".[index = 0]
9:  Recovered a painc.[index = 3]
10: The main function is excuted.
*/
```

索引超出主动引发运行时恐慌沿着调用栈逐一向上层传达，在向上层传达前只执行本代码块（fetchElement）的defer语句的函数。直到上层（fetchDemo）在传达恐慌前执行defer中recover函数“拦截”恐慌，此时意味着此层代码已经执行结束，打印语句  

  fmt.Println("The elements fetching is done.")  
没能够执行。调用fetchDemo的mian函数重获流程控制权限。  

常用处理：

>程序实体内部发生运行时恐慌，会在被传递给调用方之前被“平息”并以error类型值的形式返回给调用方。  
应该在遇到知名的、不可恢复的错误状态时才去引发一个运行时恐慌，否则可以利用函数或方法的结果值来向程序调用方传达错误状态。  
应该仅在程序处理模块的边界位置上的函数或方法中对运行时恐慌进行“拦截”和“平息”。  

