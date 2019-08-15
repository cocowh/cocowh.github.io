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

##### 缓冲池
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

可通过`INNODB_BUFFER_PAGE_LRU`来观察每个LRU列表中每个页的具体信息。

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

InnoDB存储引擎的内存区域除缓冲池外还有重做日志缓存（redo log buffer），InnoDB先将重做日志信息先放入到这个缓冲区，然后按一定的频率将其刷新到重做日志文件，一般每秒都会将重做日志缓冲刷新到日志文件，用户只需保证每秒产生的事务量在这个缓冲大小之内，不需要将其设置的很大。该值可由配置参数innodb\_log\_buffer_size控制，默认为8M（mac v5.7.22 默认16M）。

```
mysql> show variables like 'innodb_log_buffer_size'\G
*************************** 1. row ***************************
Variable_name: innodb_log_buffer_size
        Value: 16777216
1 row in set (0.01 sec)
```

在以下三种情况下会将重做日志缓冲中的内容刷新到外部磁盘的重做日志文件中。

 * Master Thread 每一秒将重做日志缓冲刷新到重做日志文件；
 * 每个事物提交时会将重做日志缓冲刷新到重做日志文件；
 * 当重做日志缓冲池剩余空间小于1/2时，重做日志缓冲刷新到重做日志文件
 
##### 额外的内存池

InnoDB对内存的管理是通过堆内存（heap）的方式进行的。在对一些数据结构本身的内存进行分配时，需要从额外的内存池中进行申请，当该区域的内存不够时，会从缓冲池中进行申请。

例如：分配了缓冲池（innodb\_buffer\_pool），但是每个缓冲池中的帧缓存（frame buffer）还有对应的缓冲控制对象（buffer control block：记录一些诸如LRU、锁、等待等信息），对象的内存需要从额外内存池中申请。在申请了很大的InnoDB缓冲池时，也应考虑相应地增加额外内存池的大小。

### Checkpoint技术

页的操作首先都是在缓冲池中完成的，若一条DML语句改变了页中的记录，那么此时页是脏的，即缓冲池中的页的版本比磁盘的新，数据库将新版本的页从缓冲池刷新到磁盘。

为避免数据丢失问题，当前事物数据库系统普遍都采用了Write Ahead Log策略，即当事物提交时，先写重做日志，再修改页。当发生宕机而导致数据丢失时，通过重做日志来完成数据的恢复。事务ACID中D（Durability持久性）的要求。

Checkpoint（检查点）技术的目的：

 * 缩短数据库的恢复时间；
 * 缓冲池不够用时，将脏数据刷新到磁盘；
 * 重做日志不可用时，刷新脏页。
 
 
 数据库发生宕机时，数据库不需要重做所有的日志，Checkpoint之前的页都已经刷新回磁盘，数据库只需对Checkpoint后的重做日志进行恢复。
 
 当缓冲池不够用时，根据LRU算法会溢出最近最少使用的页，若此页为脏页，那么需要强制执行Checkpoint，将脏页也就是页的新版本刷回磁盘。
 
 重做日志不可用的情况是因为在当前事务数据库系统对重做日志的设计都是循环使用的，并不是让其无限增大。重做日志可以被重用的部分是指这些重做日志已经不再需要，即当数据库发生宕机时，数据库恢复操作不需要这部分的重做日志，这部分可以被覆盖重用。若此时重做日志还需要使用，那么必须强制产生Checkpoint，将缓冲池中的页至少刷新到当前重做日志的位置。
 
 InnoDB存储引擎通过LSN（Log Sequence Number）来标记版本，LSN是8字节数字，单位是字节。每个页有LSN，重做日志中也有LSN，Checkpoint也有LSN。可以通过`SHOW ENGINE INNODB STATUS`来观察。
 
```
mysql> show engine innodb status\G
...
---
LOG
---
Log sequence number 5009487
Log flushed up to   5009487
Pages flushed up to 5009487
Last checkpoint at  5009478
0 pending log flushes, 0 pending chkp writes
10 log i/o's done, 0.00 log i/o's/second
...
```

在InnoDB存储引擎内部，有两种Checkpoint，分别为：
 
 * Sharp Checkpoint
 * Fuzzy Checkpoint

Sharp Checkpoint发生在数据库关闭时将所有的脏页都刷新回磁盘，这是默认的工作方式，即参数innodb\_fast\_shutdown=1。

