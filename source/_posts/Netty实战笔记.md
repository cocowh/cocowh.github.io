---
title: Netty实战笔记
tags: [java,netty,笔记]
comments: true
categories: [netty]
date: 2018-11-19 14:30:29
---
## 编写Echo服务器
### ChannelHandler和业务逻辑
响应传入的消息，需要实现ChannelInboundHandler接口，用来定义响应入站时间