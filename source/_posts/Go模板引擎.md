---
title: Go模板引擎
tags: [Go模板库,模板引擎]
comments: true
categories: [Golang]
date: 2018-08-24 21:01:29
---
Go标准库text/template、html/template。

---

### 模板引擎
可以把模板引擎划分为两种理想的类型：

* 无逻辑模板引擎（logic-less template engine）——将模板中指定的占位符替换成相应的动态数据。只进行字符串替换，不执行任何逻辑处理。目的是完全分离程序的表现和逻辑，并将所有计算方面的工作都交给处理器完成。
* 嵌入逻辑的模板引擎（embedded logic template engine）——将编程语言代码嵌入模板当中，并在模板引擎渲染时，由模板引擎执行这些代码并进行相应的字符串替换工作。

无逻辑模板引擎的渲染速度往往会更快一些。

### Go的模板引擎
Go语言的模板引擎介于无逻辑模板引擎和嵌入逻辑模板引擎之间，由处理器负责触发。

Go的通用模板引擎库text/template可以处理任意格式的文本，模板引擎库html/template专门处理HTML格式。模板中的动作默认使用两个大括号`{`和`}`包围，也可以通过模板引擎提供的方法自行指定其他定界符（delimiter）。

使用Go的Web模板引擎需要的步骤：

* 对文本格式的模板源进行语法分析，创建一个经过语法分析的模板结构，模板源既可以是一个字符串，也可以是模板文件中包含的内容。
* 执行经过语法分析的模板，将ResponseWriter和模板所需的动态数据传递给模板引擎，被调用的模板引擎会把经过语法分析的模板和传入的数据结合起来，生成最终的HTML传递给ResponseWriter。
```
···
func process(w http.ResponseWriter, r *http.Request) {
	t, _ := template.ParseFiles("tmpl.html)
	t.Execute(w, "Hello World!)
}
···
```
#### 对模板进行语法分析
ParseFiles是一个独立的函数，可以对模板文件进行语法分析，并创建出一个经过语法分析的模板结构以供Execute方法执行。

>调用ParseFiles函数的时候，Go会创建出一个新的模板，并将用户给定的模板文件的名字用作这个新模板的名字。

```
t, _ := template.ParseFiles("tmpl.html)
```
相当于

```
t := template.New("tmpl.html")
t, _ := t.ParseFiles("tmpl.html")
```
ParseFiles函数和Template结构的ParseFiles方法都可以接受一个或多个文件名作为参数，但只返回一个模板。返回用户传入的第一个文件的已分析模板，模板也会根据用户传入的第一个文件的名字进行命名，其他传入文件的已分析模板会被放置到一个映射里面，可以在之后执行模板时使用。

>即，向ParseFiles传入单个文件时，ParseFiles返回的是一个模板，向ParseFiles传入多个文件时，ParseFiles返回的是一个模板集合。

使用ParseGlob函数对模板文件进行语法分析，会对匹配给定模式的所有文件进行语法分析。

实际上，所有对模板进行语法分析的手段最终都需要调用Parse方法来执行实际的语法分析操作。

专门用于处理分析模板时出现的错误：

```
t := template.Must(template.ParseFiles("tmpl.html"))
```
Must函数可以包裹起一个函数，被包裹的函数会返回一个指向模板的指针和一个错误，若错误不是nil，Must函数将产生一个panic。

#### 执行模板
常用方法调用模板的Execute方法，并向它传递ResponseWriter以及模板所需的数据。若对模板集合调用Execute方法，只会执行模板集合中的第一个模板。使用ExecuteTemplate方法执行其他模板。

```
···
t, _ := template.ParseFiles("t1.html", "t2.html")

t.Execute(w, "hello world!")

t.ExecuteTemplate(w, "t2.html", "Hello World!")
···
```
### 动作
动作即嵌入在模板里面的命令，使用两个大括号{和}进行包围。

主要有动作：

* 条件动作；
* 迭代动作；
* 设置动作；
* 包含动作。

还有`定义动作`，（ . ）也是一个动作，代表的是传递给模板的数据，其他动作和函数基本上都会对这个动作进行处理，达到格式化和内容展示的目的。

#### 条件动作
根据参数的值决定对多条语句中的哪一条语句进行求值。

```
{{ if arg }}

some content
{{ end }}
```
又或

```
···
{{ if arg }}
some content
{{ else }}
other content
{{ end }}
···
```
#### 迭代动作
迭代动作可以对数组、切片、映射或者通道进行迭代，在迭代循环的内部点(.)会被设置为当前被迭代的元素。

```
···
{{ range array }}
Dot is set to the element {{ . }}
{{ end }}
···
```
又或

```
···
{{ range . }}
{{ . }}
{{ else }}
other content to show
{{ end }}
···
```
#### 设置动作
允许用户在指定的范围之内为点`(.)`设置值。

```
···
{{ with arg }}
{{ . }}the dot is already set to arg
{{ end }}
···
```
又或

```
···
{{ with arg }}
{{ . }}Dot is set to arg
{{ else }}
Fallback if arg is empty
{{ end }}
···
```
#### 包含动作
允需用户在一个模板里面包含另一个模板，从而构建出嵌套的模板。包含动作的格式为：

```
{{ template "name" }}
```
name参数为被包含模板的名字。

### 参数、变量和管道
参数即模板中的值，可以是布尔值、整数、字符串等字面量，也可以是结构、结构中的一个字段或者数组中的一个键。还可以是一个变量、一个方法（该方法必须只返回一个值、或只返回一个值和一个错误）或者一个函数。参数也可以是一个点(.)，用于表示处理器向模板引擎传递的数据。

