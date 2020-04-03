---
title: Golang笔记-基础篇(二)
tags: [Golang,笔记,基础]
comments: true
categories: [Golang]
date: 2018-04-11 12:20:24
---
## 数据类型
### 基本数据类型

 >string、bool、byte、rune、int/uint、int8/uint8、int16\uint16、int32/uint32、int64/uint64、float32、float64、
 complex64、complex128  

 分为三类。
#### 布尔类型

> bool：true、false

####  数值类型  
 特殊rune

>类型rune的值由rune类型字面量代表，专用于存储经过Unicode编码的字符。     
    一个rune常量即是一个Unicode编码值，使用十六进制表示法来表示与Unicode对应的数字值，并使用“U+”作为前缀。  
    一个rune字面量由外层的单引号和内层的一个或多个字符组成，在包裹字符的单引号中不能出现单引号“'”和换行符“\n”。    
    
可以用5种方式来表示一个rune字面量    

1. 该rune字面量所对应的字符。如：'a'、'-'，字符必须是Unicode编码规范所支持。  
2. 使用“\x”为前导并后跟两位十六进制数。可以表示宽度为一个字皆的值，即一个ASCII编码值。    
3. 使用“\”为前导并后跟三位八进制数。宽度限制为一个字皆，只能用于表示对应数值在0和255之间的值。  
4. 使用“\u”为前导并后跟四位十六进制数。只能用于表示两个字节宽度的值，为Unicode编码规范中的UCS-2表示法。  
5. 使用“\U”为前导并后跟八位十六进制数。为Unicode编码规范中的UCS-4表示法。为Unicode编码规范和相关国际标准中的规范编码格式。 


rune字面量可以支持转义符，有固定的几个，在规定之外的以“\”为前导的字符序列都是不合法的，转义符“\"”也不能出现在rune字面量中。

#### 字符串类型  

字符串的长度即是底层字节序列中字节的个数，一个字符串常量的长度在编译期间就能够确定。  
字符串代表了一个连续的字符序列，每一个字符都会被隐含地以Unicode编码规范的UTF-8编码个是编码为若干字节。  

字符串字面量的两种表示格式：原生字符串字面量和解释型字符串字面量。  
  
>原生字符串字面量在两个反引号“`”之间的字符序列。在反引号之间，除了反引号之外的其他字符都是合法的，两个反引号之间的所有内容都看作是这个原生字符串字面量的值，其内容由在编译期间就可以确定的字符（非解释型字符）组成。原生字符串字面量中，不存在任何转义字符，所有内容都是所见即所得，也包括换行符。原生字符串字面量中的回车符会被编译器移除。    
  
>解释型字符串字面量是被两个双引号“"”包含的字符序列。解释型字符串中的转义字符都会被成功转义。在解释型字符串字面量中，转义符“\'”是不合法的，而转义字符“\"”却是合法的，与rune字面量相反。在字符串字面量中可以包含rune字面量。  
    
字符串字面量与rune字面量的本质区别是在于他们所代表的Unicode字符的数量上。

>字符串值是不可变的，不可能改变一个字符串的内容，对字符串的操作只会返回一个新字符串，而不是改变原字符串并返回

### 数组

一个数组就是一个由若干个相同类型的元素组成的序列。   
 
####  1. 类型表示法  
声明要指明长度和元素类型
 
```code
 [n]T  //[非负整数字面量]元素类型
 [2*3*4]byte
 [5]struct{name,address string} //自定义匿名结构体类型
```
####  2. 值表示法  
值由符合字面量表示

```code
[6]string{"I", "am", "a", "loser", ".", "yes"} 
=>[6]string{0:"I", 1:"am", 2:"a", 3:"loser", 4:".", 5:"yes"}
->[6]string{2:"I", 1:"am", 5:"a", 4:"loser", 0:".", 3:"yes"}
->[6]string{5:"I", 0:"am", "a", "loser", ".", "yes"}

[6]string{"I", "am", "a", "loser"}
=>[6]string{0:"I", 1:"am", 2:"a", 3:"loser", 4:"", 5:""}

[6]string{1:"I", "am", 4:"a", "loser"}
=>[6]string{1:"I", 2:"am", 3:"", 4:"a", 5:"loser"}

