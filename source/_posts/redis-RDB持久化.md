---
title: redis-RDB持久化
tags: [redis,RDB,]
comments: true
categories: [redis设计与实现]
date: 2019-09-18 20:47:08
---

### RDB文件的创建和载入

SAVE阻塞Redis服务器进程，直到RDB文件创建完毕，阻塞期间不能处理任何命令请求。BGSAVE派生一个子进程，由子进程负责创建RDB文件，服务器进程继续处理命令请求。

rdb.c：

```
/* Save the DB on disk. Return C_ERR on error, C_OK on success. */
int rdbSave(char *filename, rdbSaveInfo *rsi) {
    char tmpfile[256];
    char cwd[MAXPATHLEN]; /* Current working dir path for error messages. */
    FILE *fp;
    rio rdb;
    int error = 0;

    snprintf(tmpfile,256,"temp-%d.rdb", (int) getpid());
    fp = fopen(tmpfile,"w");
    if (!fp) {
        char *cwdp = getcwd(cwd,MAXPATHLEN);
        serverLog(LL_WARNING,
            "Failed opening the RDB file %s (in server root dir %s) "
            "for saving: %s",
            filename,
            cwdp ? cwdp : "unknown",
            strerror(errno));
        return C_ERR;
    }

    rioInitWithFile(&rdb,fp);

    if (server.rdb_save_incremental_fsync)
        rioSetAutoSync(&rdb,REDIS_AUTOSYNC_BYTES);

    if (rdbSaveRio(&rdb,&error,RDB_SAVE_NONE,rsi) == C_ERR) {
        errno = error;
        goto werr;
    }

    /* Make sure data will not remain on the OS's output buffers */
    if (fflush(fp) == EOF) goto werr;
    if (fsync(fileno(fp)) == -1) goto werr;
    if (fclose(fp) == EOF) goto werr;

    /* Use RENAME to make sure the DB file is changed atomically only
     * if the generate DB file is ok. */
    if (rename(tmpfile,filename) == -1) {
        char *cwdp = getcwd(cwd,MAXPATHLEN);
        serverLog(LL_WARNING,
            "Error moving temp DB file %s on the final "
            "destination %s (in server root dir %s): %s",
            tmpfile,
            filename,
            cwdp ? cwdp : "unknown",
            strerror(errno));
        unlink(tmpfile);
        return C_ERR;
    }

    serverLog(LL_NOTICE,"DB saved on disk");
    server.dirty = 0;
    server.lastsave = time(NULL);
    server.lastbgsave_status = C_OK;
    return C_OK;

werr:
    serverLog(LL_WARNING,"Write error saving DB on disk: %s", strerror(errno));
    fclose(fp);
    unlink(tmpfile);
    return C_ERR;
}

int rdbSaveBackground(char *filename, rdbSaveInfo *rsi) {
    pid_t childpid;
    long long start;

    if (server.aof_child_pid != -1 || server.rdb_child_pid != -1) return C_ERR;

    server.dirty_before_bgsave = server.dirty;
    server.lastbgsave_try = time(NULL);
    openChildInfoPipe();

    start = ustime();
    if ((childpid = fork()) == 0) {
        int retval;

        /* Child */
        closeListeningSockets(0);
        redisSetProcTitle("redis-rdb-bgsave");
        retval = rdbSave(filename,rsi);
        if (retval == C_OK) {
            size_t private_dirty = zmalloc_get_private_dirty(-1);

            if (private_dirty) {
                serverLog(LL_NOTICE,
                    "RDB: %zu MB of memory used by copy-on-write",
                    private_dirty/(1024*1024));
            }

            server.child_info_data.cow_size = private_dirty;
            sendChildInfo(CHILD_INFO_TYPE_RDB);
        }
        exitFromChild((retval == C_OK) ? 0 : 1);
    } else {
        /* Parent */
        server.stat_fork_time = ustime()-start;
        server.stat_fork_rate = (double) zmalloc_used_memory() * 1000000 / server.stat_fork_time / (1024*1024*1024); /* GB per second. */
        latencyAddSampleIfNeeded("fork",server.stat_fork_time/1000);
        if (childpid == -1) {
            closeChildInfoPipe();
            server.lastbgsave_status = C_ERR;
            serverLog(LL_WARNING,"Can't save in background: fork: %s",
                strerror(errno));
            return C_ERR;
        }
        serverLog(LL_NOTICE,"Background saving started by pid %d",childpid);
        server.rdb_save_time_start = time(NULL);
        server.rdb_child_pid = childpid;
        server.rdb_child_type = RDB_CHILD_TYPE_DISK;
        updateDictResizePolicy();
        return C_OK;
    }
    return C_OK; /* unreached */
}

...

void saveCommand(client *c) {
    if (server.rdb_child_pid != -1) {
        addReplyError(c,"Background save already in progress");
        return;
    }
    rdbSaveInfo rsi, *rsiptr;
    rsiptr = rdbPopulateSaveInfo(&rsi);
    if (rdbSave(server.rdb_filename,rsiptr) == C_OK) {
        addReply(c,shared.ok);
    } else {
        addReply(c,shared.err);
    }
}

/* BGSAVE [SCHEDULE] */
void bgsaveCommand(client *c) {
    int schedule = 0;

    /* The SCHEDULE option changes the behavior of BGSAVE when an AOF rewrite
     * is in progress. Instead of returning an error a BGSAVE gets scheduled. */
    if (c->argc > 1) {
        if (c->argc == 2 && !strcasecmp(c->argv[1]->ptr,"schedule")) {
            schedule = 1;
        } else {
            addReply(c,shared.syntaxerr);
            return;
        }
    }

    rdbSaveInfo rsi, *rsiptr;
    rsiptr = rdbPopulateSaveInfo(&rsi);

    if (server.rdb_child_pid != -1) {
        addReplyError(c,"Background save already in progress");
    } else if (server.aof_child_pid != -1) {
        if (schedule) {
            server.rdb_bgsave_scheduled = 1;
            addReplyStatus(c,"Background saving scheduled");
        } else {
            addReplyError(c,
                "An AOF log rewriting in progress: can't BGSAVE right now. "
                "Use BGSAVE SCHEDULE in order to schedule a BGSAVE whenever "
                "possible.");
        }
    } else if (rdbSaveBackground(server.rdb_filename,rsiptr) == C_OK) {
        addReplyStatus(c,"Background saving started");
    } else {
        addReply(c,shared.err);
    }
}
```

