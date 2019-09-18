---
title: redis-数据库
tags: [redis,db]
comments: true
categories: [redis设计与实现]
date: 2019-09-18 16:30:49
---

### 服务器中的数据库

保存于服务器状态server.h/redisServer结构db数组中。每一项都是一个server.h/redisDb结构，代表一个数据库。初始化服务时根据服务器状态的dbnum属性决定创建多少个数据库，改值由服务器配置的database选项决定。

```
struct redisServer {
	 ...
    redisDb *db;
    ...
    int dbnum;                      /* Total number of configured DBs */
	 ...
}

/* Redis database representation. There are multiple databases identified
 * by integers from 0 (the default database) up to the max configured
 * database. The database number is the 'id' field in the structure. */
typedef struct redisDb {
    dict *dict;                 /* The keyspace for this DB */
    dict *expires;              /* Timeout of keys with a timeout set */
    dict *blocking_keys;        /* Keys with clients waiting for data (BLPOP)*/
    dict *ready_keys;           /* Blocked keys that received a PUSH */
    dict *watched_keys;         /* WATCHED keys for MULTI/EXEC CAS */
    int id;                     /* Database ID */
    long long avg_ttl;          /* Average TTL, just for stats */
    list *defrag_later;         /* List of key names to attempt to defrag one by one, gradually. */
} redisDb;
```

配置项：

```
# Set the number of databases. The default database is DB 0, you can select
# a different one on a per-connection basis using SELECT <dbid> where
# dbid is a number between 0 and 'databases'-1
databases 16
```


### 切换数据库

`SELECT`命令切换，server.h/redisClient结构的db属性记录了客户端当前的目标数据库：

```
/* With multiplexing we need to take per-client state.
 * Clients are taken in a linked list. */
typedef struct client {
	 ...
    redisDb *db;            /* Pointer to currently SELECTed DB. */
	 ...
}
```

### 数据库键空间

每个数据库由server.h/redisDb结构表示，redisDb结构的dict字典保存了数据库中的所有键值对，成为键空间（keyspace）。

```
/* Redis database representation. There are multiple databases identified
 * by integers from 0 (the default database) up to the max configured
 * database. The database number is the 'id' field in the structure. */
typedef struct redisDb {
    dict *dict;                 /* The keyspace for this DB */
    dict *expires;              /* Timeout of keys with a timeout set */
    dict *blocking_keys;        /* Keys with clients waiting for data (BLPOP)*/
    dict *ready_keys;           /* Blocked keys that received a PUSH */
    dict *watched_keys;         /* WATCHED keys for MULTI/EXEC CAS */
    int id;                     /* Database ID */
    long long avg_ttl;          /* Average TTL, just for stats */
    list *defrag_later;         /* List of key names to attempt to defrag one by one, gradually. */
} redisDb;
```

针对数据库的操作，实际是通过键空间字典进行操作实现。

对数据库进行读写操作时，除对键空间执行指定的读写操作外（读操作和写操作都要对键进行读取），还会执行一些的维护操作：

* 根据键是否存在更新服务器的键空间命中（hit）次数或键空间不命中（miss）次数，可在INFO stats命令的keyspace\_hits属性和keyspace\_misses属性中查看。
* 更新键的LRU（最后一次使用时间），用于计算键的闲置时间。
* 发现键过期则删除过期键，然后执行余下的其他操作。
* 若有客户端使用WATCH命令监视某个键，则对被监视的键修改之后，会将键标记为脏（dirty），让事务程序注意到键已经被修改。
* 每次修改一个键都会对脏（dirty）键计数器的值增1，计数器触发服务器的持久化以及复制操作。
* 若服务器开启数据库通知功能，则在对键进行修改之后，按配置发送相应的数据库通知。

### 设置键的生存时间和过期时间

`EXPIRE`和`PEXPIRE`命令，以秒或毫秒为数据库中的某个键设置生存时间（Time To Live，TTL），指定时间过后，服务器自动删除生存时间为0的键。

`EXPIREAT`和`PEXPIREAT`命令，以秒或毫秒给数据库中的某个键设置过期时间（expire），过期时间是unix时间戳，过期时间来临时，服务器自动删除键。

`SETEX`命令可为一个字符串键设置值的同时设置过期时间，原理同`EXPIRE `。

