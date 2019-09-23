---
title: redis-AOF持久化
tags: [redis,AOF]
comments: true
categories: [redis设计与实现]
date: 2019-09-19 16:57:17
---

RDB持久化通过保存数据库中的键值对来记录数据库状态的不同，AOF持久化通过保存Redis服务器所执行的写命令来记录数据状态。

### AOF持久化

redis.conf的APPEND ONLY MODE决定是否开启AOF持久化，位于redis.conf的dir选项目录下默认名appendonly.aof。

```
wuhua:redis wuhua$ cat appendonly.aof
```

```
wuhua:~ wuhua$ redis-cli 
127.0.0.1:6379> set aofkey aofvalue
OK
127.0.0.1:6379> 
```

``` 
wuhua:redis wuhua$ cat appendonly.aof 
*2
$6
SELECT
$1
0
*3
$3
set
$6
aofkey
$8
aofvalue
wuhua:redis wuhua$
```

分文件追加、文件写入、文件同步三个步骤。

服务器执行完一个写命令后，以协议格式将被执行的写命令追加到服务器状态的aof_buf缓冲区的末尾。

```
...
struct redisServer {
	 ...
	 /* AOF persistence */
    int aof_enabled;                /* AOF configuration */
    int aof_state;                  /* AOF_(ON|OFF|WAIT_REWRITE) */
    int aof_fsync;                  /* Kind of fsync() policy */
    char *aof_filename;             /* Name of the AOF file */
    int aof_no_fsync_on_rewrite;    /* Don't fsync if a rewrite is in prog. */
    int aof_rewrite_perc;           /* Rewrite AOF if % growth is > M and... */
    off_t aof_rewrite_min_size;     /* the AOF file is at least N bytes. */
    off_t aof_rewrite_base_size;    /* AOF size on latest startup or rewrite. */
    off_t aof_current_size;         /* AOF current size. */
    off_t aof_fsync_offset;         /* AOF offset which is already synced to disk. */
    int aof_rewrite_scheduled;      /* Rewrite once BGSAVE terminates. */
    pid_t aof_child_pid;            /* PID if rewriting process */
    list *aof_rewrite_buf_blocks;   /* Hold changes during an AOF rewrite. */
    sds aof_buf;      /* AOF buffer, written before entering the event loop */
    int aof_fd;       /* File descriptor of currently selected AOF file */
    int aof_selected_db; /* Currently selected DB in AOF */
    time_t aof_flush_postponed_start; /* UNIX time of postponed AOF flush */
    time_t aof_last_fsync;            /* UNIX time of last fsync() */
    time_t aof_rewrite_time_last;   /* Time used by last AOF rewrite run. */
    time_t aof_rewrite_time_start;  /* Current AOF rewrite start time. */
    int aof_lastbgrewrite_status;   /* C_OK or C_ERR */
    unsigned long aof_delayed_fsync;  /* delayed AOF fsync() counter */
    int aof_rewrite_incremental_fsync;/* fsync incrementally while aof rewriting? */
    int rdb_save_incremental_fsync;   /* fsync incrementally while rdb saving? */
    int aof_last_write_status;      /* C_OK or C_ERR */
    int aof_last_write_errno;       /* Valid if aof_last_write_status is ERR */
    int aof_load_truncated;         /* Don't stop on unexpected AOF EOF. */
    int aof_use_rdb_preamble;       /* Use RDB preamble on AOF rewrites. */
    /* AOF pipes used to communicate between parent and child during rewrite. */
    int aof_pipe_write_data_to_child;
    int aof_pipe_read_data_from_parent;
    int aof_pipe_write_ack_to_parent;
    int aof_pipe_read_ack_from_child;
    int aof_pipe_write_ack_to_child;
    int aof_pipe_read_ack_from_parent;
    int aof_stop_sending_diff;     /* If true stop sending accumulated diffs
                                      to child process. */
    sds aof_child_diff;             /* AOF diff accumulator child side. */
    ...
}
...
```

Redis服务进程是一个事件循环，循环中的文件事件负责接收客户端的命令请求，以及向客户端发送命令回复，时间事件负责执行serverCron这类需要定时运行的函数。

服务每结束结束一个事件循环之前，调用flushAppendOnlyFile函数，决定是否将aof_buf缓冲区中的内容写入保存到AOF文件中。