数据库运行时在InnoDB存储引擎内部使用Fuzzy Checkpoint进行页的刷新，即指刷新一部分脏页，而不是刷新所有的脏页回磁盘。

在InnoDB存储引擎中可能发生Fuzzy Checkpoint的情况：

* Master Thread Checkpoint
* FLUSH\_LRU\_LIST Checkpoint
* Async/Sync Flush Checkpoint
* Dirty Page too much Checkpoint

Master Thread中发生的Checkpoint，每秒或每十秒的速度从缓冲池的脏页列表中刷新一定比例的页回磁盘。过程异步，用户查询线程不会阻塞。

FLUSH\_LRU\_LIST Checkpoint是因为InnoDB存储引擎需要保证LRU列表中需要有差不多100个空闲页可供使用，在v1.1.x之前检查LRU列表中是否有足够可用空间操作发生在
用户查询线程中，会阻塞用户查询操作。若无100个可用空闲页，会将LRU列表尾端的页移除，若其中有脏页，则进行Checkpoint。

InnoDB v1.2.x（MySQL 5.6）开始检查被放在Page Cleaner Thread中进行，可通过参数`innodb_lru_scan_depth`控制LRU列表中可用页的数量，默认1024。


```
mysql> show variables like 'innodb_lru_scan_depth'\G
*************************** 1. row ***************************
Variable_name: innodb_lru_scan_depth
        Value: 1024
1 row in set (0.01 sec)
```
Async/Sync Flush Checkpoint指的是重做日志不可用的情况下，需要强制将一些页刷新回磁盘，此时脏页是从脏页列表中选取。将已经写入到重做日志的LSN记为redo\_lsn，将已经刷新回磁盘最新页的LSN记为checkpoint_lsn，则：

> checkpoint\_age = redo\_lsn - checkpoint\_lsn
> 
> async\_water\_mark = 75% \* total\_redo\_log\_file\_size
> 
> sync\_water\_mark = 90% \* total\_redo\_log\_file\_size

* checkpoint_age < async_water_mark，不需要刷新任何脏页到磁盘
* async\_water\_mark < checkpoint\_age < sync\_water\_mark时触发Async Flush，从Flush列表中刷新足够的脏页回磁盘，使得刷新后满足checkpoint\_age < async\_water\_mark
* checkpoint\_age > sync\_water\_mark很少发生除非设置的重做日志文件太小，在进行类似LOAD DATA的BULK INSETRT操作，触发Sync Flush操作，从Flush列表中刷新足够的脏页回磁盘，使得刷新后满足checkpoint\_age < async\_water\_mark。

Async/Sync Flush Checkpoint保证重做日志循环使用的可用性，v1.2.x之前，Async Flush Checkpoint阻塞发现问题的用户查询线程，Sync Flush Checkpoint阻塞所有用户的查询线程，并且等待脏页刷新的完成。v1.2.x开始，放入到单独的Page Cleaner Thread中。

MySQL官版不能查看刷新页是从Flush列表中还是从LRU列表中进行Checkpoint的，不知道因为重做日志而产生的Async/Sync Flush的次数。InnoSQL版本可通过命令`show engine innodb status`来观察。

Dirty Page too much Checkpoint是因为脏页数量太多，导致InnoDB存储引擎强制进行Checkpoint。目的为了保证缓冲池中有足够可用的页。可由参数`innodb_max_dirty_page_pct`控制。

```
mysql> show variables like 'innodb_max_dirty_pages_pct'\G
*************************** 1. row ***************************
Variable_name: innodb_max_dirty_pages_pct
        Value: 75.000000
1 row in set (0.00 sec)
```

75表示缓冲池中脏页的数量占据75%时，强制进行Checkpoint，刷新一部分脏页到磁盘，InnoDB v1.0.x之前是90，之后是75。

### Master Thread工作方式


#### InnoDB 1.0.x之前的Master Thread

具有最高的线程优先级别。内部由多个loop组成：主循环（loop）、后台循环（backgroup loop）、刷新循环（flush loop）、暂停循环（suspend loop）。根据数据库运行状态进行切换。

主循环有两大部分操作——每秒钟的操作和每10秒钟的操作。

每秒钟的操作：

