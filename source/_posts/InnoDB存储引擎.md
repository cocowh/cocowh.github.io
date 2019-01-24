---
title: InnoDB存储引擎
tags: [mysql,note,innodb]
comments: true
categories: [MySQL技术内幕-InnoDB存储引擎]
date: 2019-01-15 15:33:37
---
InnoDB是事务安全的MySQL存储引擎，设计上采用了类似于Oracle数据库的架构。

### InnoDB体系架构
InnoDB存储引擎有多个内存块，这些内存块组成了一个大的内存池，负责工作：

* 维护所有进程/线程需要访问的多个内部数据结构。
* 缓存磁盘上的数据，方便快速地读取，同时在对磁盘文件的数据修改之前在这里缓存。
* 重做日志（redo log）缓冲。 

后台线程的主要作用是负责刷新内存池中的数据，保证缓冲池中的内存缓存是最近的数据。将已修改的数据文件刷新到磁盘文件，同时保证在数据库发生异常的情况下InnoDB能恢复到正常运行状态。

#### 后台线程
InnoDB是多线程模型，后台有多个不同的后台线程，负责处理不同的任务。

##### Master Thread
核心后台线程，负责将缓冲池中的数据异步刷新到磁盘，保证数据的一致性，包括脏页的刷新、合并插入缓冲（INSERT BUFFER）、UNDO页的回收。
##### IO Thread
使用AIO（Async IO）来处理写IO请求，提高数据库的性能。IO Thread负责这些IO请求的回调（call back）处理。InnoDB V1.0前共有4个IO Thread，分别是write、read、insert buffer和log IO thread。Linux下IO Thread的数量不能进行调整，Win下可以通过参数`innodb_file_io_threads`来增大IO Thread。InnoDB V1.0开始，read thread和write thread分别增大到了4个，不再使用`innodb_file_io_threads`参数，分别使用`inodb_read_io_threads`和`innodb_write_io_threads`参数进行设置。