```
/* This is our timer interrupt, called server.hz times per second.
 * Here is where we do a number of things that need to be done asynchronously.
 * For instance:
 *
 * - Active expired keys collection (it is also performed in a lazy way on
 *   lookup).
 * - Software watchdog.
 * - Update some statistic.flushAppendOnlyFile
 * - Incremental rehashing of the DBs hash tables.
 * - Triggering BGSAVE / AOF rewrite, and handling of terminated children.
 * - Clients timeout of different kinds.
 * - Replication reconnection.
 * - Many more...
 *
 * Everything directly called here will be called server.hz times per second,
 * so in order to throttle execution of things we want to do less frequently
 * a macro is used: run_with_period(milliseconds) { .... }
 */

int serverCron(struct aeEventLoop *eventLoop, long long id, void *clientData) {
	...
	 /* AOF postponed flush: Try at every cron cycle if the slow fsync
     * completed. */
    if (server.aof_flush_postponed_start) flushAppendOnlyFile(0);

    /* AOF write errors: in this case we have a buffer to flush as well and
     * clear the AOF error in case of success to make the DB writable again,
     * however to try every second is enough in case of 'hz' is set to
     * an higher frequency. */
    run_with_period(1000) {
        if (server.aof_last_write_status == C_ERR)
            flushAppendOnlyFile(0);
    }
	...
}

/* This function gets called every time Redis is entering the
 * main loop of the event driven library, that is, before to sleep
 * for ready file descriptors. */
void beforeSleep(struct aeEventLoop *eventLoop) {
	 ...
    /* Write the AOF buffer on disk */
	 flushAppendOnlyFile(0);
	 ...
}

int prepareForShutdown(int flags) {
	...
	/* Append only file: flush buffers and fsync() the AOF at exit */
	serverLog(LL_NOTICE,"Calling fsync() on the AOF file.");
	flushAppendOnlyFile(1);
	redis_fsync(server.aof_fd);
	...
}
```

appendfsync选项决定flushAppendOnlyFile函数的行为：

appendfsync选项值 | flushAppendOnlyFile函数行为
:-: | :-:
always | 将aof_buf缓冲区中的所有内容写入并同步到AOF文件，最安全但效率最慢
everysec | 默认值，将aof_buf缓冲区中的所有内容写入到AOF文件，若上次同步AOF文件的时间距离现在超过1s，则再次对AOF文件进行同步，且同步操作由一个线程专门负责，效率快但最多丢失1s内数据风险
no | 将aof_buf缓冲区中的内容写入到AOF文件，但并不对AOF文件进行同步，同步由操作系统决定


调用write函数将数据写入文件，通常将其保存在一个内存缓冲区中，待其被填满或超过指定时限，才真正将缓冲区中的数据写入到磁盘。可通过fsync和fdatasync两个同步函数，强制让操作系统立即将缓冲区中的数据写入硬盘。



### AOF文件的载入和还原

Redis命令只能在客户端上下文中执行，创建不带网络连接的伪客户端执行AOF文件保存的写命令。

```
/* ----------------------------------------------------------------------------
 * AOF loading
 * ------------------------------------------------------------------------- */

/* In Redis commands are always executed in the context of a client, so in
 * order to load the append only file we need to create a fake client. */
struct client *createFakeClient(void) {
    struct client *c = zmalloc(sizeof(*c));

    selectDb(c,0);
    c->fd = -1;
    c->name = NULL;
    c->querybuf = sdsempty();
    c->querybuf_peak = 0;
    c->argc = 0;
    c->argv = NULL;
    c->bufpos = 0;
    c->flags = 0;
    c->btype = BLOCKED_NONE;
    /* We set the fake client as a slave waiting for the synchronization
     * so that Redis will not try to send replies to this client. */
    c->replstate = SLAVE_STATE_WAIT_BGSAVE_START;
    c->reply = listCreate();
    c->reply_bytes = 0;
    c->obuf_soft_limit_reached_time = 0;
    c->watched_keys = listCreate();
    c->peerid = NULL;
    c->resp = 2;
    c->user = NULL;
    listSetFreeMethod(c->reply,freeClientReplyValue);
    listSetDupMethod(c->reply,dupClientReplyValue);
    initClientMultiState(c);
    return c;
}
...
```

### AOF重写

解决AOF文件体积膨胀问题，创建一个新的AOF文件替代现有的AOF文件，新旧文件保存的数据库状态相同，新AOF文件不包含任何浪费的冗余命令，实际不需要对现有的AOF文件进行任何读取、分析或者写入操作，读取服务器当前的数据库状态实现。


