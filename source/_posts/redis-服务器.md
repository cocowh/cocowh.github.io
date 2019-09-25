---
title: redis-服务器
tags: [redis,server]
comments: true
categories: [redis设计与实现]
date: 2019-09-24 22:13:59
---

### 命令请求的执行过程

经networking网络事件请求解析后调用server.c/processCommand执行命令。

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

    /* The QUIT command is handled separately. Normal command procs will
     * go through checking for replication and QUIT will cause trouble
     * when FORCE_REPLICATION is enabled and would be implemented in
     * a regular command proc. */
    if (!strcasecmp(c->argv[0]->ptr,"quit")) {
        addReply(c,shared.ok);
        c->flags |= CLIENT_CLOSE_AFTER_REPLY;
        return C_ERR;
    }

    /* Now lookup the command and check ASAP about trivial error conditions
     * such as wrong arity, bad command name and so forth. */
    c->cmd = c->lastcmd = lookupCommand(c->argv[0]->ptr);
    if (!c->cmd) {
        flagTransaction(c);
        sds args = sdsempty();
        int i;
        for (i=1; i < c->argc && sdslen(args) < 128; i++)
            args = sdscatprintf(args, "`%.*s`, ", 128-(int)sdslen(args), (char*)c->argv[i]->ptr);
        addReplyErrorFormat(c,"unknown command `%s`, with args beginning with: %s",
            (char*)c->argv[0]->ptr, args);
        sdsfree(args);
        return C_OK;
    } else if ((c->cmd->arity > 0 && c->cmd->arity != c->argc) ||
               (c->argc < -c->cmd->arity)) {
        flagTransaction(c);
        addReplyErrorFormat(c,"wrong number of arguments for '%s' command",
            c->cmd->name);
        return C_OK;
    }

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

    /* Check if the user can run this command according to the current
     * ACLs. */
    int acl_retval = ACLCheckCommandPerm(c);
    if (acl_retval != ACL_OK) {
        flagTransaction(c);
        if (acl_retval == ACL_DENIED_CMD)
            addReplyErrorFormat(c,
                "-NOPERM this user has no permissions to run "
                "the '%s' command or its subcommand", c->cmd->name);
        else
            addReplyErrorFormat(c,
                "-NOPERM this user has no permissions to access "
                "one of the keys used as arguments");
        return C_OK;
    }

    /* If cluster is enabled perform the cluster redirection here.
     * However we don't perform the redirection if:
     * 1) The sender of this command is our master.
     * 2) The command has no key arguments. */
    if (server.cluster_enabled &&
        !(c->flags & CLIENT_MASTER) &&
        !(c->flags & CLIENT_LUA &&
          server.lua_caller->flags & CLIENT_MASTER) &&
        !(c->cmd->getkeys_proc == NULL && c->cmd->firstkey == 0 &&
          c->cmd->proc != execCommand))
    {
        int hashslot;
        int error_code;
        clusterNode *n = getNodeByQuery(c,c->cmd,c->argv,c->argc,
                                        &hashslot,&error_code);
        if (n == NULL || n != server.cluster->myself) {
            if (c->cmd->proc == execCommand) {
                discardTransaction(c);
            } else {
                flagTransaction(c);
            }
            clusterRedirectClient(c,n,hashslot,error_code);
            return C_OK;
        }
    }

    /* Handle the maxmemory directive.
     *
     * Note that we do not want to reclaim memory if we are here re-entering
     * the event loop since there is a busy Lua script running in timeout
     * condition, to avoid mixing the propagation of scripts with the
     * propagation of DELs due to eviction. */
    if (server.maxmemory && !server.lua_timedout) {
        int out_of_memory = freeMemoryIfNeededAndSafe() == C_ERR;
        /* freeMemoryIfNeeded may flush slave output buffers. This may result
         * into a slave, that may be the active client, to be freed. */
        if (server.current_client == NULL) return C_ERR;

        /* It was impossible to free enough memory, and the command the client
         * is trying to execute is denied during OOM conditions or the client
         * is in MULTI/EXEC context? Error. */
        if (out_of_memory &&
            (c->cmd->flags & CMD_DENYOOM ||
             (c->flags & CLIENT_MULTI && c->cmd->proc != execCommand))) {
            flagTransaction(c);
            addReply(c, shared.oomerr);
            return C_OK;
        }
    }

    /* Make sure to use a reasonable amount of memory for client side
     * caching metadata. */
    if (server.tracking_clients) trackingLimitUsedSlots();

    /* Don't accept write commands if there are problems persisting on disk
     * and if this is a master instance. */
    int deny_write_type = writeCommandsDeniedByDiskError();
    if (deny_write_type != DISK_ERROR_TYPE_NONE &&
        server.masterhost == NULL &&
        (c->cmd->flags & CMD_WRITE ||
         c->cmd->proc == pingCommand))
    {
        flagTransaction(c);
        if (deny_write_type == DISK_ERROR_TYPE_RDB)
            addReply(c, shared.bgsaveerr);
        else
            addReplySds(c,
                sdscatprintf(sdsempty(),
                "-MISCONF Errors writing to the AOF file: %s\r\n",
                strerror(server.aof_last_write_errno)));
        return C_OK;
    }

    /* Don't accept write commands if there are not enough good slaves and
     * user configured the min-slaves-to-write option. */
    if (server.masterhost == NULL &&
        server.repl_min_slaves_to_write &&
        server.repl_min_slaves_max_lag &&
        c->cmd->flags & CMD_WRITE &&
        server.repl_good_slaves_count < server.repl_min_slaves_to_write)
    {
        flagTransaction(c);
        addReply(c, shared.noreplicaserr);
        return C_OK;
    }

    /* Don't accept write commands if this is a read only slave. But
     * accept write commands if this is our master. */
    if (server.masterhost && server.repl_slave_ro &&
        !(c->flags & CLIENT_MASTER) &&
        c->cmd->flags & CMD_WRITE)
    {
        addReply(c, shared.roslaveerr);
        return C_OK;
    }

    /* Only allow a subset of commands in the context of Pub/Sub if the
     * connection is in RESP2 mode. With RESP3 there are no limits. */
    if ((c->flags & CLIENT_PUBSUB && c->resp == 2) &&
        c->cmd->proc != pingCommand &&
        c->cmd->proc != subscribeCommand &&
        c->cmd->proc != unsubscribeCommand &&
        c->cmd->proc != psubscribeCommand &&
        c->cmd->proc != punsubscribeCommand) {
        addReplyError(c,"only (P)SUBSCRIBE / (P)UNSUBSCRIBE / PING / QUIT allowed in this context");
        return C_OK;
    }

    /* Only allow commands with flag "t", such as INFO, SLAVEOF and so on,
     * when slave-serve-stale-data is no and we are a slave with a broken
     * link with master. */
    if (server.masterhost && server.repl_state != REPL_STATE_CONNECTED &&
        server.repl_serve_stale_data == 0 &&
        !(c->cmd->flags & CMD_STALE))
    {
        flagTransaction(c);
        addReply(c, shared.masterdownerr);
        return C_OK;
    }

    /* Loading DB? Return an error if the command has not the
     * CMD_LOADING flag. */
    if (server.loading && !(c->cmd->flags & CMD_LOADING)) {
        addReply(c, shared.loadingerr);
        return C_OK;
    }

    /* Lua script too slow? Only allow a limited number of commands. */
    if (server.lua_timedout &&
          c->cmd->proc != authCommand &&
          c->cmd->proc != helloCommand &&
          c->cmd->proc != replconfCommand &&
        !(c->cmd->proc == shutdownCommand &&
          c->argc == 2 &&
          tolower(((char*)c->argv[1]->ptr)[0]) == 'n') &&
        !(c->cmd->proc == scriptCommand &&
          c->argc == 2 &&
          tolower(((char*)c->argv[1]->ptr)[0]) == 'k'))
    {
        flagTransaction(c);
        addReply(c, shared.slowscripterr);
        return C_OK;
    }

    /* Exec the command */
    if (c->flags & CLIENT_MULTI &&
        c->cmd->proc != execCommand && c->cmd->proc != discardCommand &&
        c->cmd->proc != multiCommand && c->cmd->proc != watchCommand)
    {
        queueMultiCommand(c);
        addReply(c,shared.queued);
    } else {
        call(c,CMD_CALL_FULL);
        c->woff = server.master_repl_offset;
        if (listLength(server.ready_keys))
            handleClientsBlockedOnKeys();
    }
    return C_OK;
}
```

#### 发送命令请求

客户端讲命令请求转换成协议格式，通过连接到服务器的套接字，将协议格式的命令请求发送给服务器。

#### 读取命令请求

套接字可读，服务器调用命令请求处理器：

* 读取协议格式命令请求，保存到客户端输入缓冲区
* 解析输入缓冲区命令请求，提取命令参数、命令、命令个数，server.h/redisServer.clients.argc、redisServer.clients.argv
* 调用命令执行器，执行客户端指定的指令

读取解析部分在网络IO请求networking.c。

```
/* Parse the flags string description 'strflags' and set them to the
 * command 'c'. If the flags are all valid C_OK is returned, otherwise
 * C_ERR is returned (yet the recognized flags are set in the command). */