`TTL`和`PTTL`接受一个带有生存时间或过期时间的键，返回这个键的剩余生存时间。

实际上`EXPIRE`、`PEXPIRE`、`EXPIREAT`、`PEXPIREAT`命令底层实现统一。
server.h中定义：

```
void expireCommand(client *c);
void expireatCommand(client *c);
void pexpireCommand(client *c);
void pexpireatCommand(client *c);
```

server.c/redisCommandTable中命令注册绑定：

```
 ...
 {"expire",expireCommand,3,
 "write fast @keyspace",
 0,NULL,1,1,1,0,0,0},

{"expireat",expireatCommand,3,
 "write fast @keyspace",
 0,NULL,1,1,1,0,0,0},

{"pexpire",pexpireCommand,3,
 "write fast @keyspace",
 0,NULL,1,1,1,0,0,0},

{"pexpireat",pexpireatCommand,3,
 "write fast @keyspace",
 0,NULL,1,1,1,0,0,0},
 ...
```

expire.c中实现：

```

/*-----------------------------------------------------------------------------
 * Expires Commands
 *----------------------------------------------------------------------------*/

/* This is the generic command implementation for EXPIRE, PEXPIRE, EXPIREAT
 * and PEXPIREAT. Because the commad second argument may be relative or absolute
 * the "basetime" argument is used to signal what the base time is (either 0
 * for *AT variants of the command, or the current time for relative expires).
 *
 * unit is either UNIT_SECONDS or UNIT_MILLISECONDS, and is only used for
 * the argv[2] parameter. The basetime is always specified in milliseconds. */
void expireGenericCommand(client *c, long long basetime, int unit) {
    robj *key = c->argv[1], *param = c->argv[2];
    long long when; /* unix time in milliseconds when the key will expire. */

    if (getLongLongFromObjectOrReply(c, param, &when, NULL) != C_OK)
        return;

    if (unit == UNIT_SECONDS) when *= 1000;
    when += basetime;

    /* No key, return zero. */
    if (lookupKeyWrite(c->db,key) == NULL) {
        addReply(c,shared.czero);
        return;
    }

    /* EXPIRE with negative TTL, or EXPIREAT with a timestamp into the past
     * should never be executed as a DEL when load the AOF or in the context
     * of a slave instance.
     *
     * Instead we take the other branch of the IF statement setting an expire
     * (possibly in the past) and wait for an explicit DEL from the master. */
    if (when <= mstime() && !server.loading && !server.masterhost) {
        robj *aux;

        int deleted = server.lazyfree_lazy_expire ? dbAsyncDelete(c->db,key) :
                                                    dbSyncDelete(c->db,key);
        serverAssertWithInfo(c,key,deleted);
        server.dirty++;

        /* Replicate/AOF this as an explicit DEL or UNLINK. */
        aux = server.lazyfree_lazy_expire ? shared.unlink : shared.del;
        rewriteClientCommandVector(c,2,aux,key);
        signalModifiedKey(c->db,key);
        notifyKeyspaceEvent(NOTIFY_GENERIC,"del",key,c->db->id);
        addReply(c, shared.cone);
        return;
    } else {
        setExpire(c,c->db,key,when);
        addReply(c,shared.cone);
        signalModifiedKey(c->db,key);
        notifyKeyspaceEvent(NOTIFY_GENERIC,"expire",key,c->db->id);
        server.dirty++;
        return;
    }
}

/* EXPIRE key seconds */
void expireCommand(client *c) {
    expireGenericCommand(c,mstime(),UNIT_SECONDS);
}

/* EXPIREAT key time */
void expireatCommand(client *c) {
    expireGenericCommand(c,0,UNIT_SECONDS);
}

/* PEXPIRE key milliseconds */
void pexpireCommand(client *c) {
    expireGenericCommand(c,mstime(),UNIT_MILLISECONDS);
}

/* PEXPIREAT key ms_time */
void pexpireatCommand(client *c) {
    expireGenericCommand(c,0,UNIT_MILLISECONDS);
}
```

### 保存/移除过期时间
redisDb结构的expires字典保存数据库中所有键的过期时间，过期字典：

* 过期字典的键是一个指针，指向键空间中的某个键对象；
* 过期字典的值是为long long int型，保存键所指向的数据库键的过期时间——毫秒精度的UNIX时间戳。

