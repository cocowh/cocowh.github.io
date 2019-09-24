---
title: redis-客户端
tags: [redis,client]
comments: true
categories: [redis设计与实现]
date: 2019-09-24 19:25:51
---

### 客户端属性

redis服务器通过I/O多路复用技术实现的文件事件处理器，使用单线程单进程处理命令请求，并与多个客户端进行网络通信。为客户端建立相应的server.h/client结构，保存客户端当前的状态信息，以及执行相关功能时需要用到的数据结构。

```
/* With multiplexing we need to take per-client state.
 * Clients are taken in a linked list. */
typedef struct client {
    uint64_t id;            /* Client incremental unique ID. */
    int fd;                 /* Client socket. */
    int resp;               /* RESP protocol version. Can be 2 or 3. */
    redisDb *db;            /* Pointer to currently SELECTed DB. */
    robj *name;             /* As set by CLIENT SETNAME. */
    sds querybuf;           /* Buffer we use to accumulate client queries. */
    size_t qb_pos;          /* The position we have read in querybuf. */
    sds pending_querybuf;   /* If this client is flagged as master, this buffer
                               represents the yet not applied portion of the
                               replication stream that we are receiving from
                               the master. */
    size_t querybuf_peak;   /* Recent (100ms or more) peak of querybuf size. */
    int argc;               /* Num of arguments of current command. */
    robj **argv;            /* Arguments of current command. */
    struct redisCommand *cmd, *lastcmd;  /* Last command executed. */
    user *user;             /* User associated with this connection. If the
                               user is set to NULL the connection can do
                               anything (admin). */
    int reqtype;            /* Request protocol type: PROTO_REQ_* */
    int multibulklen;       /* Number of multi bulk arguments left to read. */
    long bulklen;           /* Length of bulk argument in multi bulk request. */
    list *reply;            /* List of reply objects to send to the client. */
    unsigned long long reply_bytes; /* Tot bytes of objects in reply list. */
    size_t sentlen;         /* Amount of bytes already sent in the current
                               buffer or object being sent. */
    time_t ctime;           /* Client creation time. */
    time_t lastinteraction; /* Time of the last interaction, used for timeout */
    time_t obuf_soft_limit_reached_time;
    uint64_t flags;         /* Client flags: CLIENT_* macros. */
    int authenticated;      /* Needed when the default user requires auth. */
    int replstate;          /* Replication state if this is a slave. */
    int repl_put_online_on_ack; /* Install slave write handler on first ACK. */
    int repldbfd;           /* Replication DB file descriptor. */
    off_t repldboff;        /* Replication DB file offset. */
    off_t repldbsize;       /* Replication DB file size. */
    sds replpreamble;       /* Replication DB preamble. */
    long long read_reploff; /* Read replication offset if this is a master. */
    long long reploff;      /* Applied replication offset if this is a master. */
    long long repl_ack_off; /* Replication ack offset, if this is a slave. */
    long long repl_ack_time;/* Replication ack time, if this is a slave. */
    long long psync_initial_offset; /* FULLRESYNC reply offset other slaves
                                       copying this slave output buffer
                                       should use. */
    char replid[CONFIG_RUN_ID_SIZE+1]; /* Master replication ID (if master). */
    int slave_listening_port; /* As configured with: SLAVECONF listening-port */
    char slave_ip[NET_IP_STR_LEN]; /* Optionally given by REPLCONF ip-address */
    int slave_capa;         /* Slave capabilities: SLAVE_CAPA_* bitwise OR. */
    multiState mstate;      /* MULTI/EXEC state */
    int btype;              /* Type of blocking op if CLIENT_BLOCKED. */
    blockingState bpop;     /* blocking state */
    long long woff;         /* Last write global replication offset. */
    list *watched_keys;     /* Keys WATCHED for MULTI/EXEC CAS */
    dict *pubsub_channels;  /* channels a client is interested in (SUBSCRIBE) */
    list *pubsub_patterns;  /* patterns a client is interested in (SUBSCRIBE) */
    sds peerid;             /* Cached peer ID. */
    listNode *client_list_node; /* list node in client list */

    /* If this client is in tracking mode and this field is non zero,
     * invalidation messages for keys fetched by this client will be send to
     * the specified client ID. */
    uint64_t client_tracking_redirection;

    /* Response buffer */
    int bufpos;
    char buf[PROTO_REPLY_CHUNK_BYTES];
} client;
```

redisServer.clients是一个保存了所有与服务器连接的客户端的状态结构。