[...]string{"I", "am", "a", "loser"}
=>[4]string{"I", "am", "a", "loser"}
```

* 默认第一个元素值对应索引值0，之后的每个元素值的索引值都是在前一个元素值的索引值的基础上再加1，可以显式的指定索引值。
* 在数组中未指定的元素将会被填充为元素类型的零值，可以通过显式地指定索引值来改变被填充元素值的位置。
* 用特殊标记“...”替换为数组长度，意为并不显式地指定数组值的长度，而让Go语言编辑器为我们计算该值所包含的元素值的数量并以此确定这个长度的值。可以避免由于指定的长度和元素值的实际数量不相符而导致的多于零值元素或编译错误。

>0 <= 索引值 < 数组长度  
指定的索引值不能与其他元素值的索引值重复，不论其他元素值的索引值是隐含对应的还是显式对应的。  

####  3. 属性和基本操作  
使用函数len计算数组值长度

```code
len([...]string{"I", "am", "a", "loser" })
```
通过索引值访问元素

```code
[...]string{"bighua", ".", "com"}[0] => "bighua"
```
通过索引值改变对应元素

```code
array1 := [...]string{"bighua", ".", "com"}
array1[0] = "cocowh.github"
array1[2] = "io"
```

### 切片
Slice可以看作是Array的一种包装形式，是针对其底层包装数组中某个连续片段的描述苻，包装的数组称为该切片的底层数组。
#### 类型表示法
由一对中间没有任何内容的方括号和代表其元素类型的标识符组成。

```code
[]T
```
长度并不是切片类型的一部分，不会出现在表示切片类型的类型字面量中，切片的长度是可变的，相同类型的切片值可能会有不同的长度。

```code
[]rune
[]struct{name,department string}
```
切片类型声明中的元素类型可以是任意一个有效的Go语言数据类型。
#### 值表示法
切片的零值为nil，在初始化之前，一个切片类型的变量值为nil。
>切片值的长度为其所含的元素值的实际数量，使用函数len获取切片值的长度。

```code
len([]string{4:"bighua", 2: ".",  "com"})  ##= 5
```
在切片类型的零值（即nil）上应用内建函数len将会得到0。
>一个切片一旦被初始化，就会与一个包含了其中元素值的数组相关联，即一个切片值总会持有一个对某个数组值的引用。

多个切片值可能会共用同一个底层数组。把一个切片值复制成多个，或者针对其中的某个连续片段再切片成新的值，这些切片值所引用的都会是同一个底层数组。对切片值中的元素值的修改，实质上就是对其底层数组上的对应元素的修改，作为底层数组中元素值的改变，也会体现到引用该底层数组且包含该元素值的所有切片之上。切片值类似于指向底层数组的指针。  
>切片值的容量是其能够访问到的当前底层数组中的元素值的最大数量，即从其中的指针指向的那个元素值到底层数组的最后一个元素值的计数值，用内建函数cap获取。

```code
cap([]string{4:"bighua", 2:".", "com"})   //=5
```
此例中切片值的容量就等于它的长度，对切片类型的零值应用内建函数cap也会得到0。
>一个切片值的底层数据结构中包含一个指向底层数组的指针类型值、一个代表切片长度的int类型值和一个代表切片容量的int类型值。  

>使用复合字面量初始化一个切片值的时候，首先创建的是这个切片值所引用的底层数组，该底层数组与这个切片值有相同的元素类型、元素值及其排列顺序和长度，因此切片值的长度和容量一定相同。  

>切片表达式的作用不是复制数组值中某个连续片段所包含的元素值，而是创建一个新的切片值，新的切片值中包含了指向这个连续片段中的第一个元素值的指针。

```code
array := [...]string{"I", "am", "wuhua", "a", "loser"}     //底层数组长度5，即切片容量5
slice := array[:4]      //切片长度4，能够访问前4个元素值
slice = slice[:cap(slice)] //扩大窗口，改变长度为容量，能够访问所有元素值
```
通过切片的方式把slicede的窗口扩展到最大，此时slice的值的长度等于其容量，窗口只能向索引值递增的方向拓展。当一个切片的索引值不在切片的长度范围内时，会引起一个运行时恐慌。  
使用内建函数append对切片值进行拓展：

```code
array := [...]string{"I", "am", "wuhua", "I", "am", "a", "loser"}  
slice := array[:4]
slice = append(slice, "bughua", ".", "com")
/*
slice ===> []string{"I", "am", "wuhua", "I","bughua", ".", "com"}
长度扩展到最大容量7，此时array第5、6、7元素被改变
array ===> [7]string{"I", "am", "wuhua", "I","bughua", ".", "com"}  
*/