注释即文档，很清楚。不会同时执行SAVE和BGSAVE命令以及多个BGSAVE命令，不会同时执行BGSAVE和BGREWRITEAOF。若正在执行BGSAVE，则BGREWRITEAOF延迟到BGSAVE命令执行完毕后执行，若正在执行BGREWRITEAOF命令，则BGSAVE被拒绝。

服务启动时，检测到RDB文件存在，就会自动载入RDB文件。若开启AOF持久化功能，会优先使用AOF文件来还原数据库状态，AOF持久化功能关闭时，才使用RDB文件还原数据库状态。

```
/* Like rdbLoadRio() but takes a filename instead of a rio stream. The
 * filename is open for reading and a rio stream object created in order
 * to do the actual loading. Moreover the ETA displayed in the INFO
 * output is initialized and finalized.
 *
 * If you pass an 'rsi' structure initialied with RDB_SAVE_OPTION_INIT, the
 * loading code will fiil the information fields in the structure. */
int rdbLoad(char *filename, rdbSaveInfo *rsi) {
    FILE *fp;
    rio rdb;
    int retval;

    if ((fp = fopen(filename,"r")) == NULL) return C_ERR;
    startLoadingFile(fp, filename);
    rioInitWithFile(&rdb,fp);
    retval = rdbLoadRio(&rdb,rsi,0);
    fclose(fp);
    stopLoading();
    return retval;
}
```

redis.conf中设置save，让服务器每隔一段时间自动执行一次BGSAVE命令。


