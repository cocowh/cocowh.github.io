---
title: web服务
tags: [web服务,SOAP,REST]
comments: true
categories: [web杂记]
date: 2018-10-12 14:41:00
---
### web服务
>一种与其他软件进行交互的软件程序，通过HTTP进行通信。是一个软件系统，为网络上进行的可互操作机器间交互提供支持。每个web服务都拥有一套自己的接口，由一种名为Web服务描述语言的机器可处理格式描述。其他系统需要根据Web服务的描述，适用SOAP消息与Web服务交互。SOAP消息常被序列化为XML并通过HTTP传输。

存在着多种不同类型的Web服务，其中包括基于SOAP的、基于REST的以及基于XML-RPC的，基于REST的和基于SOAP的Web服务最为流行。企业级系统大多数都是基于SOAP的Web服务实现，公开可访问的Web服务更青睐基于REST的Web服务。

基于SOAP的Web服务由功能驱动，基于REST的Web服务由数据驱动。基于SOAP的Web服务往往是RPC风格；基于REST的Web服务关注的是资源，HTTP方法是对这些资源执行操作的动词。

### 基于SOAP的Web服务
SOAP（Simple Object Access Protocol：简单对象访问协议）是一种协议，用于交换定义在XML里面的结构化数据。能够跨越不同的网络协议并在不同的编程模式中使用，其处理的并不是对象，已经不再代表Simple Object Access Protocol。

SOAP高度结构化，需要严格地进行定义，用于传输数据的XML可能会变的非常复杂。WSDL是客户端与服务器之间的契约，定义了服务提供的功能以及提供这些功能的方式，服务的每个操作以及输入/输出都需要由WSDL明确地定义。

SOAP将报文内容放入到信封里面，信封相当于一个运输容器，并且它还能够独立于实际的数据传输方式存在。

经过简化的SOAP请求报文示例：

```
POST /GetComment HTTP/1.1
Host: www.chitchatcom
Content-Type: application/soap+xml; charset=utf-8

<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3.org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.chitchat.com/forum">
	<m:GetCommentRequest>
		<m:CommentId>123</m:CommentID>
	</m:GetCommentRequest>
</soap:Body>
</soap:Envelope>
```
简化后的SOAP响应报文示例：

```
HTTP/1.1 200 OK
Content-Type: application/soap+xml; charset=utf-8

<?xml version="1.0"?>
<soap:Envelope
xmlns:soap="http://www.w3/org/2001/12/soap-envelope"
soap:encodingStyle="http://www.w3.org/2001/12/soap-encoding">
<soap:Body xmlns:m="http://www.example.org/stock">
	<m:GetCommentResponse>
		<m:Text>Hello World!</m:Text>
	</m:GetCommentResponse>
</soap:Body>
</soap:envelope>
```

SOAP 1.2允许通过HTTP的Get方法发送SOAP报文，但大多数基于SOAP的Web服务都是通过HTTP的POST方法发送SOAP报文的。

一个基于SOAP的Web服务越复杂，对应的WSDL报文就越冗长。实际中SOAP请求报文通常会由WSDL生成的SOAP客户端负责生成，SOAP响应报文通常也是由WSDL生成的SOAP服务器负责生成。

### 基于REST的Web服务
REST（Representational State transfer，具象状态传输）是一种设计理念，用于设计通过标准的几个动作来操纵资源，并以此来进行互相交流的程序（将操纵资源的动作称为“动词”，即verb）。

REST并不把函数暴露为可调用的服务，而是以资源（resource）的名义把模型暴露出来，允许通过少数几个称为动词的动作来操纵这些资源。

使用HTTP协议实现REST服务，URL将用于表示资源，HTTP方法则会用作操纵资源的动词。如表所示：

HTTP方法 | 作用 | 使用实例
:- | :- | :-
POST | 在一项资源尚未存在的情况下创建该资源 | POST /users
GET | 获取一项资源 | GET /users/1
PUT | 重新给定URL上的资源 | PUT /users/1
DELETE | 删除一项资源 | DELETE /users/1

POST和PUT的区别在于，PUT需要准确地知道哪一项资源将会被替换，使用POST只会创建出一项新资源以及一个新的URL。POST用于创建一项全新的资源，PUT用于替换一项已经存在的资源。

REST不经只能通过这几个HTTP方法实现，如可以使用PATCH方法对一项资源进行部分更新。使用REST API的时候通常都是返回JSON，或者返回一些比SOAP报文要简单得多的XML，很少返回SOAP报文。

基于REST的Web服务也拥有相应的WADL（Web Applicaton Description Language，Web应用描述语言），可以对基于REST的Web服务进行描述，能够生成访问这些服务的客户端。

REST设计理念适用于只执行简单的CURD操作的应用，适用于更为复杂的服务可以通过如下两个方法对过程或者动作进行建模。

#### 将动作转化为资源

```
POST /user/123/activation HTTP/1.1

{ "data":"2018-10-13T17:12:12Z" }
```
将创建一个被激活的资源（activation resource），表示用户的激活状态，可以为激活的资源添加额外的属性。

#### 将动作转换为资源的属性

```
PATCH /user/123 HTTP/1.1

{ "active": "true"}
```
把用户的active属性设置为true

