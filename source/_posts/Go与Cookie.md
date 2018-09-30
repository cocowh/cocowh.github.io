---
title: Go与Cookie
tags: [Golang,cookie]
comments: true
categories: [Golang]
date: 2018-08-23 20:57:26
---
大多数cookie都可以被划分为会话cookie和持久cookie两种类型。

---
### Go与cookie
cookie在Go语言中用Cookie结构表示。

```
type Cookie struct {
	Name		string
	Value		string
	Path		string
	Domain		string
	Expires		time.Time
	RawExpires	string
	MaxAge		int
	Secure		bool
	HttpOnly	bool
	Raw			string
	Unparsed	[]string
}
```
没有设置Expires字段的cookie通常称为会话cookie或者临时cookie，这种cookie在浏览器关闭的时候就会自动被移除。设置了Expires字段的cookie通常称为持久cookie，这种cookie会一直存在，直到指定的过期时间来临或者被手动删除为止。

Expires字段和MaxAge字段都可以设置cookie的过期时间，Expires字段用于明确地指定cookie应该在什么时候过期，MaxAge字段指明cookie在被浏览器创建出来之后能够存活多少秒。

为使cookie在所有浏览器上都能够正常运行，只使用Expires，或者同时使用Expires和MaxAge。
### 将cookie发送至浏览器
Cookie结构的String方法可以返回一个经过序列化处理的cookie，其中Set-Cookie响应首部的值即为这些序列化之后的cookie组成。

```
···
func setCookie(w http.ReponseWriter, r *http.Request) {
	c1 := http.Cookie{
		Name:	"first_cookie",
		Value:	"Wuhua",
		HttpOnly:	true,
	}
	c2 := {
		Name: "second_cookie",
		Value:	"Love or hate",
		HttpOnly: true,
	}
	w.Header().Set("Set-Cookie", c1.String())
	w.Header().Add("Set-Cookie", c2.String())
}
···
```
除Set方法和Add方法外，还可使用net/http库中的SetCookie方法。

```
···
func setCookie(w http.ReponseWriter, r *http.Request) {
	c1 := http.Cookie{
		Name:	"first_cookie",
		Value:	"Wuhua",
		HttpOnly:	true,
	}
	c2 := {
		Name: "second_cookie",
		Value:	"Love or hate",
		HttpOnly: true,
	}
	http.SetCookie(w, &c1)
	http.SetCookie(w, &c2)
}
···
```
使用SetCookie方法设置cookie，传递给方法的是指向Cookie的指针而不是Cookie结构本身。

### 从浏览器获取cookie
```
···
func getCookie(w http.ReponseWriter, r *http.Request) {
	h := r.Header['Cookie']
	fmt.Fprintln(w, h)
}
···
```
语句`r.Header["Cookie"]`返回一个切片，切片包含一个字符串，字符串包含了客户端发送的任意多个cookie。取得单独的键值对格式的cookie，需要对r.Header[“Cookie”]返回的字符串进行语法分析。

```
···
func getCookie(w http.ReponseWriter, r *http.Request) {
	c1, err := r.Cookie("first_cookie");
	if err != nil {
		fmt.Fprintln(w, "Cannot get the first cookie")
	}
	cs := r.Cookies()
	fmt.Fprintln(w, c1)
	fmt.Fprintln(w, cs)
}
···
```
使用Request结构的Cookie方法获取指定名字的cookie，若指定的cookie不存在，则方法返回一个错误。使用Cookies方法获取多个cookie，返回一个包含了所有cookie的切片。

上方未设置cookie的过期时间，为会话cookie，完全退出浏览器并重启这些cookie会消失。

### 使用cookie实现闪现消息
实现闪现消息的常用方法是将这些消息存储在页面刷新时就会被移除的会话cookie里面。

```
···
func setMessage(w http.ResponseWriter, r *http.Request) {
	msg := []byte("Hello World!)
	c := http.Cookie{
		Name:	"flash",
		Value:	base64.URLEncoding.EncodeToString(msg),
	}
	http.SetCookie(w, &c)
}
···
```
设置cookie时，如果cookie的值没有包含诸如空格或者百分号这样的特设字符，可不对它进行编码；由于消息本身通常包含此类字符，需要使用Base64URL编码，以此来满足响应首部对cookie值的URL编码要求。

```
···
func showMessage(w http.ReponseWriter, r *http.Request) {
	c, err := r.Cookie("flash")
	if err != nil {
		if err == http.ErrNoCookie {
			fmt.Fprintln(w, "No message found)
		}
	} else {
		rc := http.Cookie{
			Name:	 "flash",
			MaxAge:	-1,
			Expires:	time.Unix(1, 0),
		}
		http.SetCookie(w, &rc)
		val, _ := base64.URLEncoding.DecodeString(c.Value)
		fmt.Fprintln(w, string(val))
	}
}
···
```
获取flash消息cookie，创建同名cookie并设置MacAge值为负数、Expires值为已经过去的时间，将同名cookie发送至客户端，相当于命令浏览器删除这个cookie。将flash消息解码，通过响应返回这条消息。