客户端套接字描述符fd为-1（伪客户端，载入AOF或执行Lua脚本）或大于-1的整数，CLIENT list列出所有客户端。

```
127.0.0.1:6379> client list
id=3 addr=127.0.0.1:61374 fd=9 name= age=21 idle=0 flags=N db=0 sub=0 psub=0 multi=-1 qbuf=0 qbuf-free=32768 obl=0 oll=0 omem=0 events=r cmd=client
id=4 addr=127.0.0.1:61378 fd=10 name= age=2 idle=2 flags=N db=0 sub=0 psub=0 multi=-1 qbuf=0 qbuf-free=0 obl=0 oll=0 omem=0 events=r cmd=command
```

可使用CLIENT setname为客户端设置名字。

client.flags记录客户端的角色，以及客户端目前所处的状态。

client.querybuf为客户端的输入缓冲区，用于保存客户端发送的命令请求。

对命令请求进行分析，将得出的命令参数以及命令参数的个数分别保存到client.argv和client.argc中。argv[0]是要执行的命令，之后的项是传给命令的参数。

在命令表server.c/redisCommandTable中查找命令对应的实现函数，找到后将client.cmd指针指向这个结构。然后服务器可以使用cmd属性所指向的redisCommand结构，以及argv、argc属性中保存的命令参数信息。

执行命令所得回复保存在客户端状态的输出缓冲区，一个固定大小的缓冲区（client.buf：字节数组、client.bufpos：已使用字节数量）用于保存长度较小的回复，可变大小缓冲区（client.reply：链表连接多个字符串对象）用于保存长度比较大的回复。

client.authenticated属性记录客户端是否通过了身份验证，0表示未通过，1表示通过。仅在服务器启用了身份验证功能时使用，未通过时除了auth命令所有的命令被拒绝。server.c：

```

/* If this function gets called we already read a whole
 * command, arguments are in the client argv/argc fields.
 * processCommand() execute the command or prepare the
 * server for a bulk read from the client.
 *
 * If C_OK is returned the client is still alive and valid and
 * other operations can be performed by the caller. Otherwise
 * if C_ERR is returned the client was destroyed (i.e. after QUIT). */
int processCommand(client *c) {
    moduleCallCommandFilters(c);
	 ...
    /* Check if the user is authenticated. This check is skipped in case
     * the default user is flagged as "nopass" and is active. */
    int auth_required = !(DefaultUser->flags & USER_FLAG_NOPASS) &&
                        !c->authenticated;
    if (auth_required || DefaultUser->flags & USER_FLAG_DISABLED) {
        /* AUTH and HELLO are valid even in non authenticated state. */
        if (c->cmd->proc != authCommand || c->cmd->proc == helloCommand) {
            flagTransaction(c);
            addReply(c,shared.noautherr);
            return C_OK;
        }
    }
    ...
}
```

client.ctime记录创建客户端的时间，可用来计算客户端与服务器已经连接了多少秒，CLIENT list的age域记录该值。client.lastinteraction记录客户端与服务器最后一次进行互动的时间，可用于计算客户端的空转时间，CLIENT list的idle域记录该值。client.obuf_soft_limit_reached_time记录输出缓冲区第一次到达软性限制（soft limit）的时间。


### 客户端创建与关闭

若是通过网络连接与服务器进行连接的普通客户端，在客户端使用connect函数连接服务器时，服务器调用连接事件处理器，为客户端创建相应的客户端状态，并将新的客户端状态添加到服务器状态的clients链表末尾。

特殊情况如：发送的命令请求或命令回复超过了输入/输出缓冲区的限制大小被服务器关闭，设置了timeout配置选项后空转时长超过该值被服务器关闭（订阅发布或主从阻塞除外）。


限制客户端输出缓冲区的大小：

* 硬性限制：超过硬性限制大小服务器立即关闭客户端。
* 软性限制：超过软性限制（client.obuf_soft_limit_reached_time记录起始时间）但未超过硬性限制持续时间达到服务器设定的时长，则服务器关闭客户端，持续时间为超过则清零client.obuf_soft_limit_reached_time。

#### Lua脚本伪客户端

服务器初始化时创建执行Lua脚本中包含Redis命令的伪客户端，并将伪客户端关联在服务器状态结构的lua_client属性中。在服务器运行的整个生命期中一直存在，只有服务器被关闭时才会被关闭。

#### AOF文件的伪客户端

服务器在载入AOF文件时，创建用于执行AOF文件包含的Redis命令的伪客户端，在载入完成后关闭。