* 日志缓冲刷新到磁盘，即使这个事务还没有提交（总是），因此再大的事务提交时间也是很短的；
* 合并插入缓冲（可能），判断上一秒内发生的IO次数是否小于5次，若小于5次，认为当前的IO压力很小，可以住行合并插入缓冲的操作；
* 至多刷新100个InnoDB的缓冲池中的脏页到磁盘（可能），判断当前缓冲池中脏页的比例（buf\_get\_modified\_ratio\_pct）是否超过了配置文件中innodb\_max\_dirty\_pages_pct这个参数（默认90，代表90%），若超过，认为需要做磁盘同步的操作，将100个脏页写入磁盘中。


每10秒的操作：
 
 * 刷新100个脏页到磁盘（可能的情况下），若过去10秒内磁盘的IO操作小于200次，则认为有足够的磁盘IO能力，将100个脏个刷新到磁盘；
 * 合并至多5个插入缓冲（总是）；
 * 将日志缓冲刷新到磁盘（总是）；
 * 删除无用的undo页（总是），full purge操作，每次最多尝试回收20个undo页，对表进行updae、delete操作时，原行被标记为删除，因一致性读（consistent read）需要保留这些行版本的信息，在full purge过程中，判断当前事务系统中已被删除的行是否可以删除（可能有查询操作需要读取之前版本的undo信息），若可以则立即删除；
 * 刷新100个或10个脏页到磁盘（总是），判断缓冲池中脏页的比例（buf\_get\_modified\_ratio\_pct），若有超过70%的脏页，则刷新100个脏页到磁盘，若小于70%则只刷新10个脏页到磁盘。
 
 
若当前没有用户活动（数据库空闲）或者数据库关闭（shutdown），切换到background loop，执行的操作：

* 删除无用的undo页（总是）；
* 合并20个插入缓冲（总是）；
* 跳回到主循环（总是）；
* 不断刷新100个页直到符合条件（可能，跳转到flush loop中完成）。

若flush loop中也无事可做，则切换到suspend_loop，将Master Thread挂起，等待事情的发生。若用户启用了InnoDB存储引擎，却没有使用任何InnoDB存储引擎的表，那么Master Thread总是处于挂起状态。


#### InnoDB 1.2.x版本之前的Master Thread

v1.0.x对于IO有限制，向磁盘刷新时做了一定的硬编码（刷新数固定值），限制了对磁盘IO的性能，尤其是写入性能。v1.0.x开始提供参数innnodb\_io\_capacity，用来表示磁盘IO的吞吐量，默认值200，对于刷新到磁盘的页的数量，按照innnodb\_io\_capacity的百分比来进行控制：

* 合并插入缓冲时，合并插入缓冲的数量为innnodb\_io\_capacity值的5%；
* 从缓冲区刷新脏页到时，刷新脏页的数量为innnodb\_io\_capacity。

参数innodb\_max\_dirty\_pages\_pct默认值为90，当内存很大，或者数据库服务的压力很大，刷新脏页的速度会降低，数据库恢复时需要更多的时间。设置过低时会增加磁盘IO压力。v1.0.x开始，默认值设置为75，和Google测试的最优值80接近。

引入参数innodb\_adaptive\_flushing（自适应刷新）。愿刷新规则：大于innodb\_max\_dirty\_pages\_pct时，刷新100个脏页， 否则不刷新脏页。引入后通过名为buf\_flush\_get\_desired\_flush\_rate函数（通过判断产生重做日志redo log的速度来决定最合适的刷新脏页数量）判断需要刷新脏页最合适的数量。当脏页的比例小于innodb\_max\_dirty\_pages\_pct时，也会刷新一定量的脏页。

引入参数innodb_purge_batch_size，控制每次full purge回收的Undo页的数量，之前最多回收20个Undo页，该参数默认值20(用的mysql 5.7.22，默认值300)，可动态地对其进行修改。

```
mysql> show variables like 'innodb_purge_batch_size'\G
*************************** 1. row ***************************
Variable_name: innodb_purge_batch_size
        Value: 300
1 row in set (0.00 sec)

mysql> 
mysql> set global innodb_purge_batch_size=320;
Query OK, 0 rows affected (0.02 sec)

mysql> show variables like 'innodb_purge_batch_size'\G
*************************** 1. row ***************************
Variable_name: innodb_purge_batch_size
        Value: 320
1 row in set (0.00 sec)
```

可由命令`SHOW ENGINE INNODB STATUS`查看当前Master Thread的状态信息