```
/* ----------------------------------------------------------------------------
 * AOF background rewrite
 * ------------------------------------------------------------------------- */

/* This is how rewriting of the append only file in background works:
 *
 * 1) The user calls BGREWRITEAOF
 * 2) Redis calls this function, that forks():
 *    2a) the child rewrite the append only file in a temp file.
 *    2b) the parent accumulates differences in server.aof_rewrite_buf.
 * 3) When the child finished '2a' exists.
 * 4) The parent will trap the exit code, if it's OK, will append the
 *    data accumulated into server.aof_rewrite_buf into the temp file, and
 *    finally will rename(2) the temp file in the actual file name.
 *    The the new file is reopened as the new append only file. Profit!
 */
int rewriteAppendOnlyFileBackground(void) {
    pid_t childpid;
    long long start;

    if (server.aof_child_pid != -1 || server.rdb_child_pid != -1) return C_ERR;
    if (aofCreatePipes() != C_OK) return C_ERR;
    openChildInfoPipe();
    start = ustime();
    if ((childpid = fork()) == 0) {
        char tmpfile[256];

        /* Child */
        closeListeningSockets(0);
        redisSetProcTitle("redis-aof-rewrite");
        snprintf(tmpfile,256,"temp-rewriteaof-bg-%d.aof", (int) getpid());
        if (rewriteAppendOnlyFile(tmpfile) == C_OK) {
            size_t private_dirty = zmalloc_get_private_dirty(-1);

            if (private_dirty) {
                serverLog(LL_NOTICE,
                    "AOF rewrite: %zu MB of memory used by copy-on-write",
                    private_dirty/(1024*1024));
            }

            server.child_info_data.cow_size = private_dirty;
            sendChildInfo(CHILD_INFO_TYPE_AOF);
            exitFromChild(0);
        } else {
            exitFromChild(1);
        }
    } else {
        /* Parent */
        server.stat_fork_time = ustime()-start;
        server.stat_fork_rate = (double) zmalloc_used_memory() * 1000000 / server.stat_fork_time / (1024*1024*1024); /* GB per second. */
        latencyAddSampleIfNeeded("fork",server.stat_fork_time/1000);
        if (childpid == -1) {
            closeChildInfoPipe();
            serverLog(LL_WARNING,
                "Can't rewrite append only file in background: fork: %s",
                strerror(errno));
            aofClosePipes();
            return C_ERR;
        }
        serverLog(LL_NOTICE,
            "Background append only file rewriting started by pid %d",childpid);
        server.aof_rewrite_scheduled = 0;
        server.aof_rewrite_time_start = time(NULL);
        server.aof_child_pid = childpid;
        updateDictResizePolicy();
        /* We set appendseldb to -1 in order to force the next call to the
         * feedAppendOnlyFile() to issue a SELECT command, so the differences
         * accumulated by the parent into server.aof_rewrite_buf will start
         * with a SELECT statement and it will be safe to merge. */
        server.aof_selected_db = -1;
        replicationScriptCacheFlush();
        return C_OK;
    }
    return C_OK; /* unreached */
}
```


子进程进行“重写”，根据数据类型调用不同的重写规则。子进程带有服务器进程的数据副本，可在避免使用锁的情况下，保证数据的安全性。

设置AOF重写缓冲区，在服务器创建重写子进程后使用，当redis服务器执行完一个写命令后，会同时将这个写命令发送给AOF缓冲区和AOF重写缓冲区。子进程完成重写后向父进程发送一个信号，父进车收到信号后，调用信号处理函数将AOF重写缓冲区中的所有内容写入到新的AOF文件中并对新的AOF文件进行改名，原子地覆盖现有的AOF文件，完成新旧两个AOF文件的替换。