int populateCommandTableParseFlags(struct redisCommand *c, char *strflags) {
    int argc;
    sds *argv;

    /* Split the line into arguments for processing. */
    argv = sdssplitargs(strflags,&argc);
    if (argv == NULL) return C_ERR;

    for (int j = 0; j < argc; j++) {
        char *flag = argv[j];
        if (!strcasecmp(flag,"write")) {
            c->flags |= CMD_WRITE|CMD_CATEGORY_WRITE;
        } else if (!strcasecmp(flag,"read-only")) {
            c->flags |= CMD_READONLY|CMD_CATEGORY_READ;
        } else if (!strcasecmp(flag,"use-memory")) {
            c->flags |= CMD_DENYOOM;
        } else if (!strcasecmp(flag,"admin")) {
            c->flags |= CMD_ADMIN|CMD_CATEGORY_ADMIN|CMD_CATEGORY_DANGEROUS;
        } else if (!strcasecmp(flag,"pub-sub")) {
            c->flags |= CMD_PUBSUB|CMD_CATEGORY_PUBSUB;
        } else if (!strcasecmp(flag,"no-script")) {
            c->flags |= CMD_NOSCRIPT;
        } else if (!strcasecmp(flag,"random")) {
            c->flags |= CMD_RANDOM;
        } else if (!strcasecmp(flag,"to-sort")) {
            c->flags |= CMD_SORT_FOR_SCRIPT;
        } else if (!strcasecmp(flag,"ok-loading")) {
            c->flags |= CMD_LOADING;
        } else if (!strcasecmp(flag,"ok-stale")) {
            c->flags |= CMD_STALE;
        } else if (!strcasecmp(flag,"no-monitor")) {
            c->flags |= CMD_SKIP_MONITOR;
        } else if (!strcasecmp(flag,"no-slowlog")) {
            c->flags |= CMD_SKIP_SLOWLOG;
        } else if (!strcasecmp(flag,"cluster-asking")) {
            c->flags |= CMD_ASKING;
        } else if (!strcasecmp(flag,"fast")) {
            c->flags |= CMD_FAST | CMD_CATEGORY_FAST;
        } else {
            /* Parse ACL categories here if the flag name starts with @. */
            uint64_t catflag;
            if (flag[0] == '@' &&
                (catflag = ACLGetCommandCategoryFlagByName(flag+1)) != 0)
            {
                c->flags |= catflag;
            } else {
                sdsfreesplitres(argv,argc);
                return C_ERR;
            }
        }
    }
    /* If it's not @fast is @slow in this binary world. */
    if (!(c->flags & CMD_CATEGORY_FAST)) c->flags |= CMD_CATEGORY_SLOW;

    sdsfreesplitres(argv,argc);
    return C_OK;
}