```
mysql> show variables like 'innodb_purge_batch_size'\G
...
BACKGROUND THREAD
-----------------
srv_master_thread loops: 2 srv_active, 0 srv_shutdown, 139324 srv_idle
srv_master_thread log flush and writes: 139319
...
```

#### InnoDB 1.2.x版本的Master Thread

```
if InnoDD is idle
  srv_master_do_idle_tasks(); //每10s的操作
else 
  srv_master_do_active_tasks(); //每秒的操作
```

刷新脏页的操作，从Master Thread线程分离到单独的Page Cleaner Thread。

### InnoDB关键特性

* 插入缓冲（Insert Buffer）
* 两次写（Double Write）
* 自适应哈希索引（Adaptive Hash Index）
* 异步IO（Async IO）
* 刷新邻接页（Flush Neighbor Page）


#### 插入缓冲

##### Insert Buffer
和数据页一样，是物理页的一个组成部分。

插入聚集索引（Primary Key）一般是顺序的，不需要磁盘的随机读取，这类插入操作速度是非常快的。但并不是所有的主键插入都是顺序的，若主键是UUID类，则插入和辅助索引一样，同样是随机的。即使主键是指定的值，而不是NULL值，那么同样可能导致插入并非连续的情况。

对于非聚集索引的插入或者更新操作，不是每一次直接插入到索引页中，而是先判断插入的非聚集索引页是否在缓冲池中，若在，则直接插入；若不在，则先放入到一个Insert Buffer对象中，好似欺骗。再以一定的频率和情况进行Insert Buffer和辅助索引页子节点的merge（合并）操作，这时通常能将多个插入合并到一个操作（在一个索引页中），这就大大提高了对于非聚集索引插入的性能。

Insert Buffer的使用需要同时满足两个条件：

* 索引是辅助索引（secondary index）；
* 索引不是唯一（unique）的。

通过`SHOW ENGINE INNODB STATUS`查看插入缓冲的信息：

```
mysql> show engine status\G
...
-------------------------------------
INSERT BUFFER AND ADAPTIVE HASH INDEX
-------------------------------------
Ibuf: size 1, free list len 12, seg size 14, 331 merges
merged operations:
 insert 1580, delete mark 3, delete 0
discarded operations:
 insert 0, delete mark 0, delete 0
314.08 hash searches/s, 208.70 non-hash searches/s
...
```
第一行：size代表已合并记录页的数量；free list len代表空闲列表的长度；seg size显示当前Insert Buffer的大小为14*16k；merges代表合并的次数。

写密集情况下，插入缓冲会占用过多的缓冲池内存，默认最大可占用1/2。可通过修改`IBUF_POOL_SIZE_PER_MAX_SIZE`对插入缓冲的大小进行控制。将其修改为3则最大只能使用1/3的缓冲池内存。


##### Change Buffer
Insert Buffer的升级，可以对DML操作——INSERT、DELETE、UPDATE都进行缓冲，他们分别是：Insert Buffer、Delete Buffer、Purge Buffer。

同Insert Buffer，Change Buffer适用的对象依然是非唯一的辅助索引。

对一条记录进行UPDATE操作可能分为两个过程：

* 将记录标记为已删除；
* 真正将记录删除。

Delete Buffer对应操作的第一个过程，Purge Buffer对应操作的第二个过程。通过参数`innodb_change_buffering`开启各种Buffer的选项，可选：inserts、deletes、purges、changes、all、none。changes表示启用inserts和deletes、all表示启用所有，none表示都不启用。

通过`innodb_change_buffer_max_size`来控制Change Buffer最大使用内存的数量：

```
mysql> show variables like 'innodb_change_buffer_max_size'\G
*************************** 1. row ***************************
Variable_name: innodb_change_buffer_max_size
        Value: 25
1 row in set (0.00 sec)
```
默认值为25，表示最多使用1/4（25%）的缓冲池内存空间，最大有效值50。

通过`SHOW ENGINE INNODB STATUS`查看：

```
mysql> show engine status\G
...
-------------------------------------
INSERT BUFFER AND ADAPTIVE HASH INDEX
-------------------------------------
Ibuf: size 1, free list len 12, seg size 14, 331 merges
merged operations:
 insert 1580, delete mark 3, delete 0
discarded operations:
 insert 0, delete mark 0, delete 0
314.08 hash searches/s, 208.70 non-hash searches/s
...
```
insert表示Insert Buffer；delete mark表示Delete Buffer；delete表示Purge Buffer；discarded operations表示当Change Buffer发生merge时，表已经被删除，此时无需再将记录合并到辅助索引中。

