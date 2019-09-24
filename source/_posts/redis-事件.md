---
title: redis-事件
tags: [reids,event]
comments: true
categories: [redis设计与实现]
date: 2019-09-23 17:35:53
---

* 文件事件，服务器对套接字操作的抽象，通过监听并处理这些事件完成一系列的网络通信操作。
* 时间事件：对定时操作的抽象。

ae*系列文件，ae.h定义：

```
#define AE_FILE_EVENTS 1
#define AE_TIME_EVENTS 2
```

### 文件事件

基于[Reactor](https://www.jianshu.com/p/eef7ebe28673)模式开发的网络事件处理器，被称为文件事件处理器：

* 使用I/O多路复用程序同监听多个套接字，根据套接字目前执行的任务为套接字关联不同的事件处理器。
* 被监听套接字准备好执行连接应答（accept）、读取（read）、写入（write）、关闭（close）等操作时，与操作相应的文件事件就会产生，文件事件处理器调用套接字之前关联好的事件处理器处理这些事件。

单线程方式运行。包含四个组成部分：

* 套接字：根据操作产生相应的文件事件。
* I/O多路复用程序：监听多个套接字并将所有产生事件的套接字放入队列，以有序、同步、每次一个套接字的方式向文件事件分派器传送套接字，上个套接字产生的事件处理完毕后才派发下一个套接字。
* 文件事件分派器：接收I/O多路复用程序传来的套接字，根据套接字产生的事件的类型，调用相应的事件处理器。
* 事件处理器：一个个函数，定义某个事件发生时，服务器应该执行的动作。


多路复用程序包装select(ae_select.c)、epoll(ae_epoll.c)、evport(ae_evport.c)、kqueue(ae_kqueue.c)等I/O多路复用函数实现.

 
```
/* Include the best multiplexing layer supported by this system.
 * The following should be ordered by performances, descending. */
#ifdef HAVE_EVPORT
#include "ae_evport.c"
#else
    #ifdef HAVE_EPOLL
    #include "ae_epoll.c"
    #else
        #ifdef HAVE_KQUEUE
        #include "ae_kqueue.c"
        #else
        #include "ae_select.c"
        #endif
    #endif
#endif
```
选择系统中能提供的，性能最高的I/O多路复用函数库，有优先级次序。


事件类型：

```
#define AE_NONE 0       /* No events registered. */
#define AE_READABLE 1   /* Fire when descriptor is readable. */
#define AE_WRITABLE 2   /* Fire when descriptor is writable. */
#define AE_BARRIER 4    /* With WRITABLE, never fire the event if the
                           READABLE event already fired in the same event
                           loop iteration. Useful when you want to persist
                           things to disk before sending replies, and want
                           to do that in a group fashion. */
```

文件事件：

```
/* File event structure */
typedef struct aeFileEvent {
    int mask; /* one of AE_(READABLE|WRITABLE|BARRIER) */
    aeFileProc *rfileProc;
    aeFileProc *wfileProc;
    void *clientData;
} aeFileEvent;
```
### 文件事件处理器

* 连接应答处理器：networking.c/acceptTcpHandler
* 命令请求处理器：networking.c/readQueryFromClient
* 命令回复处理器：networking.c/sendReplyToClient

### 时间事件

* 定时事件
* 周期性事件


```
/* Time event structure */
typedef struct aeTimeEvent {
    long long id; /* time event identifier. */
    long when_sec; /* seconds */
    long when_ms; /* milliseconds */
    aeTimeProc *timeProc;
    aeEventFinalizerProc *finalizerProc;
    void *clientData;
    struct aeTimeEvent *prev;
    struct aeTimeEvent *next;
} aeTimeEvent;
```


将时间事件放在一个无序链表中，时间事件执行器运行时遍历整个链表，查找所有已到达的时间事件，调用相应的事件处理器。