/* Populates the Redis Command Table starting from the hard coded list
 * we have on top of redis.c file. */
void populateCommandTable(void) {
    int j;
    int numcommands = sizeof(redisCommandTable)/sizeof(struct redisCommand);

    for (j = 0; j < numcommands; j++) {
        struct redisCommand *c = redisCommandTable+j;
        int retval1, retval2;

        /* Translate the command string flags description into an actual
         * set of flags. */
        if (populateCommandTableParseFlags(c,c->sflags) == C_ERR)
            serverPanic("Unsupported command flag");

        c->id = ACLGetCommandID(c->name); /* Assign the ID used for ACL. */
        retval1 = dictAdd(server.commands, sdsnew(c->name), c);
        /* Populate an additional dictionary that will be unaffected
         * by rename-command statements in redis.conf. */
        retval2 = dictAdd(server.orig_commands, sdsnew(c->name), c);
        serverAssert(retval1 == DICT_OK && retval2 == DICT_OK);
    }
}
```

#### 命令执行器查找命令实现

在server.c/redisCommandTable中查找argv[0]所指定命令，将找到的命令保存到客户端状态的server.h/redisServer.clients.cmd属性中。

```
struct redisCommand {
    char *name;
    redisCommandProc *proc;
    int arity;
    char *sflags;   /* Flags as string representation, one char per flag. */
    uint64_t flags; /* The actual flags, obtained from the 'sflags' field. */
    /* Use a function to determine keys arguments in a command line.
     * Used for Redis Cluster redirect. */
    redisGetKeysProc *getkeys_proc;
    /* What keys should be loaded in background when calling this command? */
    int firstkey; /* The first argument that's a key (0 = no keys) */
    int lastkey;  /* The last argument that's a key */
    int keystep;  /* The step between first and last key */
    long long microseconds, calls;
    int id;     /* Command ID. This is a progressive ID starting from 0 that
                   is assigned at runtime, and is used in order to check
                   ACLs. A connection is able to execute a given command if
                   the user associated to the connection has this command
                   bit set in the bitmap of allowed commands. */
};
```


#### 命令执行器执行预备操作

#### 命令执行器调用命令执行函数


```
/* Call() is the core of Redis execution of a command.
 *
 * The following flags can be passed:
 * CMD_CALL_NONE        No flags.
 * CMD_CALL_SLOWLOG     Check command speed and log in the slow log if needed.
 * CMD_CALL_STATS       Populate command stats.
 * CMD_CALL_PROPAGATE_AOF   Append command to AOF if it modified the dataset
 *                          or if the client flags are forcing propagation.
 * CMD_CALL_PROPAGATE_REPL  Send command to salves if it modified the dataset
 *                          or if the client flags are forcing propagation.
 * CMD_CALL_PROPAGATE   Alias for PROPAGATE_AOF|PROPAGATE_REPL.
 * CMD_CALL_FULL        Alias for SLOWLOG|STATS|PROPAGATE.
 *
 * The exact propagation behavior depends on the client flags.
 * Specifically:
 *
 * 1. If the client flags CLIENT_FORCE_AOF or CLIENT_FORCE_REPL are set
 *    and assuming the corresponding CMD_CALL_PROPAGATE_AOF/REPL is set
 *    in the call flags, then the command is propagated even if the
 *    dataset was not affected by the command.
 * 2. If the client flags CLIENT_PREVENT_REPL_PROP or CLIENT_PREVENT_AOF_PROP
 *    are set, the propagation into AOF or to slaves is not performed even
 *    if the command modified the dataset.
 *
 * Note that regardless of the client flags, if CMD_CALL_PROPAGATE_AOF
 * or CMD_CALL_PROPAGATE_REPL are not set, then respectively AOF or
 * slaves propagation will never occur.
 *
 * Client flags are modified by the implementation of a given command
 * using the following API:
 *
 * forceCommandPropagation(client *c, int flags);
 * preventCommandPropagation(client *c);
 * preventCommandAOF(client *c);
 * preventCommandReplication(client *c);
 *
 */