---
slice1 := append(slice, "bughua", ".", "com")
/*
不会改变slice的值，声明并初始化一个新变量slice1
slice1 ===> []string{"I", "am", "wuhua", "I","bughua", ".", "com"}
array第5、6、7元素被改变
array ===> [7]string{"I", "am", "wuhua", "I","bughua", ".", "com"}  
*/
```
第一个参数为将要被拓展的切片，第二个可变长参数类型应与第一个参数元素类型相同，与作为拓展内容的一个或多个元素值绑定。此函数又返回结果，结果的类型与其第一个参数的类型完全一致。  
append函数不是在原始切片值上进行拓展，而是创建一个新的切片值，在无需扩容时，此切片值与原切片值共用一个底层数组，指针类型值和容量值与原切片值保持一致。

```code
array := [...]string{"I", "am", "wuhua", "I", "am", "a", "loser"}  
slice := array
slice = append(slice, "bughua", ".", "com")
/*
此时长度超出容量，会创建一个新的长度大于需要存储的元素值总和的底层数组，新切片指针、长度、容量改变。
*/相似
```
上例中slice长度超出容量，此时会有一个新的数组值被创建并初始化，新的数组值将作为在append函数新创建的切片值的底层数组，包含原切片之中的全部元素值以及作为拓展内容的所有元素值。此底层数组的长度总是大于需要存储的元素值的总和，新切片值中的指针将指向其底层数组的第一个元素值，长度和容量与其底层数组的长度相同。  

```code
slice = append(slice, slice1...)
---
slice1 = nil
slice1 = append(slice2, slice...)
---
var slice2 []string
slice2 = append(slice2, slice...)
```
运用“...”符号，集合追加方式。
>如果容量上限索引被指定，作为切片表达式的求值结果的新切片值的容量则为容量上界索引与元素下界索引之间的差值。指定容量上界索引的目的是为了缩小新切片值的容量。

```code
var arrray = [10]int{0, 1, 2, 3, 4, 5, 6, 7, 8, 9}
slice := array[2:6]
/*可直接修改array对应索引值在[2,6)的元素值，通过扩大slice窗口，可修改array对应索引值[6,8)的元素值*/
---
slice :=array[2:6:8]
/*即使扩大长度也仅能访问修改array中对应索引值[2,8)的元素值*/
---
slice = append(slice, []int{10 ,11, 12, 13, 14, 15}...)
/*拓展超出容量创建新的底层数组，指针指向新底层数组，彻底无法访问修改array的元素值*/
```
> 使用容量上限索引能有效的精细控制切片值对其底层数组的访问权限。  
指定容量上限索引时，元素上界索引时不能够省略的，可以省略元素下界索引。

使用内建函数copy批量赋值切片值中的元素。

```code
slice1 := []string{"I", "love", "my", "family"}
slice2 := []string{"bighua", ".", "com"}
n1 := copy(slice1,slice2)
/*
n1 = 3
slice => []string{"bighua", ".", "com", "family"}
*/
```
把原切片值（参数二）中的元素值复制到目标切片值（参数一）中，返回被复制的元素值的数量。参数一和参数二的元素类型必须一致，实际复制的元素值的数量等于长度较短的切片值的长度。  
切片类型相当于于其他编程语言中的动态数组类型，扩展机制也与动态数组类型相似。

### 字典
字典（Map）是哈希表（Hash Table）的一个实现。哈希表是一个实现了关联数组的数据结构，关联数组是用于代表键值对的集合的一种抽象数据类型，在一个键值对集合中，一个键最多能够出现一次。与这个抽象数据结构相关联的操作有：  
 
 * 向集合中添加键值对。
 * 从集合中删除键值对。
 * 修改集合中已存在的键值对的值。
 * 查找一个特定键所对应的值。

哈希表通过哈希函数建立键值对的内部关联，键值对之间是没有顺序关系的。
#### 类型表示法
如果一个字典类型中的键的类型为K，且元素的类型为T，字典类型的类型字面量为：

```code
map[K]T
---
map[int]string
map[string]struct{name,department string}
map[string]interface{}
```
字典类型的键类型和元素类型都需要在其声明中指定，元素类型可以是任意一个有效的Go语言数据类型，键类型不能是函数类型、字典类型或切片类型，键类型必须是可比较的。若键类型是接口类型，在程序运行期间，该类型的字典值中的每一个键值的动态类型都必须是可比较的，否则引起运行时异常。
#### 值表示法

由复合字面量表示。

```code
map[string]bool{"bighua":true, "cool":true, "smart":true, "ugly":false}
---
map[string]bool{}
```
#### 属性和基本操作
同指针类型和切片类型，字典类型是一个引用类型。字典会持有一个针对某个底层数据结构值的引用，将一个字典值传递给一个会改变它的函数，这个改变对于函数的调用方是可见的。  

>在Go语言中只有“传值”没有“传引用”，函数内部对参数值的改变是否会在该函数之外体现出来，只取决于这个被改变的值的类型是值类型还是引用类型。  

字典的零值是nil，类似一个长度为零的字典，可对其进行读取操作，对其进行写操作引发运行时恐慌。为初始化的字典类型的变量的值为nil。  
用内建函数len获取字典值的长度，代表当前所包含的键值对的数量。

```code
editorSign := map[string]bool{"cool":true, "smart":true, "stupid":false}
editorSign["ugly"] = false
/*新增*/
---
sign1 := editorSign["smart"]
sign1,ok := editorSign["smart"]
/*查找获取，消除不存在歧义*/
---
delete(editorSign,"stupid")
/*删除键为"stupid"的键值对，无返回结果，即使不存在要删的键值对也不引起恐慌*/
```
>字典类型不是并发安全的，官方认为在大多数使用字典值的地方并不需要多线程场景下的安全访问控制，为了少数的并发使用场景而强制要求所有的字典都满足互斥操作将会降低大多数程序的速度。  

>对一个非并发安全的字典值进行不受控制的并发访问可能会导致程序行为错乱，可以使用标准库代码包sync中的结构体类型RWMutex扩展字典类来保证并发安全性。RWMutex是一个读写互斥量，常用于多线程环境下的并发读写控制。
### 函数和方法

函数类型是一等类型，可以把函数当作一个值来传递和使用，即可以作为其他函数的参数，也可以作为其他函数的结果，可以利用函数的和则以特性生成闭包。
#### 类型表示法

函数类型指代了所有可以接受若干参数并能够返回若干结果的函数。  
声明一个函数以关键字func作为开始，其后紧跟函数签名，包括参数声明列表和结果声明列表。参数声明一般参数名在前，参数类型在后，中间空格分隔，参数名称唯一。若相邻两个参数的类型一致，可以只写第二个参数的参数类型。可以在函数声明的参数列表中略去所有参数的名称。可添加可变长参数。

```code
(name string, age int)
---
(name string, age, seniority int)
---
(string,int,int)
---
(name string,age int,seniority int,informations ...string)
```
结果声明列表的编写规则与参数声明基本一致，区别于：  

*  只存在可变长参数的声明不存在可变长结果的声明。
* 如果结果声明列表中只有一个结果声明且这个结果声明中并不包含结果的名称，则可以忽略圆括号。


```code
func (name string, age int, seniority int, informations ...string)bool
->
func (name string, age int, seniority int, informations ...string)(done bool)
/*命名结果*/
```
Go语言的函数可以有多个结果，为函数声明多个结果可以让每个结果的职责更单一。可以利用此特性将错误值作为结果返回给调用它的代码，而不是把错误抛出来，然后在调用它的地方编写代码处理这个错误。

```code
func (name string, age int , seniority int)(effected uint, err error)
```
#### 值表示法

函数类型的零值是nil，未被初始化的函数类型的变量的值为nil，在一个未被初始化的函数类型的变量上调用表达式会引发一个运行时的恐慌。  
函数类型的值分为命名函数值和匿名函数值。  
命名函数由关键字func、函数名、函数的签名和函数体组成。若签名中包含了结果声明列表，则在函数体中的任何可到达的流程分支的最后一条语句都必须是终止语句。终止语句有多种，return或goto开始的语句，针对内建函数panic的调用表达式的语句。

```code
func Module(x, y int) int{
    return x % y
}
---
func Module(x, y int) (result int){
    return x % y
}
---
func Module(x, y int) (result int){
    result =  x % y
    return
}
```
在关键字return之后的结果必须在数量上与该函数的结果声明列表中的内容完全一致，对应位置的结果的类型上存在可赋予的关系。

>函数的声明可以省略掉函数体，表示会由外部程序（如汇编语言程序）实现，而不会由Go语言程序实现。

匿名函数由函数字面量表示，函数没有名字。

```code
func (x, y int) (result int){
    result =  x % y
    return
}
```

#### 属性和基本操作
函数类型是Go语言的基本类型，可以把函数类型作为一个变量的类型。

```code
var recoder func (name string, age int, seniority int) (done bool)
```
之后所有符合这个函数的实现都可以被赋给变量recoder。

```code
recoder = func(name string, age int, seniority int) (done bool){
    //tudo
    return
}
```
被赋给变量recoder的函数字面量必须与recoder的类型拥有相同的函数签名。像“面向接口编程”原则的一种实现方式。可以在一个函数类型的变量上直接应用调用表达式来调用它。

```codewuhua
done := recoder("Harry", 32, 10)
```
可以把函数类型的变量的值看作是一个函数值，所有的函数值都可以被调用，函数字面量也是。

```codewuhua
func(name tsring, age int, seniority)(done bool){
    //todo
    return
}("HuaGe", 32, 10)
```
一个函数即可以作为其他函数的参数，也可以作为其他函数的结果。

```code
//声明加密算法函数类型
type Encipher func(plaintext string) []byte