```
################################ SNAPSHOTTING  ################################
#
# Save the DB on disk:
#
#   save <seconds> <changes>
#
#   Will save the DB if both the given number of seconds and the given
#   number of write operations against the DB occurred.
#
#   In the example below the behaviour will be to save:
#   after 900 sec (15 min) if at least 1 key changed
#   after 300 sec (5 min) if at least 10 keys changed
#   after 60 sec if at least 10000 keys changed
#
#   Note: you can disable saving completely by commenting out all "save" lines.
#
#   It is also possible to remove all the previously configured save
#   points by adding a save directive with a single empty string argument
#   like in the following example:
#
#   save ""

save 900 1
save 300 10
save 60 10000
```


启动时根据save选项设置:

```
struct saveparam {
    time_t seconds;
    int changes;
};

struct redisServer {
	 ...
	 struct saveparam *saveparams;   /* Save points array for RDB */
	 ...
	 /* RDB persistence */
    long long dirty;                /* Changes to DB from the last save */
    long long dirty_before_bgsave;  /* Used to restore dirty on failed BGSAVE */
    pid_t rdb_child_pid;            /* PID of RDB saving child */
    struct saveparam *saveparams;   /* Save points array for RDB */
    int saveparamslen;              /* Number of saving points */
    char *rdb_filename;             /* Name of RDB file */
    int rdb_compression;            /* Use compression in RDB? */
    int rdb_checksum;               /* Use RDB checksum? */
    time_t lastsave;                /* Unix time of last successful save */
    time_t lastbgsave_try;          /* Unix time of last attempted bgsave */
    time_t rdb_save_time_last;      /* Time used by last RDB save run. */
    time_t rdb_save_time_start;     /* Current RDB save start time. */
    int rdb_bgsave_scheduled;       /* BGSAVE when possible if true. */
    int rdb_child_type;             /* Type of save by active child. */
    int lastbgsave_status;          /* C_OK or C_ERR */
    int stop_writes_on_bgsave_err;  /* Don't allow writes if can't BGSAVE */
    int rdb_pipe_write_result_to_parent; /* RDB pipes used to return the state*/
    int rdb_pipe_read_result_from_child; /* of each slave in diskless SYNC. */
    int rdb_key_save_delay;         /* Delay in microseconds between keys while
	 ...
}
```



### RDB文件结构