void call(client *c, int flags) {
    long long dirty, start, duration;
    int client_old_flags = c->flags;
    struct redisCommand *real_cmd = c->cmd;

    /* Sent the command to clients in MONITOR mode, only if the commands are
     * not generated from reading an AOF. */
    if (listLength(server.monitors) &&
        !server.loading &&
        !(c->cmd->flags & (CMD_SKIP_MONITOR|CMD_ADMIN)))
    {
        replicationFeedMonitors(c,server.monitors,c->db->id,c->argv,c->argc);
    }

    /* Initialization: clear the flags that must be set by the command on
     * demand, and initialize the array for additional commands propagation. */
    c->flags &= ~(CLIENT_FORCE_AOF|CLIENT_FORCE_REPL|CLIENT_PREVENT_PROP);
    redisOpArray prev_also_propagate = server.also_propagate;
    redisOpArrayInit(&server.also_propagate);

    /* Call the command. */
    dirty = server.dirty;
    start = ustime();
    c->cmd->proc(c);
    duration = ustime()-start;
    dirty = server.dirty-dirty;
    if (dirty < 0) dirty = 0;

    /* When EVAL is called loading the AOF we don't want commands called
     * from Lua to go into the slowlog or to populate statistics. */
    if (server.loading && c->flags & CLIENT_LUA)
        flags &= ~(CMD_CALL_SLOWLOG | CMD_CALL_STATS);

    /* If the caller is Lua, we want to force the EVAL caller to propagate
     * the script if the command flag or client flag are forcing the
     * propagation. */
    if (c->flags & CLIENT_LUA && server.lua_caller) {
        if (c->flags & CLIENT_FORCE_REPL)
            server.lua_caller->flags |= CLIENT_FORCE_REPL;
        if (c->flags & CLIENT_FORCE_AOF)
            server.lua_caller->flags |= CLIENT_FORCE_AOF;
    }

    /* Log the command into the Slow log if needed, and populate the
     * per-command statistics that we show in INFO commandstats. */
    if (flags & CMD_CALL_SLOWLOG && !(c->cmd->flags & CMD_SKIP_SLOWLOG)) {
        char *latency_event = (c->cmd->flags & CMD_FAST) ?
                              "fast-command" : "command";
        latencyAddSampleIfNeeded(latency_event,duration/1000);
        slowlogPushEntryIfNeeded(c,c->argv,c->argc,duration);
    }

    if (flags & CMD_CALL_STATS) {
        /* use the real command that was executed (cmd and lastamc) may be
         * different, in case of MULTI-EXEC or re-written commands such as
         * EXPIRE, GEOADD, etc. */
        real_cmd->microseconds += duration;
        real_cmd->calls++;
    }

    /* Propagate the command into the AOF and replication link */
    if (flags & CMD_CALL_PROPAGATE &&
        (c->flags & CLIENT_PREVENT_PROP) != CLIENT_PREVENT_PROP)
    {
        int propagate_flags = PROPAGATE_NONE;

        /* Check if the command operated changes in the data set. If so
         * set for replication / AOF propagation. */
        if (dirty) propagate_flags |= (PROPAGATE_AOF|PROPAGATE_REPL);

        /* If the client forced AOF / replication of the command, set
         * the flags regardless of the command effects on the data set. */
        if (c->flags & CLIENT_FORCE_REPL) propagate_flags |= PROPAGATE_REPL;
        if (c->flags & CLIENT_FORCE_AOF) propagate_flags |= PROPAGATE_AOF;

        /* However prevent AOF / replication propagation if the command
         * implementations called preventCommandPropagation() or similar,
         * or if we don't have the call() flags to do so. */
        if (c->flags & CLIENT_PREVENT_REPL_PROP ||
            !(flags & CMD_CALL_PROPAGATE_REPL))
                propagate_flags &= ~PROPAGATE_REPL;
        if (c->flags & CLIENT_PREVENT_AOF_PROP ||
            !(flags & CMD_CALL_PROPAGATE_AOF))
                propagate_flags &= ~PROPAGATE_AOF;

        /* Call propagate() only if at least one of AOF / replication
         * propagation is needed. Note that modules commands handle replication
         * in an explicit way, so we never replicate them automatically. */
        if (propagate_flags != PROPAGATE_NONE && !(c->cmd->flags & CMD_MODULE))
            propagate(c->cmd,c->db->id,c->argv,c->argc,propagate_flags);
    }

    /* Restore the old replication flags, since call() can be executed
     * recursively. */
    c->flags &= ~(CLIENT_FORCE_AOF|CLIENT_FORCE_REPL|CLIENT_PREVENT_PROP);
    c->flags |= client_old_flags &
        (CLIENT_FORCE_AOF|CLIENT_FORCE_REPL|CLIENT_PREVENT_PROP);

    /* Handle the alsoPropagate() API to handle commands that want to propagate
     * multiple separated commands. Note that alsoPropagate() is not affected
     * by CLIENT_PREVENT_PROP flag. */
    if (server.also_propagate.numops) {
        int j;
        redisOp *rop;

        if (flags & CMD_CALL_PROPAGATE) {
            for (j = 0; j < server.also_propagate.numops; j++) {
                rop = &server.also_propagate.ops[j];
                int target = rop->target;
                /* Whatever the command wish is, we honor the call() flags. */
                if (!(flags&CMD_CALL_PROPAGATE_AOF)) target &= ~PROPAGATE_AOF;
                if (!(flags&CMD_CALL_PROPAGATE_REPL)) target &= ~PROPAGATE_REPL;
                if (target)
                    propagate(rop->cmd,rop->dbid,rop->argv,rop->argc,target);
            }
        }
        redisOpArrayFree(&server.also_propagate);
    }
    server.also_propagate = prev_also_propagate;

    /* If the client has keys tracking enabled for client side caching,
     * make sure to remember the keys it fetched via this command. */
    if (c->cmd->flags & CMD_READONLY) {
        client *caller = (c->flags & CLIENT_LUA && server.lua_caller) ?
                            server.lua_caller : c;
        if (caller->flags & CLIENT_TRACKING)
            trackingRememberKeys(caller);
    }

    server.stat_numcommands++;
}
```

#### 命令执行器执行后续工作

慢日志查询、AOF、主从复制等。


#### 将命令回复发送给客户端

networking.c中：

```
/* Write event handler. Just send data to the client. */
void sendReplyToClient(aeEventLoop *el, int fd, void *privdata, int mask) {
    UNUSED(el);
    UNUSED(mask);
    writeToClient(fd,privdata,1);
}
```

#### 客户端接收并打印命令回复

例如redis\-cli，cliReadReply将回复命令回复格式化后写入标准输出。


### serverCron函数

每隔100毫秒运行一次，负责管理服务器的资源，保持服务器自身的良好运转。

#### 更新服务器时间缓存

redisServer.unixtime和redisServer.mstime，不精准，只在打印日志、更新服务器的LRU时钟、决定是否持久化、计算服务器上线时间等对精度要求不高时使用。对键设置过期时间、添加慢日志等高精度服务器再次执行系统调用。

#### 更新LRU时钟

redisServer.lruclock，INFO server的lru\_clock值。

```
127.0.0.1:6379> info server
# Server
redis_version:4.0.10
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:ea14acb2d1b3b56f
redis_mode:standalone
os:Darwin 18.7.0 x86_64
arch_bits:64
multiplexing_api:kqueue
atomicvar_api:atomic-builtin
gcc_version:4.2.1
process_id:440
run_id:cdd4befae14640bdb75dd1ed60c3880aadd8e9d1
tcp_port:6379
uptime_in_seconds:247596
uptime_in_days:2
hz:10
lru_clock:9135224
executable:/usr/local/opt/redis/bin/redis-server
config_file:/usr/local/etc/redis.conf
```

每个Redis对象都有一个时钟保存对象最后一次被命令访问的时间。

server.h/redisObject.lru。、

redisServer.lruclock - redisObject.lru即为对象空转时间。


#### 更新服务器每秒执行次数

```
   run_with_period(100) {
        trackInstantaneousMetric(STATS_METRIC_COMMAND,server.stat_numcommands);
        trackInstantaneousMetric(STATS_METRIC_NET_INPUT,
                server.stat_net_input_bytes);
        trackInstantaneousMetric(STATS_METRIC_NET_OUTPUT,
                server.stat_net_output_bytes);
    }