##### Insert Buffer的内部实现

Insert Buffer的数据结构是一棵B+树，MySQL v4.1前每张表有一棵Insert Buffer B+树，现版本全局只有一棵Insert Buffer B+树，负责对所有的表的辅助索引进行Insert Buffer。存放在共享表空间中，默认ibdata1中。在试图通过独立表空间ibd文件恢复表中数据时，往往会导致CHECK TABLE失败，因为表的辅助索引中的数据可能还在Insert Buffer中，即共享表空间中。

Insert Buffer非叶节点存放查询的search key（键值）。

search key一共占用9个字节，space表示待插入记录所在表的表空间id，InnoDB存储引擎中每个表有一个唯一的space id，可通过space id查询得知是哪张表。space占用4字节。marker占用1字节，用于兼容老版本的Insert Buffer。offset表示页所在的偏移量，占用4字节。

当辅助索引要插入到页（space，offset）时，若页不在缓冲池中，则首先根据上述规则构造一个search key，然后查询Insert Buffer这棵B+树，然后再将这条记录插入到Insert Buffer B+树的叶子节点中。
插入到Insert Buffer B+树叶子节点的记录，需要根据规则进行构造。

> space | marker | offset | metadata |{ secondary index record}|

metadata占用4字节，存储内容：

名称 | 字节 
:-: | :-: | :-:
IBUF\_REC\_OFFSET\_COUNT | 2 
IBUF\_REC\_OFFSET\_TYPE  | 1 
IBUF\_REC\_OFFSET\_FLAGS | 1  

IBUF\_REC\_OFFSET\_COUNT保存两个字节的整数，用来排序每个记录进入Insert Buffer的顺序。第五列开始是实际插入记录的各个字段。

启用Insert Buffer索引后，辅助索引页中的记录可能被插入到Insert Buffer B+树中，为保证每次Merge Insert Buffer页必须成功，需要特殊页用来标记每个辅助索引页（sapce，page_no）的可用空间。该页类型为Insert Buffer Bitamp。

每个Insert Buffer Bitmap页用来追踪16384个辅助索引页，即256个区（Extent）。每个Insert Buffer Bitmap页在16384个页的第二个页中。

每个辅助索引页在Insert Buffer Bitmap页中占用4位，由三部分组成：

名称 | 大小（bit） | 说明
:-: | :-: | :-:
IBUF\_BITMAP\_FREE | 2 | 表示该辅助索引页中的可用空间数量，可取值0，1，2，3。0表示无可用剩余空间；1表示剩余空间大于1/32页（512字节）
IBUF\_BITMAP\_BUFFERED | 1 | 1表示该辅助索引页有记录被缓存在Insert Buffer B+树中
IBUF\_BITMAP\_IBUF | 1 | 1表示该页为Insert Buffer B+树的索引页

##### Merge Insert Buffer

Merge Insert Buffer的操作发生在：

* 辅助索引页被读取到缓冲池时，例如执行正常的SELECT查询操作，这时需要检查Insert Buffer Bitmap页，然后确认该辅助索引页是否有记录存放于Insert Buffer B+树中，若有则将Insert Buffer B+树中该页的记录插入到该辅助索引页中；
* Insert Buffer Bitmap页追踪到该辅助索引页已无可用空间时，若插入辅助索引记录时检测到插入记录后可用空间会小于1/32页，则强制进行一个合并操作（强制读取辅助索引页），将Insert Buffer B+树中该页的记录及待插入的记录插入到辅助索引页中；
* Master Thread，每秒和每10秒进行一次的Merger Insert Buffer操作。

Mater Thread根据`srv_innodb_io_capactity`的百分比来决定真正要合并多少个辅助索引页。

Insert Buffer B+ Tree中，辅助索引页根据（space，offset）都已排序好，根据（space，offset）的排序顺序进行页的选择。


#### 两次写

doublewrite保障InnoDB存储引擎数据页的可靠性。

若发生写失效，可以通过重做日志进行恢复，但重做日志记录的是对页的物理操作，若页本身已损坏，则再对其重做是无意义的。在应用重做日志之前，需要一个页的副本，当写失效发生时，先通过页的副本还原页，在进行重做，即doublewrite。