```
mysql> show variables like 'innodb_version'\G
*************************** 1. row ***************************
Variable_name: innodb_version
        Value: 5.7.22
1 row in set (0.23 sec)

mysql> show variables like 'innodb_%io_threads'\G;
*************************** 1. row ***************************
Variable_name: innodb_read_io_threads
        Value: 4
*************************** 2. row ***************************
Variable_name: innodb_write_io_threads
        Value: 4
2 rows in set (0.00 sec)

ERROR: 
No query specified

mysql> show engine innodb status\G;
*************************** 1. row ***************************
  Type: InnoDB
  Name: 
Status: 
=====================================
2019-01-23 00:22:55 0x7000078ef000 INNODB MONITOR OUTPUT
=====================================
Per second averages calculated from the last 30 seconds
-----------------
BACKGROUND THREAD
-----------------
srv_master_thread loops: 3 srv_active, 0 srv_shutdown, 261512 srv_idle
srv_master_thread log flush and writes: 261494
----------
SEMAPHORES
----------
OS WAIT ARRAY INFO: reservation count 9
OS WAIT ARRAY INFO: signal count 9
RW-shared spins 0, rounds 9, OS waits 2
RW-excl spins 0, rounds 0, OS waits 0
RW-sx spins 0, rounds 0, OS waits 0
Spin rounds per wait: 9.00 RW-shared, 0.00 RW-excl, 0.00 RW-sx
------------
TRANSACTIONS
------------
Trx id counter 23555
Purge done for trx's n:o < 0 undo n:o < 0 state: running but idle
History list length 0
LIST OF TRANSACTIONS FOR EACH SESSION:
---TRANSACTION 281479475189552, not started
0 lock struct(s), heap size 1136, 0 row lock(s)
--------
FILE I/O
--------
I/O thread 0 state: waiting for i/o request (insert buffer thread)
I/O thread 1 state: waiting for i/o request (log thread)
I/O thread 2 state: waiting for i/o request (read thread)
I/O thread 3 state: waiting for i/o request (read thread)
I/O thread 4 state: waiting for i/o request (read thread)
I/O thread 5 state: waiting for i/o request (read thread)
I/O thread 6 state: waiting for i/o request (write thread)
I/O thread 7 state: waiting for i/o request (write thread)
I/O thread 8 state: waiting for i/o request (write thread)
I/O thread 9 state: waiting for i/o request (write thread)
Pending normal aio reads: [0, 0, 0, 0] , aio writes: [0, 0, 0, 0] ,
 ibuf aio reads:, log i/o's:, sync i/o's:
Pending flushes (fsync) log: 0; buffer pool: 0
432 OS file reads, 59 OS file writes, 7 OS fsyncs
0.00 reads/s, 0 avg bytes/read, 0.00 writes/s, 0.00 fsyncs/s
-------------------------------------
INSERT BUFFER AND ADAPTIVE HASH INDEX
-------------------------------------
Ibuf: size 1, free list len 0, seg size 2, 0 merges
merged operations:
 insert 0, delete mark 0, delete 0
discarded operations:
 insert 0, delete mark 0, delete 0
Hash table size 34673, node heap has 0 buffer(s)
Hash table size 34673, node heap has 0 buffer(s)
Hash table size 34673, node heap has 0 buffer(s)
Hash table size 34673, node heap has 0 buffer(s)
Hash table size 34673, node heap has 0 buffer(s)
Hash table size 34673, node heap has 0 buffer(s)
Hash table size 34673, node heap has 0 buffer(s)
Hash table size 34673, node heap has 0 buffer(s)
0.00 hash searches/s, 0.00 non-hash searches/s
---
LOG
---
Log sequence number 4861558
Log flushed up to   4861558
Pages flushed up to 4861558
Last checkpoint at  4861549
0 pending log flushes, 0 pending chkp writes
10 log i/o's done, 0.00 log i/o's/second
----------------------
BUFFER POOL AND MEMORY
----------------------
Total large memory allocated 137428992
Dictionary memory allocated 137933
Buffer pool size   8191
Free buffers       7760
Database pages     431
Old database pages 0
Modified db pages  0
Pending reads      0
Pending writes: LRU 0, flush list 0, single page 0
Pages made young 0, not young 0
0.00 youngs/s, 0.00 non-youngs/s
Pages read 396, created 35, written 42
0.00 reads/s, 0.00 creates/s, 0.00 writes/s
No buffer pool page gets since the last printout
Pages read ahead 0.00/s, evicted without access 0.00/s, Random read ahead 0.00/s
LRU len: 431, unzip_LRU len: 0
I/O sum[0]:cur[0], unzip sum[0]:cur[0]
--------------
ROW OPERATIONS
--------------
0 queries inside InnoDB, 0 queries in queue
0 read views open inside InnoDB
Process ID=94, Main thread ID=123145423732736, state: sleeping
Number of rows inserted 90, updated 0, deleted 0, read 98
0.00 inserts/s, 0.00 updates/s, 0.00 deletes/s, 0.00 reads/s
----------------------------
END OF INNODB MONITOR OUTPUT
============================

1 row in set (0.08 sec)

ERROR: 
No query specified
```

`show engine innodb status`观察IO Thread。读线程的ID总是小于写线程。

##### Purge Thread
事务被提交后，其所使用的undolog可能不再需要，需要Purge Thread回收已经使用并分配的undo页，V1.1之前，purge操作仅在InnoDB存储引擎的Master Thread中完成，V1.1开始，可以单独到独立的线程中进行，减轻Master Thread的工作，提高CPU使用率、提升存储引擎的性能。

在数据库配置文件中添加：

```
[mysqld]
innodb_purge_threads=1
```
来启用独立的Purge Thread。

>查看配置文件位置  
 
```
wuhua:~ wuhua$ /usr/local/mysql/bin/mysql --verbose --help |grep -A 1 'Default options'
Default options are read from the following files in the given order:
/etc/my.cnf /etc/mysql/my.cnf /usr/local/mysql/etc/my.cnf ~/.my.cnf 
wuhua:~ wuhua$ mysql --help|grep 'my.cnf'
                      order of preference, my.cnf, $MYSQL_TCP_PORT,
/etc/my.cnf /etc/mysql/my.cnf /usr/local/mysql/etc/my.cnf ~/.my.cnf 
```
设置后重启mysql（`sudo /usr/local/mysql/support-files/mysql.server restart`）：

```
mysql> show variables like 'innodb_purge_threads'\G;
*************************** 1. row ***************************
Variable_name: innodb_purge_threads
        Value: 1
1 row in set (0.04 sec)
```
V1.1即使将`innodb_purge_threads`设为大于一，启动时也会将其设为1。V1.2开始，为进一步加快undo页的回收，支持多个Purge Thread。