//声明生成加密函数的函数
func GenEncryptionFunc(encrypt Encipher) func(string) (ciphertest string){
    return func(plaintext string) string{
        return fmt.Sprintf("%x",encrypt(plaintext))
    }
}
/*
实现了闭包
*/
```
函数GenEncryptionFunc的签名中包含一个参数声明和一个结果声明。参数声明“(encrypt Encipher)”中的参数类型是定义的用于封装加密算法的函数类型,结果声明“func(string)(ciphertext string)”表示了一个函数类型的结果，这个函数类型则是GetEncryptionFunc函数所生成的加密函数的类型，接收一个string类型的明文作为参数，并返回一个string类型的密文作为结果。  
函数GenEncryptionFunc的函数体内直接返回了符合加密函数类型的匿名函数，匿名函数调用名称未encrypt的函数，把作为该匿名函数的参数的明文加密，然后使用标准代码库代码包fmt中的Sprintf函数，把encrypt的函数的调用结果转换成字符串。字符串内容是十六进制数表示的加密结果，是[]byte类型的。

>每一次调用GenEncryptionFunc函数，传递给它的加密算法函数都会一直被对应的加密函数引用着。只要生成的加密函数还可以被访问，其中的加密算法函数就会一直存在，不会被Go语言的垃圾回收期回收。

只有当函数类型是一等类型并且其值可以作为其他函数的参数或结果的时候，才能够实现闭包。  

#### 方法

方法是附属于某个自定义的数据类型的函数，一个方法就是一个于某个接收者关联的函数。  
方法的签名中不但包含了函数签名，还包含了一个与接收者有关的声明，即方法的声明包含了关键字func、接收者声明、方法名称、参数声明列表、结果声明列表和方法体。接收者由被圆括号括起来的两个标识符组成，标识符间空格分隔，左边标识符为接收者的值在当前方法中的名称，右边标识符代表接收者的类型，前者称为接收者标识符。

```wuhua
type MyIntSlice []int
func (self MyIntSlice) Max() (result) {
    //todo
    return
}
```
接收者声明编写规则

* 接收者声明中的类型必须是某个自定义的数据类型，或者是一个与某个自定义数据类型对应的指针类型。接收者的类型既不能是一个指针类型，也不能是一个接口类型。
* 接受者声明中的类型必须由非限定标识符代表。
* 接收者标识符不能是空标识符“_”。
* 接收者的值未在当前方法体内被引用，可以将接收者标识符从当前方法的接受者声明中删除掉。（同参数声明不推荐

方法的类型与从其声明中去掉函数接收者之后的函数的类型相似，把接收者声明中的两个标识符加到参数列表声明的首位。

```bighua
func (self *MyIntSlice) Min() (result int)
//类型为
func Min()(self *MyIntSlice, result int)
```
选择接收者的类型  
 
 * 在某个自定义数据类型上，值能够调用与这个数据类型相关联的值方法，在这个值的指针值上，能够调用与其数据类型相关联的值方法和指针方法。
 * 在指针方法中能够改变接收者的值，在值的方法中，对接收者的值的改变对于该方法之一般是无效的。  

接收者的类型如果是引用类型的别名类型，在该类型值的值方法中对该值的改变也是对外有效的。

### 接口
 Go语言的接口由一个方法的集合代表。只要一个数据类型（或与其对应的指针类型）附带的方法集合是某一个接口的方法集合的超级，就可以判定该类型实现了这个接口。

#### 类型表示法
接口由方法集合代表。
```bighua
 //标准库代码包sort中的接口类型Interface
 type Interface interface {
    Len() int
    Less(i, j int) bool
    Swap(i, j int)
 }
 ```

将一个接口类型嵌入到另一个接口类型中，亦接口间的继承。

```code
type Sortable interface {
    sort.Interface
    Sort()
}
//嵌入了sort中的接口类型Interface
```

>接口的嵌入不能嵌入自身，包括直接的嵌入和间接的嵌入，当前接口类型中声明的方法也不能与任何被嵌入其中的接口类型的方法重名，错误的嵌入会造成编译错误。

interface{}为空接口，不包含任何方法声明的接口，Go语言中所有数据类ixng都是它的实现。
#### 值表示法

Go语言的接口没有相应的值表示法，接口是规范而不是实现。一个接口类型的变量可以被赋予任何实现了这个接口类型的数据类型的值，因此接口类型的值可以由任何其它数据类型的值来表示。
#### 属性和基本操作

接口的实现。

```code
type SortableStrings [3]string

