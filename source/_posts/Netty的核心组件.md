---
title: Netty的核心组件
tags: [netty]
comments: true
categories: [netty]
date: 2018-11-02 14:42:46
---
阅读《netty实战》，初识netty的一些笔记。

异步、事件驱动。

### 核心组件
 * Channel
 * 回调
 * Future
 * 事件和ChannelHandler
 
#### Channel
Java NIO的一个基本构造。
>代表一个到实体（如一个硬件设备、一个文件、一个网络套接字或者一个能够执行一个或者多个不同的I/O操作的程序组件）的开放连接，如读操作和写操作。

可以把Channel看作是传入（入站）或者传出（出站）数据的载体。可以被打开或者被关闭，链接或者断开连接。

#### 回调
一个指向已经被提供给另一个方法的方法的引用。使得后者可以调用前者。

Netty在内部使用回调来处理事件，当一个回调被触发时，相关的事件可以被一个interface ChannelHandler的实现处理。

当一个新的连接已经被建立，ChannelHandler的channelActive()回调方法将会被调用。

```
public class ConnectHandler extends ChannelInboundHandlerAdapter {
	public void channelActive(ChannelHandlerContext ctx) throws Exception {
		System.out.println("Client " + ctx.channel().remoteAddress() + " connected");
	}
}
```

#### Future
提供了另一种在操作完成时通知应用程序的方式。可以看作是一个异步操作的结果的占位符；将在未来的某个时刻完成，并提供对其结果的访问。

JDK预置的interface java.util.concurrent.Future提供的实现只允许手动检查对应的操作是否已经完成，或者一直阻塞直到它完成。Netty提供了自己的实现——ChannelFuture，用于在执行异步操作的时候使用。

ChannelFuture提供额外的方法，使得我们能够注册一个或者多个ChannelFutureListener实例。监听器的回调方法operationComplete()，会在对应的操作完成时被调用。然后监听器可以判断该操作是成功地完成了还是出错了。ChannelFutureListener提供的通知机制消除了手动检查对应的操作是否完成的必要。

每个Netty的出站I/O操作都将返回一个ChannelFuture，它们都不会阻塞。

ChannelFuture作为一个I/O操作的一部分返回。connect()方法将会直接返回，而不会阻塞，调用将会在后台完成。

```
Channel channel = ...;

ChannelFuture future = Channel.connect(new InetSocketAddress("192.168.0.1", 25));
```

利用ChannelFutureListener

```
Channel channel = ...;
ChannelFuture future = channel.connect(new InetSocketAddress("192.168.0.1", 25));	异步连接到远程节点
future.addListener(new ChannelFutureListener() {	//	注册一个ChannelFutureListener，在操作完成时获得通知
    @Override
    public void operationComplete(ChannelFuture future) {
        if (future.isSuccess()) {		//检查操作的状态
            ByteBuf buffer = Unpooled.copiedBuffer("Hello", Charset.defaultCharset());
            ChannelFuture wf = future.channel().writeAndFlush(buffer);
            ...
        } else {
            Throwable cause = future.cause();
            cause.printStackTrace();
        }
    }
})
```

#### 事件和ChannelHandler

Netty使用不同的事件来通知状态的改变或者是操作的状态。能够基于已经发生的事件来触发适当的动作。这些动作可能是：
 
 * 记录日志；
 * 数据流转换；
 * 流控制；
 * 应用程序逻辑。
 
 Netty的事件是按照它们与入站或者出站数据流的相关性进行分类的。可能由入站数据或者相关的状态更改而触发的事件包括：
 
 * 连接已被激活或者连接失活；
 * 数据读取；
 * 用户事件；
 * 错误事件。
 
 出站事件是未来将会触发的某个动作的操作结果，这些动作包括：
 
 * 打开或者关闭到远程节点的连接；
 * 将数据写到或者冲刷到套接字。

 每个事件都可以被分发给ChannelHandler类中的某个用户实现的方法（将事件驱动范式直接转换为应用程序构件块）。
 
 Netty的ChannelHandler为处理器提供了基本的抽象。每个ChannelHandler的实例都类似于一种为了响应特定事件而被执行的回调。

### 关系

#### Future、回调和ChannelHandler
Netty异步编程模型建立在Future和回调之上，将事件派发到ChannelHandler的方法发生在更深的层次上。

拦截操作以及高速地转换入站数据和出站数据，需要提供回调或者利用操作所返回的Future。

#### 选择器、事件和EventLoop
Netty通过触发事件将Selector从应用程序中抽象出来，消除了本来将需要手动编写的派发代码。在内部，会为每个Channel分配一个EventLoop，用以处理所有事件，包括：

* 注册感兴趣的事件；
* 将事件派发给ChannelHandler；
* 安排进一步的动作。

EventLoop本身只由一个线程驱动，其处理了一个Channel的所有I/O事件，并且在该EventLoop的整个生命周期内都不会改变。此设计消除了可能有的在ChannelHandler实现中需要进行同步的任何顾虑，只需专注于提供正确的逻辑，用来在感兴趣的数据要处理的时候执行。