设置过期时间时，会在过期字典中关联给定的数据库键和过期时间。使用PERSIST命令移除过期时间：

```
127.0.0.1:6379> ttl hi
(integer) -1
127.0.0.1:6379> expire hi 1000
(integer) 1
127.0.0.1:6379> ttl hi
(integer) 998
127.0.0.1:6379> persist hi
(integer) 1
127.0.0.1:6379> ttl hi
(integer) -1
```

PERSIST命令是PEXPIREAT命令的反操作，在过期字典中查找给定的键，并解除键和值（过期时间）在过期字典中的关联。

```
/* PERSIST key */
void persistCommand(client *c) {
    if (lookupKeyWrite(c->db,c->argv[1])) {
        if (removeExpire(c->db,c->argv[1])) {
            addReply(c,shared.cone);
            server.dirty++;
        } else {
            addReply(c,shared.czero);
        }
    } else {
        addReply(c,shared.czero);
    }
}
```


### 计算并返回剩余生存时间

TTL和PTTL都是通过计算键的过期时间和当前时间之间的差来实现。

```
/* Implements TTL and PTTL */
void ttlGenericCommand(client *c, int output_ms) {
    long long expire, ttl = -1;

    /* If the key does not exist at all, return -2 */
    if (lookupKeyReadWithFlags(c->db,c->argv[1],LOOKUP_NOTOUCH) == NULL) {
        addReplyLongLong(c,-2);
        return;
    }
    /* The key exists. Return -1 if it has no expire, or the actual
     * TTL value otherwise. */
    expire = getExpire(c->db,c->argv[1]);
    if (expire != -1) {
        ttl = expire-mstime();
        if (ttl < 0) ttl = 0;
    }
    if (ttl == -1) {
        addReplyLongLong(c,-1);
    } else {
        addReplyLongLong(c,output_ms ? ttl : ((ttl+500)/1000));
    }
}

/* TTL key */
void ttlCommand(client *c) {
    ttlGenericCommand(c, 0);
}

/* PTTL key */
void pttlCommand(client *c) {
    ttlGenericCommand(c, 1);
}
```

### 过期键的判定

通过过期字典，检查：

* 检查给定键是否存在于过期字典：若存在，取得键的过期时间。
* 检查当前UNIX时间戳是否大于键的过期时间：若是，则键已经过期，否则未过期。

### 过期键删除策略

* 定时删除。设置键的过期时间的同时，创建一个定时器，定时器在过期时间到来时，立即执行对键的删除操作。
* 惰性删除。每次从键空间获取键时，检查键是否过期，若是则删除该键。
* 定期删除。每个一段时间，对数据库进行一次检查，删除里面的过期键。

创建定时器会用到时间事件，实现方式为无序链表，查找时间复杂度为O(N)，不能高效处理大量时间事件。

惰性删除会导致不被访问的键永远无法被删除，导致内存泄漏，除非用户手动执行FLUSHDB。

Redis使用惰性删除和定期删除两种策略。惰性删除策略由db.c/expireIfNeeded函数实现，见注释：

```
/* This function is called when we are going to perform some operation
 * in a given key, but such key may be already logically expired even if
 * it still exists in the database. The main way this function is called
 * is via lookupKey*() family of functions.
 *
 * The behavior of the function depends on the replication role of the
 * instance, because slave instances do not expire keys, they wait
 * for DELs from the master for consistency matters. However even
 * slaves will try to have a coherent return value for the function,
 * so that read commands executed in the slave side will be able to
 * behave like if the key is expired even if still present (because the
 * master has yet to propagate the DEL).
 *
 * In masters as a side effect of finding a key which is expired, such
 * key will be evicted from the database. Also this may trigger the
 * propagation of a DEL/UNLINK command in AOF / replication stream.
 *
 * The return value of the function is 0 if the key is still valid,
 * otherwise the function returns 1 if the key is expired. */
int expireIfNeeded(redisDb *db, robj *key) {
    if (!keyIsExpired(db,key)) return 0;

    /* If we are running in the context of a slave, instead of
     * evicting the expired key from the database, we return ASAP:
     * the slave key expiration is controlled by the master that will
     * send us synthesized DEL operations for expired keys.
     *
     * Still we try to return the right information to the caller,
     * that is, 0 if we think the key should be still valid, 1 if
     * we think the key is expired at this time. */
    if (server.masterhost != NULL) return 1;

    /* Delete the key */
    server.stat_expiredkeys++;
    propagateExpire(db,key,server.lazyfree_lazy_expire);
    notifyKeyspaceEvent(NOTIFY_EXPIRED,
        "expired",key,db->id);
    return server.lazyfree_lazy_expire ? dbAsyncDelete(db,key) :
                                         dbSyncDelete(db,key);
}
```