func (self SortableStrings) Len() int {
    return Len(self)
}

func (self SortableStrings) Less(i, j int) bool {
    return self[i] < self[j]
}

func (self SortableStrings) Swap(i, j int) {
    self[i],self[j] = self[j],self[i]
}

_,ok := interface{}(SortableStrings{}).(sort.Interface)
//类型断言SorableStrings类型是一个sort.Interface接口类型的实现。

func (self SortableStrings) Sort(){
    sort.Sort(self)
}
_,ok := interface{}(SortableStrings{}).(Sortable)
//断言SorableStrings类型实现了接口类型Sortable。

func (self *SortableStrings) Sort(){
    sort.Sort(self)
}
_,ok := interface{}(&SortableStrings{}).(Sortable)
//验证方法接收对象规则值方法和指针方法
```

### 结构体

结构体类型既可以包含若干个命名元素（字段），又可以与若干个方法相关联。字段代表了该类型的属性，方法可以看作是针对这些属性的操作。

#### 类的表示法

```code
type Sequence struct {
    len int
    cap int
    Sortable        // 匿名字段
    sortableArray sort.Interface
}
```
可以把类型相同的字段写在同一行中(不建议):

```code
len, cap int
```
只有类型而没有指定名称的字段叫做匿名字段，也称嵌入式的字段（结构体类型的嵌入类型），必须由一个数据类型的名称或者一个与非接口类型对应的指针类型类型的名称代表，代表匿名字段类型的非限定名称被隐含地作为该字段的名称。

```code
type Anonymities struct {
    T1      //隐含名称T1
    *T2     //隐含名称T2
    P.T3    //隐含名称T3
    *P.T4   //隐含名称T4
}
```
结构体自动地实现它包含的所有嵌入类型所实现的接口类型。

```code
type Sequence struct {
    Sortable
    sorted bool
}
```

当Sequence类型中由与Sortable接口类型的Sort方法的名称和签名都相同的方法时，调用seq.Sort()是调用Sequence自身的Sort方法，嵌入类型Sortable的方法Sort被隐藏了。类似装饰器模式。若名称相同签名不同，Sortable的Sort方法依然被隐藏。此时调用Sequence自身的Sort方法需要依据Sort的签名来编写调用。

```code 
func (self *Sequence) Sort (quicksort bool){
    //todo
}
seq.Sort(true) //调用自身
seq.Sortable.Sort() //调用嵌入类型Sortable的Sort
```
假设有结构体类型S和非指针类型的数据类型T，则：  

* S中包含一个嵌入类型T，S和\*S的方法集合中都包含接收者类型为T的方法。\*S的方法集合中还包含接收者类型为\*T的方法。
* S中包含了一个嵌入类型\*T，S和\*S的方法集合中都会包含接收者类型T或\*T的所有方法。

对于结构体的多层嵌入：  

* 在被嵌入的结构体类型的值上像调用它自己的字段或方法那样调用任意深度的嵌入类型值的字段或方法。前提是这些嵌入类型的字段或者方法没有被隐藏，被隐藏则需要通过链式的选择表达式调用或者访问。
* 被嵌入的结构体类型的字段或者方法可以隐藏任意深度的嵌入类型的同名字段或方法。字段可以隐藏方法，方法可以隐藏字段，名称相同即可。

匿名结构体类型比命名结构体类型少了关键字type和类型名称：

```code
struct {
    Sortable
    sorted bool
}
```
可以在数组类型、切片类型活字典类型的声明中，将一个匿名的结构体类型作为它们的元素的类型。可以直接将匿名结构体作为一个变量的类型:

```code
var anonym struct {
    a int
    b string
}
```
更常用的是在声明以匿名结构体类型为类型的变量的同时对其初始化:

```code
anonym := struct {
    a int 
    b string
}{0, "wuhua"}
```

匿名结构体类型不具有通用性，常常用在临时数据存储和传递的场景中。可以在结构体类型声明中的字段声明的后面添加一个字符串字面量标签，以作为对应字段的附加属性：

```code
type Persion struct {
    Name    string `json:"name"`
    Age     uint   `json:"age" `
    Address string `json:"addr"`
}
```

通常该标签对该结构体类型及其值的代码来说是不可见的，可以使用标准库代码包reflect中提供的函数查看到结构体类型中字段的标签。会在一些特殊的应用场景下使用，如标签库代码包encoding/json中的函数会根据这种标签的内容确定与该结构体中的字段对应的JSON节点的名称。

#### 值表示法

一般由复合字面量表达。  
对Sequence有：

```code
Sequence{Sortable:SortableStrings{"3","2","1"},sorted:false }
```

可以忽略掉结构体字面量字段的名字，即不添加架构体字面量中的键值对的键。有限制：  

* 要省略都省略。
* 字段值之间的顺序与结构体类型声明中的字段声明的顺序一致，不能省略对任何一字段的赋值。

可以在结构体字面量中不指定任何字段的值:

```code
Sequence{}
```

此时此值中的两个字段被赋予他们所属类型的零值。结构体类型属于值类型，零值为不为任何字段赋值的结构体字面量。  
在字段访问权限允许下访问操作字段，字段名称首字母小写，只能在结构体类型声明所属的代码包中访问到该类型的值中的字段，或对其赋值。

#### 属性和基本操作

结构体类型的属性既其所包含的字段和关联的方法。  
只存在内嵌不存在继承的概念。  
在结构体类型的别名类型的值上，既不能调用该结构体类型的方法，也不能调用该结构体类型对应的指针类型的方法。

>通过结构体中嵌入接口，嵌入的接口能够存储所有实现了该接口类型的数据类型的值，该结构体可以在一定程度上模拟泛型。

很多预定义类型都属于泛型类型（数组、切片、字典、通道），不支持自定义的泛型。

```code
type GenericSeq interface {
    Sortable
    Append(e interface{}) bool
    Set(index int,e interface{}) bool
    Delete(index int)(interface{},bool)
    ElemValue(index int)interface {}
    ElemType() reflect.Type
    Value() interface{}
}