```

serverCron的trackInstantaneousMetric函数没100毫秒执行一次，估算并记录服务器最近一秒钟处理命令请求数量。

INFO stats的instantaneous\_ops\_per\_sec值：

```
127.0.0.1:6379> info stats
# Stats
total_connections_received:2
total_commands_processed:6
instantaneous_ops_per_sec:0
total_net_input_bytes:162
total_net_output_bytes:21919
instantaneous_input_kbps:0.00
instantaneous_output_kbps:0.00
rejected_connections:0
sync_full:0
sync_partial_ok:0
sync_partial_err:0
expired_keys:0
expired_stale_perc:0.00
expired_time_cap_reached_count:0
evicted_keys:0
keyspace_hits:0
keyspace_misses:0
pubsub_channels:0
pubsub_patterns:0
latest_fork_usec:27954
migrate_cached_sockets:0
slave_expires_tracked_keys:0
active_defrag_hits:0
active_defrag_misses:0
active_defrag_key_hits:0
active_defrag_key_misses:0
```

#### 更新服务器内存峰值记录

redisServer.stat\_peak\_memory

```
    /* Record the max memory used since the server was started. */
    if (zmalloc_used_memory() > server.stat_peak_memory)
        server.stat_peak_memory = zmalloc_used_memory();
```

#### 处理SIGTERM信号

启动服务器时，为服务器进程的SIGTERM信号关联处理器sigShutdownHandler函数，该函数负责在服务器接到SIGTERM信号时，设置服务器状态的shutdown\_asap标识。

根据redisServer.shutdown\_asap属性决定是否关闭服务器。

```
  /* We received a SIGTERM, shutting down here in a safe way, as it is
     * not ok doing so inside the signal handler. */
    if (server.shutdown_asap) {
        if (prepareForShutdown(SHUTDOWN_NOFLAGS) == C_OK) exit(0);
        serverLog(LL_WARNING,"SIGTERM received but errors trying to shut down the server, check the logs for more information");
        server.shutdown_asap = 0;
    }