过期键定时删除策略由redis.h中定义，expire.c中实现，每当redis的服务器周期性操作redis.c/serverCron函数执行时，在其内部调用的databasesCron函数调用activeExpireCycle函数。

```
/* Try to expire a few timed out keys. The algorithm used is adaptive and
 * will use few CPU cycles if there are few expiring keys, otherwise
 * it will get more aggressive to avoid that too much memory is used by
 * keys that can be removed from the keyspace.
 *
 * No more than CRON_DBS_PER_CALL databases are tested at every
 * iteration.
 *
 * This kind of call is used when Redis detects that timelimit_exit is
 * true, so there is more work to do, and we do it more incrementally from
 * the beforeSleep() function of the event loop.
 *
 * Expire cycle type:
 *
 * If type is ACTIVE_EXPIRE_CYCLE_FAST the function will try to run a
 * "fast" expire cycle that takes no longer than EXPIRE_FAST_CYCLE_DURATION
 * microseconds, and is not repeated again before the same amount of time.
 *
 * If type is ACTIVE_EXPIRE_CYCLE_SLOW, that normal expire cycle is
 * executed, where the time limit is a percentage of the REDIS_HZ period
 * as specified by the ACTIVE_EXPIRE_CYCLE_SLOW_TIME_PERC define. */

void activeExpireCycle(int type) {
    /* This function has some global state in order to continue the work
     * incrementally across calls. */
    static unsigned int current_db = 0; /* Last DB tested. */
    static int timelimit_exit = 0;      /* Time limit hit in previous call? */
    static long long last_fast_cycle = 0; /* When last fast cycle ran. */

    int j, iteration = 0;
    int dbs_per_call = CRON_DBS_PER_CALL;
    long long start = ustime(), timelimit, elapsed;

    /* When clients are paused the dataset should be static not just from the
     * POV of clients not being able to write, but also from the POV of
     * expires and evictions of keys not being performed. */
    if (clientsArePaused()) return;

    if (type == ACTIVE_EXPIRE_CYCLE_FAST) {
        /* Don't start a fast cycle if the previous cycle did not exit
         * for time limit. Also don't repeat a fast cycle for the same period
         * as the fast cycle total duration itself. */
        if (!timelimit_exit) return;
        if (start < last_fast_cycle + ACTIVE_EXPIRE_CYCLE_FAST_DURATION*2) return;
        last_fast_cycle = start;
    }

    /* We usually should test CRON_DBS_PER_CALL per iteration, with
     * two exceptions:
     *
     * 1) Don't test more DBs than we have.
     * 2) If last time we hit the time limit, we want to scan all DBs
     * in this iteration, as there is work to do in some DB and we don't want
     * expired keys to use memory for too much time. */
    if (dbs_per_call > server.dbnum || timelimit_exit)
        dbs_per_call = server.dbnum;

    /* We can use at max ACTIVE_EXPIRE_CYCLE_SLOW_TIME_PERC percentage of CPU time
     * per iteration. Since this function gets called with a frequency of
     * server.hz times per second, the following is the max amount of
     * microseconds we can spend in this function. */
    timelimit = 1000000*ACTIVE_EXPIRE_CYCLE_SLOW_TIME_PERC/server.hz/100;
    timelimit_exit = 0;
    if (timelimit <= 0) timelimit = 1;

    if (type == ACTIVE_EXPIRE_CYCLE_FAST)
        timelimit = ACTIVE_EXPIRE_CYCLE_FAST_DURATION; /* in microseconds. */

    /* Accumulate some global stats as we expire keys, to have some idea
     * about the number of keys that are already logically expired, but still
     * existing inside the database. */
    long total_sampled = 0;
    long total_expired = 0;

    for (j = 0; j < dbs_per_call && timelimit_exit == 0; j++) {
        int expired;
        redisDb *db = server.db+(current_db % server.dbnum);

        /* Increment the DB now so we are sure if we run out of time
         * in the current DB we'll restart from the next. This allows to
         * distribute the time evenly across DBs. */
        current_db++;

        /* Continue to expire if at the end of the cycle more than 25%
         * of the keys were expired. */
        do {
            unsigned long num, slots;
            long long now, ttl_sum;
            int ttl_samples;
            iteration++;

            /* If there is nothing to expire try next DB ASAP. */
            if ((num = dictSize(db->expires)) == 0) {
                db->avg_ttl = 0;
                break;
            }
            slots = dictSlots(db->expires);
            now = mstime();

            /* When there are less than 1% filled slots getting random
             * keys is expensive, so stop here waiting for better times...
             * The dictionary will be resized asap. */
            if (num && slots > DICT_HT_INITIAL_SIZE &&
                (num*100/slots < 1)) break;

            /* The main collection cycle. Sample random keys among keys
             * with an expire set, checking for expired ones. */
            expired = 0;
            ttl_sum = 0;
            ttl_samples = 0;

            if (num > ACTIVE_EXPIRE_CYCLE_LOOKUPS_PER_LOOP)
                num = ACTIVE_EXPIRE_CYCLE_LOOKUPS_PER_LOOP;

            while (num--) {
                dictEntry *de;
                long long ttl;

                if ((de = dictGetRandomKey(db->expires)) == NULL) break;
                ttl = dictGetSignedIntegerVal(de)-now;
                if (activeExpireCycleTryExpire(db,de,now)) expired++;
                if (ttl > 0) {
                    /* We want the average TTL of keys yet not expired. */
                    ttl_sum += ttl;
                    ttl_samples++;
                }
                total_sampled++;
            }
            total_expired += expired;

            /* Update the average TTL stats for this database. */
            if (ttl_samples) {
                long long avg_ttl = ttl_sum/ttl_samples;

                /* Do a simple running average with a few samples.
                 * We just use the current estimate with a weight of 2%
                 * and the previous estimate with a weight of 98%. */
                if (db->avg_ttl == 0) db->avg_ttl = avg_ttl;
                db->avg_ttl = (db->avg_ttl/50)*49 + (avg_ttl/50);
            }

            /* We can't block forever here even if there are many keys to
             * expire. So after a given amount of milliseconds return to the
             * caller waiting for the other active expire cycle. */
            if ((iteration & 0xf) == 0) { /* check once every 16 iterations. */
                elapsed = ustime()-start;
                if (elapsed > timelimit) {
                    timelimit_exit = 1;
                    server.stat_expired_time_cap_reached_count++;
                    break;
                }
            }
            /* We don't repeat the cycle if there are less than 25% of keys
             * found expired in the current DB. */
        } while (expired > ACTIVE_EXPIRE_CYCLE_LOOKUPS_PER_LOOP/4);
    }

    elapsed = ustime()-start;
    latencyAddSampleIfNeeded("expire-cycle",elapsed/1000);

    /* Update our estimate of keys existing but yet to be expired.
     * Running average with this sample accounting for 5%. */
    double current_perc;
    if (total_sampled) {
        current_perc = (double)total_expired/total_sampled;
    } else
        current_perc = 0;
    server.stat_expired_stale_perc = (current_perc*0.05)+
                                     (server.stat_expired_stale_perc*0.95);
}
```