type Sequence struct {
    GenericSeq
    sorted bool
    elemType reflect.Type
}

func (self *Sequence) Sort(){
    self.GenericSeq.Sort()
    self.sorted = true
}

func (self *Sequence) Append(e interface{}) bool {
    result := self.GenericSeq.Append(e)
    //todo
    self.sorted = false
    //todo
    return result
}

func (self *Sequence) Set(index int, e interface{}) bool {
    result := self.GenericSeq.Set(index,e)
    //todo
    self.sorted = false
    //todo
    return result
}

func (self *Sequence) ElemType() reflect.Type{
    //todo
    self.elemType = self.GenericSeq.ElemType()
    //todo
    return self.elemType
}
```
接口类型GenericSeq中声明了用于添加、修改、删除、查询元素和获取元素类型的方法。实现GenericSeq接口类型，也必须实现Sortable接口类型。将嵌入到Sequence类型的Sortable接口类型改为GenericSeq接口类型，在类型声明中添加reflect.Type类型（标准库代码包reflect中的Type类型）的字段elemType，用于缓存GenericSeq字段中存储的值的元素类型。  
通过创建与Sequence类型关联的方法，方法与接口GenericSeq或Sortable中声明的某个方法有着相同的方法名和方法签名，隐藏了GenericSeq字段中存储的值的同名方法，达到扩展效果。  
结构体类型在多数场景中比预定义数据类型的别名类型更适合作为接口类型的实现，是Go语言支持面向对象编程的主要体现。

### 指针
代表着某个内存地址的值。是复合类型之一。

#### 类型表示法
通过于有效数据类型的左边插入符号“*”获取与之对应的指针类型。

```code
*[]int
*Sequence
*sort.StringSlice
```
专门用于存储内存地址的类型uintptr，与int和uint一样属于数值类型。其值能够保存一个指针值的32位或64位（与程序运行的计算机架构有关）无符号整数，亦称其值为指针类型值的位模式。

#### 值表示法
若变量可寻址，使用取址操作符“&”取对应指针值。
#### 属性和基本类型

指针类型属于引用类型，零值为nil。  
标准库代码包unsafe提供不安全的操作绕过Go语言类型安全机制。  
包中有个int类型的别名类型ArbitraryType，可以代表任意的Go语言表达式的结果类型。包中声明了一个名为Pointer的类型，unsafe.Pointer类型代表了ArbitarayType类型的指针类型。有特殊转换操作：  

* 指向其他类型值的指针值可以被转换为unsafe.Pointer类型值。

```code
pointer := unsafe.Pointer(float32(32))
```

* unsafe.Pointer类型值可以被转换为对应的指针类型的值。对于内存上的同一段数据，将其作为int类型的值和float32类型的值来解析得出的结果不同，某些情况，会引起一个运行时的恐慌。

```code
vptr := (*int)(pointer)
---
vptr := (*string)(pointer) //引发运行时恐慌
```

* unsafe.Pointer类型的值可以被转换为一个uintptr类型的值。

```code
uptr := uintptr(pointer)
```

* uintptr类型的值也可转换为unsafe.Pointer类型的值。

```code
pointer2 ：= unsafe.Poniter(uptr)
```

可通过unsafe.Pointer绕过类型系统在任意的内存地址上进行读写操作。

```code
type Person struct {
    Name    string `json:"name"`
    Age     uint8  `json:"age"`
    Address string `json:"addr"`
}
pp := &Person{"Bighau",23,"Henan,China"}
var puptr = uintptr(unsafe.Pointer(pp))
var npp uintptr = puptr + unsafe.Offsetof(pp.Name)
var name *string = (*string)(unsafe.Pointer(npp))
```

使用unsafe包中的Offsetof函数返回Name在Person中的存储偏移量，将Person的内存地址与Name的存储偏移量相加得Name的内存地址，可利用特殊转换操作的规则2和4还原指向Name字段值的指针类型值。最后通过*name直接获取Name字段的值。  

总结为：

```code
uintptr(unsafe.Pointer(&s)) + unsafe.Offsetof(s.f) == uintptr(unssafe.Pointer(&s.f))
```

### 数据初始化

指对某个数据类型的值或变量的初始化。专门用于数据初始化的内建函数new和make。

#### new

用于为值分配内存。不同于其他编程语言，此处不会初始化分配到的内存，只会清零。  
调用new(T)意味着为T类型的新值分配并清零一块内存空间，将这块内存空间的地址作为结果返回。结果即为指向这个新的T类型值的指针值，指向一个T类型的零值。

```code
s = new(string)     //s->""
[]int = new([3]int) //n ->[3]int{0,0,0} 
```
标准库代码包sync中的结构体内类型Mutex是一个new后即用的数据类型，零值为一个处于未锁定状态的互斥量。

#### make

只能被用于创建切片类型、字典类型和通道类型的值，并返回一个已经被初始化的（非零值）的对应类型的值。  在创建这三个引用类型的值的时候，将内存分配和数据初始化两个步骤绑定在一起。三个类型的零值都是nil，使用new得到的是一个指向空值nil的指针。  
除了接受一个表示目标类型的类型字面量，还接受一个或两个额外的参数。

```code
make([]int, 10, 100)
make([]int, 10)

=>[]int{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
//创建一个新的[]int类型的值，长度为10、容量为100，可省略参数3，此时为不指定新值的容量。
---
make(map[string]int, 100)
make(map[string]int)

=>map[string]int{}
//可忽略用于表示底层数据结构长度的参数，不建议
---
make(chan int, 10)
//参数一通道类型，参数二通道长度，参数二可省略
```

make函数只能被应用在引用类型的值的创建上，其结果是第一个参数所代表的类型的值，而不是指向这个值的指针值。在调用make函数的表达式的求值结果上使用“&”取址操作符获取指针值。

```code
m := make(map[string]int, 100)
mp := &m
```

规则总结：  

* 字面量可以被用于初始化除接口类型和通道类型外的所有数据类型的值，接口类型没有值，通道类型只能使用make函数创建。  
* 内建函数new主要被用于创建值类型的值，不适合用来创建引用类型的值，其结果是指向被创建值的指针值。  
* 内建函数make仅能被用于切片、字典和通道类型的值的创建，结果值是被创建的值本身。