```

#### 管理客户端资源

```
    /* We need to do a few operations on clients asynchronously. */
    clientsCron();
```

serverCron函数调用clientsCron函数，对一定数量的客户端进行检查：


```

/* This function is called by serverCron() and is used in order to perform
 * operations on clients that are important to perform constantly. For instance
 * we use this function in order to disconnect clients after a timeout, including
 * clients blocked in some blocking command with a non-zero timeout.
 *
 * The function makes some effort to process all the clients every second, even
 * if this cannot be strictly guaranteed, since serverCron() may be called with
 * an actual frequency lower than server.hz in case of latency events like slow
 * commands.
 *
 * It is very important for this function, and the functions it calls, to be
 * very fast: sometimes Redis has tens of hundreds of connected clients, and the
 * default server.hz value is 10, so sometimes here we need to process thousands
 * of clients per second, turning this function into a source of latency.
 */
#define CLIENTS_CRON_MIN_ITERATIONS 5
void clientsCron(void) {
    /* Try to process at least numclients/server.hz of clients
     * per call. Since normally (if there are no big latency events) this
     * function is called server.hz times per second, in the average case we
     * process all the clients in 1 second. */
    int numclients = listLength(server.clients);
    int iterations = numclients/server.hz;
    mstime_t now = mstime();

    /* Process at least a few clients while we are at it, even if we need
     * to process less than CLIENTS_CRON_MIN_ITERATIONS to meet our contract
     * of processing each client once per second. */
    if (iterations < CLIENTS_CRON_MIN_ITERATIONS)
        iterations = (numclients < CLIENTS_CRON_MIN_ITERATIONS) ?
                     numclients : CLIENTS_CRON_MIN_ITERATIONS;

    while(listLength(server.clients) && iterations--) {
        client *c;
        listNode *head;

        /* Rotate the list, take the current head, process.
         * This way if the client must be removed from the list it's the
         * first element and we don't incur into O(N) computation. */
        listRotate(server.clients);
        head = listFirst(server.clients);
        c = listNodeValue(head);
        /* The following functions do different service checks on the client.
         * The protocol is that they return non-zero if the client was
         * terminated. */
        if (clientsCronHandleTimeout(c,now)) continue;
        if (clientsCronResizeQueryBuffer(c)) continue;
        if (clientsCronTrackExpansiveClients(c)) continue;
    }
}
```

* 连接超时，释放客户端。
* 输入缓冲区超限重新创建扩容。


#### 管理数据库资源

```
  /* Handle background operations on Redis databases. */
    databasesCron();