### AOF、RDB和复制功能对过期键的处理

#### 生成RDB文件
执行SAVE命令或BGSAVE命令创建一个新的RDB文件时，对数据库中的键进行检查，已过期的键不会保存到新创建的RDB文件。

#### 载入RDB文件

* 若服务器已主服务器模式运行，载入RDB文件时，对文件中保存的键进行检查，未过期的键载入数据库中，过期的被忽略。
* 以从服务器模式运行，载入RDB文件时，保存的所有键，不存是否过期，都载入到数据库中。主从同步时会清空从服务器。

#### AOF文件写入

若以AOF持久化模式运行，若键已过期，但未被删除，仍会记录到AOF文件中，当键删除时，会向AOF文件追加一条DEL命令，显示记录该键已经被删除。

#### AOF重写

执行AOF重写时会键进行检查，已过期的键被忽略。


#### 复制

复制模式下，从服务器过期键删除动作由主服务器控制：

* 主服务器删除过期键后，显示地向所有从服务器发送一个DEL命令，告知从服务器删除这个过期键。
* 从服务器执行客户端发送的读命令时，遇到过期键也不会将其删除，继续像处理未过期的键一样处理过期键，将实际已过期键值返回给客户端。
* 从服务器只有在接到主服务器发来的DEL命令后，才删除过期键。