```
/* A background append only file rewriting (BGREWRITEAOF) terminated its work.
 * Handle this. */
void backgroundRewriteDoneHandler(int exitcode, int bysignal) {
    if (!bysignal && exitcode == 0) {
        int newfd, oldfd;
        char tmpfile[256];
        long long now = ustime();
        mstime_t latency;

        serverLog(LL_NOTICE,
            "Background AOF rewrite terminated with success");

        /* Flush the differences accumulated by the parent to the
         * rewritten AOF. */
        latencyStartMonitor(latency);
        snprintf(tmpfile,256,"temp-rewriteaof-bg-%d.aof",
            (int)server.aof_child_pid);
        newfd = open(tmpfile,O_WRONLY|O_APPEND);
        if (newfd == -1) {
            serverLog(LL_WARNING,
                "Unable to open the temporary AOF produced by the child: %s", strerror(errno));
            goto cleanup;
        }

        if (aofRewriteBufferWrite(newfd) == -1) {
            serverLog(LL_WARNING,
                "Error trying to flush the parent diff to the rewritten AOF: %s", strerror(errno));
            close(newfd);
            goto cleanup;
        }
        latencyEndMonitor(latency);
        latencyAddSampleIfNeeded("aof-rewrite-diff-write",latency);

        serverLog(LL_NOTICE,
            "Residual parent diff successfully flushed to the rewritten AOF (%.2f MB)", (double) aofRewriteBufferSize() / (1024*1024));

        /* The only remaining thing to do is to rename the temporary file to
         * the configured file and switch the file descriptor used to do AOF
         * writes. We don't want close(2) or rename(2) calls to block the
         * server on old file deletion.
         *
         * There are two possible scenarios:
         *
         * 1) AOF is DISABLED and this was a one time rewrite. The temporary
         * file will be renamed to the configured file. When this file already
         * exists, it will be unlinked, which may block the server.
         *
         * 2) AOF is ENABLED and the rewritten AOF will immediately start
         * receiving writes. After the temporary file is renamed to the
         * configured file, the original AOF file descriptor will be closed.
         * Since this will be the last reference to that file, closing it
         * causes the underlying file to be unlinked, which may block the
         * server.
         *
         * To mitigate the blocking effect of the unlink operation (either
         * caused by rename(2) in scenario 1, or by close(2) in scenario 2), we
         * use a background thread to take care of this. First, we
         * make scenario 1 identical to scenario 2 by opening the target file
         * when it exists. The unlink operation after the rename(2) will then
         * be executed upon calling close(2) for its descriptor. Everything to
         * guarantee atomicity for this switch has already happened by then, so
         * we don't care what the outcome or duration of that close operation
         * is, as long as the file descriptor is released again. */
        if (server.aof_fd == -1) {
            /* AOF disabled */

            /* Don't care if this fails: oldfd will be -1 and we handle that.
             * One notable case of -1 return is if the old file does
             * not exist. */
            oldfd = open(server.aof_filename,O_RDONLY|O_NONBLOCK);
        } else {
            /* AOF enabled */
            oldfd = -1; /* We'll set this to the current AOF filedes later. */
        }

        /* Rename the temporary file. This will not unlink the target file if
         * it exists, because we reference it with "oldfd". */
        latencyStartMonitor(latency);
        if (rename(tmpfile,server.aof_filename) == -1) {
            serverLog(LL_WARNING,
                "Error trying to rename the temporary AOF file %s into %s: %s",
                tmpfile,
                server.aof_filename,
                strerror(errno));
            close(newfd);
            if (oldfd != -1) close(oldfd);
            goto cleanup;
        }
        latencyEndMonitor(latency);
        latencyAddSampleIfNeeded("aof-rename",latency);

        if (server.aof_fd == -1) {
            /* AOF disabled, we don't need to set the AOF file descriptor
             * to this new file, so we can close it. */
            close(newfd);
        } else {
            /* AOF enabled, replace the old fd with the new one. */
            oldfd = server.aof_fd;
            server.aof_fd = newfd;
            if (server.aof_fsync == AOF_FSYNC_ALWAYS)
                redis_fsync(newfd);
            else if (server.aof_fsync == AOF_FSYNC_EVERYSEC)
                aof_background_fsync(newfd);
            server.aof_selected_db = -1; /* Make sure SELECT is re-issued */
            aofUpdateCurrentSize();
            server.aof_rewrite_base_size = server.aof_current_size;
            server.aof_current_size = server.aof_current_size;

            /* Clear regular AOF buffer since its contents was just written to
             * the new AOF from the background rewrite buffer. */
            sdsfree(server.aof_buf);
            server.aof_buf = sdsempty();
        }

        server.aof_lastbgrewrite_status = C_OK;

        serverLog(LL_NOTICE, "Background AOF rewrite finished successfully");
        /* Change state from WAIT_REWRITE to ON if needed */
        if (server.aof_state == AOF_WAIT_REWRITE)
            server.aof_state = AOF_ON;

        /* Asynchronously close the overwritten AOF. */
        if (oldfd != -1) bioCreateBackgroundJob(BIO_CLOSE_FILE,(void*)(long)oldfd,NULL,NULL);

        serverLog(LL_VERBOSE,
            "Background AOF rewrite signal handler took %lldus", ustime()-now);
    } else if (!bysignal && exitcode != 0) {
        /* SIGUSR1 is whitelisted, so we have a way to kill a child without
         * tirggering an error condition. */
        if (bysignal != SIGUSR1)
            server.aof_lastbgrewrite_status = C_ERR;
        serverLog(LL_WARNING,
            "Background AOF rewrite terminated with error");
    } else {
        server.aof_lastbgrewrite_status = C_ERR;

        serverLog(LL_WARNING,
            "Background AOF rewrite terminated by signal %d", bysignal);
    }

cleanup:
    aofClosePipes();
    aofRewriteBufferReset();
    aofRemoveTempFile(server.aof_child_pid);
    server.aof_child_pid = -1;
    server.aof_rewrite_time_last = time(NULL)-server.aof_rewrite_time_start;
    server.aof_rewrite_time_start = -1;
    /* Schedule a new rewrite if we are waiting for it to switch the AOF ON. */
    if (server.aof_state == AOF_WAIT_REWRITE)
        server.aof_rewrite_scheduled = 1;
}
```






