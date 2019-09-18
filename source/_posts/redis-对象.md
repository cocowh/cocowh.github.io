---
title: redis-对象
tags: [redis,redisObject]
comments: true
categories: [redis设计与实现]
date: 2019-09-17 11:26:38
---

基于数据结构创建对象系统，执行命令前根据对象的类型判断一个对象是否可以执行给定的命令。基于引用计数的内存回收机制，对象共享机制。带有访问时间信息，用于计算数据库键的空转时长，启用maxmemory功能下，空转时长较大的优先被服务器删除。

### 对象类型和编码

注：参考的最新代码redis v5.x.x

使用对象表示数据库中的键和值，创建新键值对时，至少创建两个对象，一个对象用作键值对的键（键对象），一个对象用作键值对的值（值对象）。

结构：

```
/* A redis object, that is a type able to hold a string / list / set */

/* The actual Redis Object */
/*
 * Redis 对象
 */
#define REDIS_LRU_BITS 24
#define REDIS_LRU_CLOCK_MAX ((1<<REDIS_LRU_BITS)-1) /* Max value of obj->lru */
#define REDIS_LRU_CLOCK_RESOLUTION 1000 /* LRU clock resolution in ms */
typedef struct redisObject {

    // 类型
    unsigned type:4;

    // 编码
    unsigned encoding:4;

    // 对象最后一次被访问的时间
    unsigned lru:LRU_BITS; /* LRU time (relative to global lru_clock) or
                            * LFU data (least significant 8 bits frequency
                            * and most significant 16 bits access time). */

    // 引用计数
    int refcount;

    // 指向实际值的指针
    void *ptr;

} robj;
```
类型：

```
/*-----------------------------------------------------------------------------
 * Data types
 *----------------------------------------------------------------------------*/

/* A redis object, that is a type able to hold a string / list / set */

/* The actual Redis Object */
#define OBJ_STRING 0    /* String object.字符串对象 */
#define OBJ_LIST 1      /* List object. 列表对象*/
#define OBJ_SET 2       /* Set object. 集合对象*/
#define OBJ_ZSET 3      /* Sorted set object. 有序集合对象*/
#define OBJ_HASH 4      /* Hash object. 哈希对象*/

/* The "module" object type is a special one that signals that the object
 * is one directly managed by a Redis module. In this case the value points
 * to a moduleValue struct, which contains the object value (which is only
 * handled by the module itself) and the RedisModuleType struct which lists
 * function pointers in order to serialize, deserialize, AOF-rewrite and
 * free the object.
 *
 * Inside the RDB file, module types are encoded as OBJ_MODULE followed
 * by a 64 bit module type ID, which has a 54 bits module-specific signature
 * in order to dispatch the loading to the right module, plus a 10 bits
 * encoding version. */
#define OBJ_MODULE 5    /* Module object. 直接由模块管理*/
#define OBJ_STREAM 6    /* Stream object. */
```
stream类型参考[浅入浅出Redis5.0的stream数据结构](http://xiaorui.cc/2018/06/07/%E6%B5%85%E5%85%A5%E6%B5%85%E5%87%BAredis5-0%E7%9A%84streams%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84/)

编码：

```
/* Objects encoding. Some kind of objects like Strings and Hashes can be
 * internally represented in multiple ways. The 'encoding' field of the object
 * is set to one of this fields for this object. */
#define OBJ_ENCODING_RAW 0     /* Raw representation 简单动态字符串*/
#define OBJ_ENCODING_INT 1     /* Encoded as integer long类型整数*/
#define OBJ_ENCODING_HT 2      /* Encoded as hash table 字典*/
#define OBJ_ENCODING_ZIPMAP 3  /* Encoded as zipmap 压缩map*/
#define OBJ_ENCODING_LINKEDLIST 4 /* No longer used: old list encoding. 不在使用，旧列表编码*/
#define OBJ_ENCODING_ZIPLIST 5 /* Encoded as ziplist 压缩列表*/
#define OBJ_ENCODING_INTSET 6  /* Encoded as intset 整数集合*/
#define OBJ_ENCODING_SKIPLIST 7  /* Encoded as skiplist 跳跃表*/
#define OBJ_ENCODING_EMBSTR 8  /* Embedded sds string encoding embstr实现的动态字符串*/
#define OBJ_ENCODING_QUICKLIST 9 /* Encoded as linked list of ziplists 压缩列表实现的快速列表*/
#define OBJ_ENCODING_STREAM 10 /* Encoded as a radix tree of listpacks */
```

### 字符串对象

编码可为int、raw或者embstr。保存的是整数值，且可用long类型表示，字符编码设置为int；若保存的是一个字符串值且长度小于等于39字节，使用embstr编码方式，超过使用row编码方式。

row调用两次内存分配函数分别创建redisObject结构和sdshdr结构，embstr通过调用一次内存分配函数来分配一块连续的空间，空间中依次包含redisObject和sdshdr两个结构。

对int编码或embstr编码的字符串追加，编码都会转变为row，没为这写编码的字符串编写相应的修改程序。

```
127.0.0.1:6379> set hi 123
OK
127.0.0.1:6379> object encoding hi
"int"
127.0.0.1:6379> append hi aaa
(integer) 6
127.0.0.1:6379> object encoding hi
"raw"
127.0.0.1:6379> set hi aaa
OK
127.0.0.1:6379> object encoding hi
"embstr"
127.0.0.1:6379> append hi aaabbb
(integer) 9
127.0.0.1:6379> object encoding hi
"raw"
127.0.0.1:6379> get hi
"aaaaaabbb"
127.0.0.1:6379> set hi aaaaaabbb
OK
127.0.0.1:6379> object encoding hi
"embstr"
127.0.0.1:6379> get hi
"aaaaaabbb"
127.0.0.1:6379> set hi 111
OK
127.0.0.1:6379> append hi 222
(integer) 6
127.0.0.1:6379> object encoding hi
"raw"
127.0.0.1:6379> get hi
"111222"
127.0.0.1:6379> 
```

### 内存回收

随着对象的使用状态改变：

* 创建一个新对象时，引用计数的值初始化为1；
* 被一个新程序使用时，引用计数值增1；
* 不再被一个程序使用时，引用计数值减1；
* 引用计数值为0时，对象所占的内存被释放。

### 对象共享

多个键共享一个值对象：

* 将数据库键的值指针指向一个现有的值对象；
* 将被共享的值对象的引用计数赠一。


### 对象的空转时长

lru属性，记录对象最后一次被命令程序访问的时间，

通过`OBJECT IDLETIME`命令打印给定键的空转时长，通过将当前时间减去键的值对象的lru时间计算得出，命令在访问键的对象时，不会修改值对象的lru属性。

打开maxmemory选项且服务器用于回收内存的算法为volatile-lru或allkeys-lru，占用内存数超过maxmemory选项所设置值，则空转时长较高的键优先被服务器释放，回收内存。



