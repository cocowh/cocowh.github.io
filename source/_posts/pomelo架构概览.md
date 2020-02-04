---
title: pomelo架构概览
tags: [note,pomelo]
comments: true
categories: [pomelo]
date: 2020-02-04 11:14:22
---
### 规范
摘录[风格与约定](https://github.com/NetEase/pomelo/wiki/%E9%A3%8E%E6%A0%BC%E4%B8%8E%E7%BA%A6%E5%AE%9A)。

Tips:  

* pomelo是一个框架，编写的代码是用来配置框架的，特别是要求我们自己定义一些框架所需的回调方法。
* 无论是component、handler、filter、module，remote等等，在导出的时候，往往都会导出一个工厂函数，而不是直接导出对象，这样能够进行上下文的注入，同时在加载时可以传入一些配置参数。
* 代码组织要遵循pomelo的规范，每一个服务器代码都分到名为handler和remote的两个目录下，它们分别描述了这个服务器接受客户端请求和接受rpc请求的服务端逻辑。

###  设计思路

摘录[pomelo架构概览](https://github.com/NetEase/pomelo/wiki/pomelo%E6%9E%B6%E6%9E%84%E6%A6%82%E8%A7%88)。

组织Tips：

* 客户端通过websocket长连接连到connector服务器群。
* connector负责承载连接，并把请求转发到后端的服务器群。
* 后端的服务器群主要包括按场景分区的场景服务器(area)、聊天服务器(chat)和状态服务器等(status)， 这些服务器负责各自的业务逻辑。真实的案例中还会有各种其它类型的服务器。
* 后端服务器处理完逻辑后把结果返回给connector， 再由connector广播回给客户端。
* master负责统一管理这些服务器，包括各服务器的启动、监控和关闭等功能。

> 思考：类似web架构，nginx转发http请求给相关服务处理，但是nginx可负载均衡拓展性强。connector服务器socket连接达到上限时，如何拓展。  
 
 
 设计Tips： 
 
 * 每个服务器进程专注于一块具体的服务功能，如：连接服务，场景服务，聊天服务等。这些服务器进程相互协作，对外提供完整的游戏服务。

#### 服务器类型

 * frontend：负责承载客户端的连接，维护session信息，把请求转发到后端，把后端需要广播的消息发到前端。
 * backend：处理业务逻辑，包括RPC和前端请求的逻辑；把消息推送回前端。

### 请求/响应流程
客户端可以向服务器发送两种类型的消息：request和notify。

* Request：上行和下行两个消息，服务器处理后会返回响应，pomelo框架维护请求和响应之间的对应关系。
* notify：单向，客户端通知服务器端的消息，服务器处理后无需向客户端返回响应。

请求到达服务器后，先到达客户端所连接的frontend服务器，后者会根据请求的类型和状态信息将请求分发给负责处理该请求的backend服务器。

请求的处理代码根据职责划分为两大部分：handler和filter。与游戏业务逻辑相关的代码放在handler中完成；业务逻辑之外的工作放在filter中。Filter可看成是请求流程的扩展点。

Filter按注册的顺序出现在请求的处理流程上。

* Before filter：负责前置处理。Before filter中调用next参数，流程会进入下一个filter。直到走完所有的before filter后，请求会进入到handler中。也可以通过向next传递一个error参数，来表示filter中处理出现需要终止当前处理流程的异常，请求的处理流程会直接转到一个全局的error handler来处理。
* Handler：负责实现业务逻辑。如有需要返回给客户端的响应，可以将返回结果封装成js对象，通过next传递给后面流程。
* Error Handler：处理全局异常的地方，对处理流程中发生的异常进行集中处理。
* After filter：无论前面的流程处理的结果是正常还是异常，请求最终都会进入到after filter。After filter是进行后置处理的地方，如：释放请求上下文的资源，记录请求总耗时等。After filter中不应该再出现修改响应内容的代码。

### channel和广播

Channel是服务器端向客户端推送消息的通道。Channel可以看成一个玩家id的容器，通过channel接口，可以把玩家id加入到channel中成为当中的一个成员。之后向channel推送消息，则该channel中所有的成员都会收到消息。Channel只适用于服务器进程本地，即在服务器进程A创建的channel和在服务器进程B创建的channel是两个不同的channel，相互不影响。

* 具名channel：创建时指定名字，返回一个channel实例。之后可以向channel实例添加、删除玩家id以及推送消息等。Channel实例不会自动释放，需要显式调用销毁接口。具名channel适用于需要长期维护的订阅关系，如：聊天频道服务等。
* 匿名channel：无需指定名字，无实例返回，调用时需指定目标玩家id集合。匿名channel适用于成员变化频率较大、临时的单次消息推送，如：场景AOI消息的推送。

Channel的推送过程分为两步：第一步从channel所在的服务器进程将消息推送到玩家客户端所连接的frontend进程；第二步则是通过frontend进程将消息推送到玩家客户端。第一步的推送的实现主要依赖于底层的RPC框架。推送前，会根据玩家所在的frontend服务器id进行分组，一条消息只会往同一个frontend服务器推送一次，不会造成广播消息泛滥的问题。

### RPC框架

用于进程之间通讯。

#### RPC客户端

* 最底层，使用mail box的抽象隐藏了底层通讯协议的细节。......

* 在mail box上面，是mail station层，负责管理底层所有mail box实例的创建和销毁，以及对上层提供统一的消息分发接口。.......

* 再往上的是路由层。路由层的主要工作就是提供消息路由的算法。......

* 最上面的是代理层，其主要作用是隐藏底层RPC调用的细节。......

具体阅读[Pomelo Framework](https://github.com/NetEase/pomelo/wiki/Pomelo-Framework)，设计思想很具有参考意义。

#### RPC服务提供端

* 最底下的是acceptor层，主要负责网络监听，消息接收和解析。
* 往上是dispatch层。该层主要完成的工作是根据RPC描述消息将请求分发给上层的远程服务。
* 最上层的是远程服务层，即提供远程服务业务逻辑的地方，由pomelo框架自动加载remote代码来完成。

具体阅读[Pomelo Framework](https://github.com/NetEase/pomelo/wiki/Pomelo-Framework)。

### 服务器的拓展

每一个服务进程都维护着一个application的实例app。App除了提供一些基本的配置和驱动接口，更多的是充当着服务进程上下文的角色。

app.set和app.get往上下文中保存和读取键值对。

#### 组件
是纳入服务器生命周期管理的服务单元。以服务为单位来划分，一个组件负责实现一类具体的服务。App作为服务器的主干代码，并不会参与具体的服务逻辑，更多的是充当上下文和驱动者的角色。开发者可以定义自己的组件，加入到服务器的生命周期管理中，从而来对服务器的能力进行扩展。

更多参阅[Pomelo Framework](https://github.com/NetEase/pomelo/wiki/Pomelo-Framework)。

### 小结
pomelo是一个松耦合、抽象、组件化、模块化、可方便拓展的开发框架，已经封装好各种模块，约定优于配置原则，使开发者着重于业务开发，也可灵活的进行业务拓展。