```
mysql> show variables like 'innodb_purge_threads'\G;
*************************** 1. row ***************************
Variable_name: innodb_purge_threads
        Value: 4
1 row in set (0.00 sec)
```


##### Page Cleaner Thread
于V1.2.x版本引入，为减轻原Master Thread的工作及对于用户查询线程的阻塞、进一步提高InnoDB存储引擎的性能，将之前版本中脏页的刷新操作放到单独的线程中来完成。

#### 内存

#####缓冲池
InnoDB存储引擎基于磁盘存储，并将其中的记录按照页的方式进行管理，可将其视为基于磁盘的数据库系统。因CPU速度与磁盘速度之间的鸿沟，使用缓冲池技术来提高数据库的整体性能。

数据库中进行读取页的操作，首先将从磁盘读到的页存放在缓冲池中，过程称为将页‘FIX’在缓冲池中。下一次再读取相同的页时，首先判断该页是否在缓冲池中。若在缓冲池中，称该页在缓冲池中被命中，直接读取页，否则读取磁盘上的页。

进行页的修改操作时，首先修改在缓冲池中的页，然后再以一定的频率刷新到磁盘上。页从缓冲池刷新回磁盘的操作并不是在每次页发生更新时触发，通过一种称为Checkpoint的机制刷新回磁盘。为提高数据库的整体性能。

缓冲池的大小直接影响着数据库的整体性能。32位系统下该值为3G，可打开操作系统的PAE选项来获得32位操作系统下最大64GB内存的支持。为使数据库使用更多的内存，建议数据库服务器采用64位操作系统。

缓存池的配置通过参数`innodb_buffer_pool_size`来设置，默认值是128M，最小5M(当小于该值时会设置成5M)，最大为LLONG_MAX。

修改前：

```
mysql> show variables like 'innodb_buffer_pool_size'\G;
*************************** 1. row ***************************
Variable_name: innodb_buffer_pool_size
        Value: 134217728
1 row in set (0.00 sec)
```
修改后：

```
wuhua:~ wuhua$ cat  .my.cnf
[mysqld]
innodb_purge_threads=4
innodb_buffer_pool_size=256M
```

```
mysql> show variables like 'innodb_buffer_pool_size'\G;
*************************** 1. row ***************************
Variable_name: innodb_buffer_pool_size
        Value: 268435456
1 row in set (0.01 sec)
```

缓冲池中缓冲的数据页类型有：索引页、数据页、undo页、插入缓冲（insert buffer）、自适应哈希索引（adaptive hash index）、InnoDB存储的锁信息（lock info）、数据字典信息（data dictionary）等。索引页和数据页占缓冲池很大一部分。

从V1.0.x版本开始，允许有多个缓冲池实例。每个页根据哈希值平均分配到不同缓冲池实例中。可以减少数据库内部的资源竞争，增加数据库的并发处理能力。可以通过参数`innodb_buffer_pool_instances`来进行设置，默认值为1，设置大于1时需保证缓冲池大小（`innodb_buffer_pool_size`）最小为1G。

设置前：

```
mysql> show variables like 'innodb_buffer_pool_instances'\G;
*************************** 1. row ***************************
Variable_name: innodb_buffer_pool_instances
        Value: 1
1 row in set (0.01 sec)
```
设置后：

```
wuhua:~ wuhua$ cat  .my.cnf
[mysqld]
innodb_purge_threads=4
innodb_buffer_pool_size=1028M
innodb_buffer_pool_instances=2
```
多种方式查看：