doublewrite由两部分组成：内存中的doublewrite buffer，大小为2MB；物理磁盘上共享表空间中连续的128个页，即两个区（extent），大小为2MB。

在对缓冲池的脏页进行刷行时，并不直接写磁盘，会先通过memcpy函数将脏页先复制到内存中的doublewrite buffer，之后通过doublewrite buffer再分两次，每次1MB顺序地写入共享表空间的物理磁盘上，然后马上调用fsync函数，同步磁盘，避免缓冲写带来的问题。因为doublewrite页连续，过程是顺序写的，开销不大。完成doublewrite页的写入后，再将doublewrite buufer中的页写入各个表空间文件中，此时写入则是离散的，

通过`SHOW GLOBAL STATUS LIKE 'innodb_dblwr%'`观察doublewrite的运行情况：

```
mysql> show global status like 'innodb_dblwr%'\G
*************************** 1. row ***************************
Variable_name: Innodb_dblwr_pages_written
        Value: 269936
*************************** 2. row ***************************
Variable_name: Innodb_dblwr_writes
        Value: 26401
2 rows in set (0.00 sec)
```
表示一共写了269936个页，实际写入次数26401，`Innodb_dblwr_pages_written:Innodb_dblwr_writes`比例10:1。若系统高峰时远小于64:1，说明系统写入压力不是很高。


若操作系统在写入磁盘过程发生崩溃，在恢复时InnoDB先从共享表空间中的doublewrite中找到该页的一个副本，将其复制到表空间文件，再应用重做日志。

通过命令`SHOW BLOBAL STATUS like 'Innodb_buffer_pool_pages_flushed'`查看当前从缓冲池中刷新到磁盘页的数量。该变量和`Innodb_dblwr_pages_written`一致。MySQL 5.5.24版本之前，`Innodb_buffer_pool_pages_flushed`总是`Innodb_dblwr_pages_written`的2倍，之后才被修复，统计数据库在生产环境中写入的量，最安全的方法是根据`Innodb_dblwr_pages_written`来进行统计。

参数`skip_innnodb_doublewrite`可以禁用doublewrite功能，可能发生写失效问题，若有多个从服务器（slave server），需要提供较快的性能（在slave server上做RAID0），启用该参数是一个办法。对于需要提供数据高可用性的主服务器（master server），任何时候都应确保开启doublewrite功能。

有些文件系统本身就提供了部分写失效的防范机制，如ZFS文件系统，可不用开启doublewrite。

#### 自适应哈希索引
哈希一般查找的时间复杂度为O(1)，B+ Tree的查找次数取决于B+ tree的高度，一般为3～4层。

InnoDB会监控对表上各索引页的查询，若观察到建立哈希索引可以带来速度提升，则建立哈希索引，称之为自适应哈希索引（Adaptive Hash Index，AHI）。AHI通过缓冲池的B+ tree构建而来，建立的速度很快，不需要对整张表构建哈希索引。InnoDB会自动根据访问的频率和模式来自动地为某些热点页建立哈希索引。

AHI要求这个页的连续访问模式必须是一样的。如对（a，b）这样的联合索引页，访问模式可以是：

* WHERE a=xxx
* WHERE a=xxx and b=xxx

访问模式指查询条件一样，若交替上述两种查询，则不会对该页构造AHI。AHI还要求：

* 以该模式访问了100次
* 页通过该模式访问了N次，其中N=页中记录*1/16

启用AHI后，读取和写入速度可以提高2倍，辅助索引的连接操作性能可以提高5倍。其为数据库自由化，可通过命令`SHOW ENGINE INNODB STATUS`查看当前AHI的使用状况：

```
mysql> show engine innodb status\G
...
-------------------------------------
INSERT BUFFER AND ADAPTIVE HASH INDEX
-------------------------------------
Ibuf: size 1, free list len 12, seg size 14, 347 merges
merged operations:
 insert 1702, delete mark 3, delete 0
discarded operations:
 insert 0, delete mark 0, delete 0
1.04 hash searches/s, 4.33 non-hash searches/s
...
```

哈希索引只能用来搜索等值的查询，如SELECT \* FROM table WHERE index_col='xxx'。其他如范围查找不能使用哈希索引。通过hash searches:non-hash searches可以了解使用哈希索引后的效率。

可通过`SHOW ENGINE INNODB STATUS`的结果及参数`innodb_adaptive_hash_index`来考虑是禁用或启动，默认AHI开启。

#### 异步IO