位于redis.conf下dir配置的文件目录下，默认名dump.rdb，[vi二进制转码](https://blog.csdn.net/yuanya/article/details/24406357)或是用od命令查看：

```
00000000: 5245 4449 5330 3030 38fa 0972 6564 6973  REDIS0008..redis
00000010: 2d76 6572 0634 2e30 2e31 30fa 0a72 6564  -ver.4.0.10..red
00000020: 6973 2d62 6974 73c0 40fa 0563 7469 6d65  is-bits.@..ctime 
00000030: c272 3083 5dfa 0875 7365 642d 6d65 6dc2  .r0.]..used-mem.
00000040: 4045 1000 fa0c 616f 662d 7072 6561 6d62  @E....aof-preamb
00000050: 6c65 c000 fe00 fb08 000e 0b6d 6169 6c65  le.........maile
00000060: 723a 6c69 7374 01c3 40fa 4699 0499 0600  r:list..@.F.....
00000070: 0023 2003 1f0e 0000 4075 7b22 7375 626a  .# .....@u{"subj
00000080: 6563 7422 3a22 e998 bfe6 b3a2 e7bd 97e7  ect":"..........
00000090: 99bb e69c 8814 e8ae a1e5 8892 222c 2265  ............","e
000000a0: 6d61 696c 4164 6472 6573 7320 260f 3630  mailAddress &.60
000000b0: 3936 3639 3938 3340 7171 2e63 6f6d 2021  9669983@qq.com !
000000c0: 0362 6f64 7920 190e e688 91e4 b88d e7ae  .body ..........
000000d0: a12c e7be a4e4 b820 4406 80e5 b885 2e20  .,..... D...... 
000000e0: 2d40 000b 6279 2063 6f63 6f77 6822 7d78  -@..by cocowh"}x
000000f0: e02c 7706 3232 3839 3434 38e0 3477 0076  .,w.2289448.4w.v
00000100: e02a ef09 3234 3939 3436 3638 3134 e030  .*..2499466814.0
00000110: f000 79e0 2cf0 0439 3633 3737 20f2 0037  ..y.,..96377 ..7
00000120: e030 77e1 2d68 0833 3134 3836 3534 3031  .0w.-h.314865401
00000130: e032 77e1 2b68 0631 3130 3738 3930 216e  .2w.+h.1107890!n
00000140: e030 7802 7940 72e1 2ae1 8297 e030 7400  .0x.y@r.*....0t.
00000150: 75e1 2cdd e3ff 46e4 2237 e3ff 46e5 159f  u.,...F."7..F...
00000160: e3ae 4601 7dff 0c08 7a73 6574 7465 7374  ..F.}...zsettest
00000170: 1717 0000 0013 0000 0002 0000 076d 656d  .............mem
00000180: 6265 7231 09fe 64ff 0009 7374 7269 6e67  ber1..d...string
00000190: 6b65 79c1 9001 0c08 7465 7374 7a73 6574  key.....testzset
000001a0: c333 3b04 3b00 0000 3820 030a 0c00 0004  .3;.;...8 ......
000001b0: 6d65 6d36 06f6 0240 0702 3506 f760 0702  mem6...@..5..`..
000001c0: 3406 f860 0702 3306 f960 0702 3206 fa60  4..`..3..`..2..`
000001d0: 0703 3106 fbff 0002 6869 c26a 0401 000e  ..1.....hi.j....
000001e0: 046c 6973 7401 1111 0000 000e 0000 0003  .list...........
000001f0: 0000 f402 f302 f2ff 0e03 6c73 7401 2525  ..........lst.%%
00000200: 0000 001b 0000 0006 0000 f202 f402 f602  ................
00000210: c066 2704 0577 7568 7561 0707 6c69 7765  .f'..wuhua..liwe
00000220: 6e71 69ff 0d08 6874 6573 746b 6579 2323  nqi...htestkey##
00000230: 0000 0020 0000 0004 0000 0666 696c 6564  ... .......filed
00000240: 3108 0476 616c 3106 066b 6579 6164 6408  1..val1..keyadd.
00000250: f4ff ff18 8e2b 7151 f9f0 680a            .....+qQ..h.
```

```
wuhua:redis wuhua$ od -c dump.rdb 
0000000    R   E   D   I   S   0   0   0   8 372  \t   r   e   d   i   s
0000020    -   v   e   r 006   4   .   0   .   1   0 372  \n   r   e   d
0000040    i   s   -   b   i   t   s 300   @ 372 005   c   t   i   m   e
0000060  302   r   0 203   ] 372  \b   u   s   e   d   -   m   e   m 100
0000100    @   E 020  \0 372  \f   a   o   f   -   p   r   e   a   m   b
0000120    l   e 300  \0 376  \0 373  \b  \0 016  \v   m   a   i   l   e
0000140    r   :   l   i   s   t 001 303   @ 372   F 231 004 231 006  \0
0000160   \0   #     003 037 016  \0  \0   @   u   {   "   s   u   b   j
0000200    e   c   t   "   :   "  阿  **  **  波  **  **  罗  **  **  登
0000220   **  **  月  **  ** 024  计  **  **  划  **  **   "   ,   "   e
0000240    m   a   i   l   A   d   d   r   e   s   s       & 017   6   0
0000260    9   6   6   9   9   8   3   @   q   q   .   c   o   m       !
0000300  003   b   o   d   y     031 016  我  **  **  不  **  **  管  **
0000320   **   ,  群  **  ** 344 270       D 006 200  帅  **  **   .    
0000340    -   @  \0  \v   b   y       c   o   c   o   w   h   "   }   x
0000360  340   ,   w 006   2   2   8   9   4   4   8 340   4   w  \0   v
0000400  340   * 357  \t   2   4   9   9   4   6   6   8   1   4 340   0
0000420  360  \0   y 340   , 360 004   9   6   3   7   7     362  \0   7
0000440  340   0   w 341   -   h  \b   3   1   4   8   6   5   4   0   1
0000460  340   2   w 341   +   h 006   1   1   0   7   8   9   0   !   n
0000500  340   0   x 002   y   @   r 341   * 341 202 227 340   0   t  \0
0000520    u 341   , 335 343 377   F 344   "   7 343 377   F 345 025 237
0000540  343 256   F 001   } 377  \f  \b   z   s   e   t   t   e   s   t
0000560  027 027  \0  \0  \0 023  \0  \0  \0 002  \0  \0  \a   m   e   m
0000600    b   e   r   1  \t 376   d 377  \0  \t   s   t   r   i   n   g
0000620    k   e   y 301 220 001  \f  \b   t   e   s   t   z   s   e   t
0000640  303   3   ; 004   ;  \0  \0  \0   8     003  \n  \f  \0  \0 004
0000660    m   e   m   6 006 366 002   @  \a 002   5 006 367   `  \a 002
0000700    4 006 370   `  \a 002   3 006 371   `  \a 002   2 006 372   `
0000720   \a 003   1 006 373 377  \0 002   h   i 302   j 004 001  \0 016
0000740  004   l   i   s   t 001 021 021  \0  \0  \0 016  \0  \0  \0 003
0000760   \0  \0 364 002 363 002 362 377 016 003   l   s   t 001   %   %
0001000   \0  \0  \0 033  \0  \0  \0 006  \0  \0 362 002 364 002 366 002
0001020  300   f   ' 004 005   w   u   h   u   a  \a  \a   l   i   w   e
0001040    n   q   i 377  \r  \b   h   t   e   s   t   k   e   y   #   #
0001060   \0  \0  \0      \0  \0  \0 004  \0  \0 006   f   i   l   e   d
0001100    1  \b 004   v   a   l   1 006 006   k   e   y   a   d   d  \b
0001120  364 377 377 030 216   +   q   Q 371 360   h                    
0001133
```

直接使用redis-check-rdb快照检查工具(已编译进redis，直接使用)查看：

```
wuhua:redis wuhua$ redis-check-rdb dump.rdb
[offset 0] Checking RDB file dump.rdb              
[offset 27] AUX FIELD redis-ver = '4.0.10'     //redis事例版本
[offset 41] AUX FIELD redis-bits = '64'        //redis事例主机架构
[offset 53] AUX FIELD ctime = '1568878706'     //rdb创建时unix时间戳
[offset 68] AUX FIELD used-mem = '1066304'     //转存时使用的内存大小
[offset 84] AUX FIELD aof-preamble = '0'       //是否在AOF文件头放置RDB快照（开启混合持久化）   
[offset 86] Selecting DB ID 0                  //DB索引
[offset 603] Checksum OK                       //检验信息
[offset 603] \o/ RDB looks OK! \o/
[info] 8 keys read
[info] 0 expires
[info] 0 already expired
```

使用[redis-rdb-tools](https://github.com/sripathikrishnan/redis-rdb-tools)工具查看内容：

```
wuhua:redis wuhua$ rdb --command json dump.rdb 
[{
"mailer:list":["{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"609669983@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"228944883@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"2499466814@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"963779447@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"314865401@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"1107890499@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"cocowh@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"609669983@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"228944883@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"2499466814@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"963779447@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"314865401@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"1107890499@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}","{\"subject\":\"\u963f\u6ce2\u7f57\u767b\u6708\u8ba1\u5212\",\"emailAddress\":\"cocowh@qq.com\",\"body\":\"\u6211\u4e0d\u7ba1,\u7fa4\u4e3b\u6700\u5e05. -----by cocowh\"}"],
"zsettest":{"member1":"100"},
"stringkey":"400",
"testzset":{"mem6":"5","mem5":"6","mem4":"7","mem3":"8","mem2":"9","mem1":"10"},
"hi":"66666",
"list":["3","2","1"],
"lst":["1","3","5","10086","wuhua","liwenqi"],
"htestkey":{"filed1":"val1","keyadd":"3"}}]wuhua:redis wuhua$ 
```