```

对服务器中的一部分数据库进行检查，删除其中的过期键，在有需要时对字典进行收缩。

```
/* This function handles 'background' operations we are required to do
 * incrementally in Redis databases, such as active key expiring, resizing,
 * rehashing. */
void databasesCron(void) {
    /* Expire keys by random sampling. Not required for slaves
     * as master will synthesize DELs for us. */
    if (server.active_expire_enabled) {
        if (server.masterhost == NULL) {
            activeExpireCycle(ACTIVE_EXPIRE_CYCLE_SLOW);
        } else {
            expireSlaveKeys();
        }
    }

    /* Defrag keys gradually. */
    if (server.active_defrag_enabled)
        activeDefragCycle();

    /* Perform hash tables rehashing if needed, but only if there are no
     * other processes saving the DB on disk. Otherwise rehashing is bad
     * as will cause a lot of copy-on-write of memory pages. */
    if (server.rdb_child_pid == -1 && server.aof_child_pid == -1) {
        /* We use global counters so if we stop the computation at a given
         * DB we'll be able to start from the successive in the next
         * cron loop iteration. */
        static unsigned int resize_db = 0;
        static unsigned int rehash_db = 0;
        int dbs_per_call = CRON_DBS_PER_CALL;
        int j;

        /* Don't test more DBs than we have. */
        if (dbs_per_call > server.dbnum) dbs_per_call = server.dbnum;

        /* Resize */
        for (j = 0; j < dbs_per_call; j++) {
            tryResizeHashTables(resize_db % server.dbnum);
            resize_db++;
        }

        /* Rehash */
        if (server.activerehashing) {
            for (j = 0; j < dbs_per_call; j++) {
                int work_done = incrementallyRehash(rehash_db);
                if (work_done) {
                    /* If the function did some work, stop here, we'll do
                     * more at the next cron loop. */
                    break;
                } else {
                    /* If this db didn't need rehash, we'll try the next one. */
                    rehash_db++;
                    rehash_db %= server.dbnum;
                }
            }
        }
    }
}
```

#### 执行被延迟的BGREWRITEAOF

```

    /* Start a scheduled AOF rewrite if this was requested by the user while
     * a BGSAVE was in progress. */
    if (server.rdb_child_pid == -1 && server.aof_child_pid == -1 &&
        server.aof_rewrite_scheduled)
    {
        rewriteAppendOnlyFileBackground();
    }