除参数外，可在工作中设置以美元符号开头的变量。

```
···
{{ range $key, $value := . }}
The key is {{ $key }} and the value is {{ $value }}
{{ end }}
···
```
又或者使用管道

```
···
{{ 12.3456 | printf "%.2f" }}
···
```
### 函数
Go的模板引擎函数都是受限制的：函数可以接受任意多个参数作为输入，但是只能返回一个值，或者返回一个值和一个错误。

创建自定义模板函数：

* 创建一个名为FuncMap的映射，将映射的键设置为函数的名字，映射的值设置为实际定义的函数；
* 将FuncMap与模板进行绑定。

```
···
func formatDate(t time.Time) string {
	layout := "2006-01-02"
	return t.Format(layout)
}

func process(w http.ResponseWriter, r *http.Request) {
	funcMap := template.FuncMap{ "fdate": formatDate }
	t := template.New("tmpl.html").Funcs(funcMap)
	t, _ = t.ParseFiles("tmpl.html)
	t.Execute(w, time.Now())
}
···
```
模板中使用

```
<div>The Date/Time is {{ . | fdate }}</div>
```
又或者

```
<div>the Date/Time is {{ fdate . }}</div>
```
使用管道将一个函数的输出传递给另一个函数作为输入，使代码更简单易读。

### 上下文感知
Go的模板引擎可以根据内容所处的上下文改变其显示的内容。根据内容在模板中所处的位置，模板在显示这些内容的时候将对其进行相应的修改。可对被显示的内容实施正确的转义（escape）：模板现实的是HTML格式的内容，模板对其实施HTML转义；显示的是JavaScript格式的内容，对其实施JavaScript转义。还可以识别出内容中的URl或者CSS样式。

主要用于实现自动的防御编程，防止某些明显并且低级的编程错误。

### 防御XSS攻击
由于服务器将攻击者存储的数据原原本本地显示给其他用户所致。

通过模板引擎在显示用户输入时将其转换为转义之后的HTML，避免可能会出现的问题。

### 不对HTML进行转义
使用“不转义代码机制”允许用户输入HTML代码或者JavaScript代码，并在显示内容时执行这些代码。

将不想被转义的内容传给template.HTML函数。

```
···
func process(w http.ResponseWriter, r *http.Request) {
	t, _ := template.ParseFiles("tmpl.html)
	t.Execute(w, template.HTML(r.FormValue("comment)))
}
···
```
程序通过类型转换（typecast）将表单中的评价值转换成template.HTML类型。

>可通过发送一个最初由微软公司为IE浏览器创建的特殊HTTP响应首部X-XSS-Protection让浏览器关闭内置的XSS防御功能。

```
func process (w http.ResponseWriter, r *http.Request) {
	w.Header().Set("X-XSS-Protection", "0")
	t, _ := template.ParseFiles("tmpl.html")
	t.Execute(w, template.HTML(r.FormValue("content)))
}
```
### 嵌套模版
布局指Web设计中可以重复应用在多个页面上的固定模式。

通过包含动作，在一个模版里面包含另一个模版：

```
···
{{ template "name" . }}
···
```
动作参数name为被包含的模板名字，是一个字符串常量。每个页面都拥有它们各自的布局模版文件，程序最终无法拥有任何可共用的公共布局。

可通过定义动作（define action），在模板文件里面显示地定义模板。

```
{{ define "layout" }}
 <html>
 ···
 {{ template "content" }}
 ···
 </html>
{{ end }}
```
在一个模板文件里定义多个不同模板:

```
{{ define "layout" }}
 <html>
 ···
 {{ template "content" }}
 ···
 </html>
{{ end }}
{{ define "content }}
Hello World!
{{ end }}
```
使用显示定义模板：

```
···
func process(w, http.ResponseWriter, r *http.Request) {
	t, _ := template.ParseFiles("layout.html")
	t.ExecuteTemplate(w, "layout", "")
}
···
```
可在不同的模板文件里面定义同名的模板（red_hello.html，blue_hello.html）：

```
···
{{ define "content" }}
<h1 style= "color: red;">Hello World!</h1>
{{ end }}
···
```
和

```
···
{{ define "content }}
<h1 style="color: blue;"> hello World!</h1>
{{ end }}
···
```
使用在不同模板文件中定义的同名模板：

```
···
func process(w http.ResponseWriter, r *http.Request) {
	rand.Seed(time.Now().Unix())
	var t *template.Template
	if rand.Intn(10) > 5 {
		t, _ := template.ParseFiles("layout.html", "red_hello.html")
	} else {
		t, _ := template.ParseFiles("layput.html", "blue_hello.html")
	}
	t.Execute(w, "layout", "")
}
···
```
通过块动作定义默认模板
块动作（block action）允许用户定义一个模板并且立即使用。

```
{{ block arg }}
Dot is set to arg
{{ end }}
```
改进上方逻辑，默认展示蓝色else只对layout.html进行语法分析

```
···
func process(w http.ResponseWriter, r *http.Request) {
	rand.Seed(time.Now().Unix())
	var t *tempale.Template
	if rand.Intn(10) > 5 {
		t, _ := template.ParseFiles("layout.html", "red)
	} else {
		t, _ := template.ParseFiles("layout.html")
	}
	t.ExecuteTemplate(w, "layout", "")
}
···
```
### 通过块动作添加默认的content模版

```
···
{{ define "layout" }}
<html>
···
{{ block "content" . }}
<h1 style="color: blue;">Hello World!</h1>
{{ end }}
···
</html>
{{ end }}
···
```
块动作定义的content模板，当layout模板被执行时，若模板引擎没找到可用的content模板，就会使用块动作中定义的content模板。