```
mysql> use information_schema
mysql> select pool_id,pool_size,free_buffers,database_pages from innodb_buffer_pool_stats\G;
*************************** 1. row ***************************
       pool_id: 0
     pool_size: 40955
  free_buffers: 40724
database_pages: 231
*************************** 2. row ***************************
       pool_id: 1
     pool_size: 40955
  free_buffers: 40755
database_pages: 200
2 rows in set (0.00 sec)

mysql> show variables like 'innodb_buffer_pool_instances'\G;
*************************** 1. row ***************************
Variable_name: innodb_buffer_pool_instances
        Value: 2
1 row in set (0.01 sec)

mysql> show engine innodb status\G;

...
----------------------
INDIVIDUAL BUFFER POOL INFO
----------------------
---BUFFER POOL 0
Buffer pool size   40955
Free buffers       40724
Database pages     231
Old database pages 0
Modified db pages  0
Pending reads      0
Pending writes: LRU 0, flush list 0, single page 0
Pages made young 0, not young 0
0.00 youngs/s, 0.00 non-youngs/s
Pages read 196, created 35, written 39
0.00 reads/s, 0.00 creates/s, 0.00 writes/s
No buffer pool page gets since the last printout
Pages read ahead 0.00/s, evicted without access 0.00/s, Random read ahead 0.00/s
LRU len: 231, unzip_LRU len: 0
I/O sum[0]:cur[0], unzip sum[0]:cur[0]
---BUFFER POOL 1
Buffer pool size   40955
Free buffers       40755
Database pages     200
Old database pages 0
Modified db pages  0
Pending reads      0
Pending writes: LRU 0, flush list 0, single page 0
Pages made young 0, not young 0
0.00 youngs/s, 0.00 non-youngs/s
Pages read 200, created 0, written 0
0.00 reads/s, 0.00 creates/s, 0.00 writes/s
No buffer pool page gets since the last printout
Pages read ahead 0.00/s, evicted without access 0.00/s, Random read ahead 0.00/s
LRU len: 200, unzip_LRU len: 0
I/O sum[0]:cur[0], unzip sum[0]:cur[0]
...
```

##### LRU List、Free List和Flush List
通常数据库中的缓冲池通过LRU（Latest Recent Used）算法来进行管理。InnoDB缓冲池中页的大小默认为16KB，使用LRU算法管理。但对LRU算法做了一些优化，在LRU列表中增加了midpoint位置，新读取到的页放入到LRU列表的midpoint位置。默认配置下，该位置在LRU列表长度的5/8处。可由参数`innodb_old_blocks_pct`控制。

```
mysql> 
mysql> show variables like 'innodb_old_blocks_pct'\G;
*************************** 1. row ***************************
Variable_name: innodb_old_blocks_pct
        Value: 37
1 row in set (0.19 sec)
```

表示新读取的页插入到LRU列表尾端37%（3/8）的位置，把midpoint之后的列表称为old表，之前的列表称为new列表。引入另一个参数`innodb_old_blocks_time`进一步管理LRU列表，用于表示页读取到mid位置后需要等待多久才会被加入到LRU列表的热端。

```
mysql> show variables like 'innodb_old_blocks_time'\G;
*************************** 1. row ***************************
Variable_name: innodb_old_blocks_time
        Value: 1000
1 row in set (0.01 sec)
mysql> set global innodb_old_blocks_time=999;
Query OK, 0 rows affected (0.02 sec)

mysql> show variables like 'innodb_old_blocks_time'\G;
*************************** 1. row ***************************
Variable_name: innodb_old_blocks_time
        Value: 999
1 row in set (0.00 sec)
```

若预估活跃的热点数据不止63%，可以在执行SQL前，通过设置`innodb_old_blocks_pct`的值减少热点页可能被刷出来的概率。

```
mysql> show variables like 'innodb_old_blocks_pct'\G;
*************************** 1. row ***************************
Variable_name: innodb_old_blocks_pct
        Value: 37
1 row in set (0.07 sec)

mysql> set global innodb_old_blocks_pct=20;
Query OK, 0 rows affected (0.00 sec)

mysql> show variables like 'innodb_old_blocks_pct'\G;
*************************** 1. row ***************************
Variable_name: innodb_old_blocks_pct
        Value: 20
1 row in set (0.01 sec)
```

LRU列表管理已经读取的页，当数据库刚启动时，LRU列表是空的，此时页存放在Free列表中。从缓冲池中分页时，先从Free列表中查找可用的空闲页，有则从Free列表中删除，放入到LRU列表中，否则根据LRU算法淘汰LRU列表末尾的页，将该内存空间分配给新的页。

通过`show engine innodb status`观察LRU列表及Free列表的使用情况和运行状态。