```


### 初始化服务器

seerver.c->main调用initServerConfig初始化server变量：

* 设置服务器的运行ID
* 设置服务器的默认运行频率
* 设置服务器的默认配置文件路径
* 设置服务器的运行架构
* 设置服务器的默认端口号
* 设置服务器的默认RDB持久化条件和AOF持久化条件
* 初始化服务器的LRU时钟
* 创建命令表

#### 载入配置选项

* 若为属性的相应选项指定新的值，服务器使用指定值更新相应的属性
* 若没有为属性的相应选项设置新的值，沿用initServerConfig函数为属性设置的默认值

#### 初始化服务器数据结构

调用initServer函数，为server.clients、server.db、server.pubsub_channels、server.lua、server.slowlog等分配内存或者关联初始化值。

initServerConfig主要初始化一般属性、initServer主要负责初始化数据结构。

还进行：

* 为服务器设置进程信号处理器。
* 创建共享对象。
* 打开服务器的监听端口，为监听套接字关联连接应答事件处理器，等待服务器正式运行时接受客户端的连接。
* 为serverCron函数创建时间事件，等待服务器正式运行时执行serverCron函数。
* 若AOF持久化功能已打开，则打开现有的AOF文件，若AOF文件不存在则创建并打开一个新的AOF文件，为AOF写入做好准备。
* 初始化服务器的后台I/O模块（bio），为I/O操作做准备。


#### 还原数据库状态

完成对服务器server变量的初始化后，服务器载入RDB文件或AOF文件，根据文件记录的内容来还原服务器的数据库状态。

#### 执行事件循环

执行服务器的事件循环（loop），服务器可接受客户端的连接请求，并处理客户端发来的命令请求。