### 数据库通知(订阅/发布)

客户端通过订阅给定的频道或者模式，获知数据库中键的变化，以及数据库中命令的执行情况。

通过配置选项notify-keyspace-events确定发送通知的类型。

发送通知功能在notify.c/notifyKeyspaceEvent函数实现：

```
/* The API provided to the rest of the Redis core is a simple function:
 *
 * notifyKeyspaceEvent(char *event, robj *key, int dbid);
 *
 * 'event' is a C string representing the event name.
 * 'key' is a Redis object representing the key name.
 * 'dbid' is the database ID where the key lives.  */
void notifyKeyspaceEvent(int type, char *event, robj *key, int dbid) {
    sds chan;
    robj *chanobj, *eventobj;
    int len = -1;
    char buf[24];

    /* If any modules are interested in events, notify the module system now.
     * This bypasses the notifications configuration, but the module engine
     * will only call event subscribers if the event type matches the types
     * they are interested in. */
     moduleNotifyKeyspaceEvent(type, event, key, dbid);

    /* If notifications for this class of events are off, return ASAP. */
    if (!(server.notify_keyspace_events & type)) return;

    eventobj = createStringObject(event,strlen(event));

    /* __keyspace@<db>__:<key> <event> notifications. */
    if (server.notify_keyspace_events & NOTIFY_KEYSPACE) {
        chan = sdsnewlen("__keyspace@",11);
        len = ll2string(buf,sizeof(buf),dbid);
        chan = sdscatlen(chan, buf, len);
        chan = sdscatlen(chan, "__:", 3);
        chan = sdscatsds(chan, key->ptr);
        chanobj = createObject(OBJ_STRING, chan);
        pubsubPublishMessage(chanobj, eventobj);
        decrRefCount(chanobj);
    }

    /* __keyevent@<db>__:<event> <key> notifications. */
    if (server.notify_keyspace_events & NOTIFY_KEYEVENT) {
        chan = sdsnewlen("__keyevent@",11);
        if (len == -1) len = ll2string(buf,sizeof(buf),dbid);
        chan = sdscatlen(chan, buf, len);
        chan = sdscatlen(chan, "__:", 3);
        chan = sdscatsds(chan, eventobj->ptr);
        chanobj = createObject(OBJ_STRING, chan);
        pubsubPublishMessage(chanobj, key);
        decrRefCount(chanobj);
    }
    decrRefCount(eventobj);
}
```

发布订阅消息由pubsub.c/pubsubPublishMessage函数实现：

```
/* Publish a message */
int pubsubPublishMessage(robj *channel, robj *message) {
    int receivers = 0;
    dictEntry *de;
    listNode *ln;
    listIter li;

    /* Send to clients listening for that channel */
    de = dictFind(server.pubsub_channels,channel);
    if (de) {
        list *list = dictGetVal(de);
        listNode *ln;
        listIter li;

        listRewind(list,&li);
        while ((ln = listNext(&li)) != NULL) {
            client *c = ln->value;
            addReplyPubsubMessage(c,channel,message);
            receivers++;
        }
    }
    /* Send to clients listening to matching channels */
    if (listLength(server.pubsub_patterns)) {
        listRewind(server.pubsub_patterns,&li);
        channel = getDecodedObject(channel);
        while ((ln = listNext(&li)) != NULL) {
            pubsubPattern *pat = ln->value;

            if (stringmatchlen((char*)pat->pattern->ptr,
                                sdslen(pat->pattern->ptr),
                                (char*)channel->ptr,
                                sdslen(channel->ptr),0))
            {
                addReplyPubsubPatMessage(pat->client,
                    pat->pattern,channel,message);
                receivers++;
            }
        }
        decrRefCount(channel);
    }
    return receivers;
}
```