```
mysql> show engine innodb status\G;
*************************** 1. row ***************************
  Type: InnoDB
  Name: 
Status: 
=====================================
2019-01-24 21:13:11 0x700007d13000 INNODB MONITOR OUTPUT
=====================================
Per second averages calculated from the last 53 seconds
-----------------
...
----------------------
BUFFER POOL AND MEMORY
----------------------
Total large memory allocated 1374289920
Dictionary memory allocated 100382
Buffer pool size   81910
Free buffers       81479
Database pages     431
Old database pages 0
Modified db pages  0
Pending reads      0
Pending writes: LRU 0, flush list 0, single page 0
Pages made young 0, not young 0
0.00 youngs/s, 0.00 non-youngs/s
Pages read 396, created 35, written 39
0.00 reads/s, 0.00 creates/s, 0.00 writes/s
No buffer pool page gets since the last printout
Pages read ahead 0.00/s, evicted without access 0.00/s, Random read ahead 0.00/s
LRU len: 431, unzip_LRU len: 0
I/O sum[0]:cur[0], unzip sum[0]:cur[0]
...
```

Free buffers与Database pages的数量之和可能不等于Buffer pool size，因为缓冲池中的页还可能会被分配给自适应哈希索引、Lock信息、Insert Buffer等页。Buffer pool hit rate表示缓冲池命中率，小于95%需要观察是否由于全表扫描引起的LRU列表被污染问题。
> 该命令显示的不是当前的状态，而是过去某个时间范围内InnoDB存储引擎的状态。`Per second averages calculated from the last 53 seconds`

可通过I`NNODB_BUFFER_PAGE_LRU`来观察每个LRU列表中每个页的具体信息。

```
mysql> use information_schema;
Database changed
mysql> select table_name,space,page_number,page_type from innodb_buffer_page_lru where space=189;
+------------+-------+-------------+-------------------+
| table_name | space | page_number | page_type         |
+------------+-------+-------------+-------------------+
| NULL       |   189 |           0 | FILE_SPACE_HEADER |
| NULL       |   189 |           1 | IBUF_BITMAP       |
| NULL       |   189 |           2 | INODE             |
| NULL       |   189 |           3 | INDEX             |
| NULL       |   189 |           4 | INDEX             |
+------------+-------+-------------+-------------------+
```

V1.0.x开始支持压缩页的功能，可将原本16KB的页压缩为1KB、2KB、4KB和8KB，非16KB的页，通过unzip_LRU列表进行管理。

```
mysql> show engine innodb status\G;
...
No buffer pool page gets since the last printout
Pages read ahead 0.00/s, evicted without access 0.00/s, Random read ahead 0.00/s
LRU len: 431, unzip_LRU len: 0
I/O sum[0]:cur[0], unzip sum[0]:cur[0]
```
LRU中的页包含了unzip_LRU列表中的页。

unzip_LRU列表中对不同压缩页大小的风进行分别管理，通过伙伴算法进行内存的分配。例如从缓冲池中申请页为4KB的大小，过程为：

* 检查4KB的unzip_LRU列表，检查是否有可用的空闲页；
* 若有，直接使用；
* 否则检查8KB的unzip_LRU列表；
* 若有空闲页，将页分成2个4KB页，存放到4KB的unzip_LRU列表；
* 否则从LRU列表中申请一个16KB的页，将页分为1个8KB的页、2个4KB的页，分别存放到对应的unzip_LRU列表中。

可通过表`INNODB_BUFFER_PAGE_LRU`来观察unzip_LRU列表中的项。

```
mysql> use information_schema;
Database changed
mysql> select table_name,space,page_number,compressed_size from innodb_buffer_page_lru where compressed_size<>0;
Empty set (0.01 sec)
```

在LRU列表中的页被修改后，称该页为脏页，即缓冲池中的页和磁盘上的页的数据产生了不一致。这时通过CHECKPOINT机制将脏页刷新回磁盘，而Flush列表中的页即为脏页列表。脏页既存在于LRU列表中，也存在于Flush列表中。LRU列表用来管理缓冲池中页的可用性，Flush列表用来管理将页刷新回磁盘。

```
mysql> show engine innodb status\G;
...
BUFFER POOL AND MEMORY
----------------------
Total large memory allocated 1374289920
Dictionary memory allocated 100382
Buffer pool size   81910
Free buffers       81479
Database pages     431
Old database pages 0
Modified db pages  0
Pending reads      0
Pending writes: LRU 0, flu
```
`Modified db pages`显示了脏页的数量。

可通过表`INNODB_BUFFER_PAGE_LRU`来观察脏页。

```
mysql> use information_schema;
Database changed
mysql> select table_name,space,page_number,page_type from innodb_buffer_page_lru where oldest_modification>0;
Empty set (0.01 sec)
```

> `TABLE_NAME`为NULL表示该页属于系统表空间。

##### 重做日志缓冲

