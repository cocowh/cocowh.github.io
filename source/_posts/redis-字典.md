---
title: redis-字典
tags: [redis,dict,字典]
comments: true
categories: [redis]
date: 2018-09-10 21:30:23
---
又称符号表、关联数组或映射，一种用于保存键值对的抽象数据结构。

一个键可以和一个值进行关联，字典中的每个键都是独一无二的，通过键查找与之关联的值、更新值或删除整个键值对。

redis构建了自己的字典实现，redis数据库使用字典作为底层实现，对数据库的增、删、改、查操作也是构建在对字典的操作之上。字典还是哈希键的底层实现之一，当一个哈希键包含的键值对比较多，又或者键值对中的元素都是比较长的字符串时，redis就会使用字典作为哈希键的底层实现。

### 字典的实现
redis字典使用哈希表作为底层实现，一个哈希表里面可以有多个哈希表节点，而每个哈希表节点就保存了字典中的一个键值对。

#### 哈希表
由dict.h/dictht结构定义：

```
typedef struct dictht {
	dictEntry **table;//哈希表数组
	unsigned long size;//哈希表大小
	unsigned long sizemask;//哈希表大小掩码，用于计算索引值，等于size-1
	unsigned long used;//该哈希表已有节点的数量
} dictht;
```
table属性是一个数组，数组中的每个元素都是一个指向dict.h/dictEntry结构的指针，每个dictEntry结构都保存着一个键值对。

#### 哈希表节点
哈希表节点使用dictEntry结构表示，每个dictEntry结构都保存着一个键值对:

```
typedef struct dictEntry {
	void *key;//键
	union {
		void *val;
		uint64_tu64;
		int64_ts64;
	} v; //值
	struct dictEntry *next;//指向下个哈希表节点，形成链表
} dictEntry;
```
next属性是一个指向哈希表节点的指针，可以将多个哈希表值相同的键值对链接在一起，以此来解决键冲突的问题。

#### 字典
由dict.h/dict结构表示：

```
typedef struct dict {
	dictType *type;//类型特定函数
	void *privdata;//私有数据
	dictht ht[2];//哈希表
	int rehashidx;//rehash索引，当rehash不再进行时，值为-1  
	
} dict;
```
type属性和privdata属性是针对不同类型的键值对，为创建多态字典而设置：

* type属性是一个指向dictType结构的指针，每个dictType结构保存了一簇用于操作特定类型键值对的函数，redis会为用途不同的字典设置不同的类型特定函数。
* privdata属性保存了需要传给那些类型特定函数的可选参数。

```
typedef struct dictType {
	unsigned int (*hashFunction)(const void *key);//计算哈希值的函数
	void *(*keyDup)(void *privdata, const void *key);//复制键的函数
	void *(*valDup)(void *privdata, const void *key);//复制值的函数
	int (*keyCompare)(void *privdata, const void *key1, const void *key2);对比键的函数
	void (*keyDestructor)(void *privdata, void *key);//销毁键的函数
	void (*valDestructor)(void *privdata, void *obj);//销毁值的函数
} dictType;
```
ht属性是一个包含两个项的数组，数组中的每个项都是一个dictht哈希表，一般情况下，字典只使用ht[0]哈希表，ht[1]哈希表只会在对ht[0]哈希表进行rehash时使用。

rehashidx属性记录rehash目前的进度，若没有在进行rehash，则值为-1。

### 哈希算法
将一个新的键值对添加到字典里面时，程序需要先根据键值对的键计算出哈希值和索引值，然后再根据索引值，将包含新键值对的哈希表节点放到哈希表数组的指定索引上面。

redis计算哈希值和索引值：

```
//使用字典设置的哈希函数，计算键key的哈希值
hash = dict->type->hashFunction(key);
//使用哈希表的sizemask属性和哈希值，计算出索引值
//ht[x]根据情况选择ht[0]和ht[1]
index = hash & dict->ht[x].sizemask;
```
当字典被用作数据库的底层实现，或者哈希键的底层实现时，redis使用MurmurHash2算法来计算哈希值。

### 解决键冲突
当有两个或以上数量键被分配到了哈希数组的同一个索引上面时，称这些键发生了冲突。

redis的哈希表使用链表链地址法来解决键冲突，每个哈希表节点都有一个next指针，多个哈希表节点可以使用next指针构成一个单向链表，被分配到同一个索引上的多个节点可以用这个单项链表连接起来，解决键冲突问题。速度考虑，程序总是将新节点添加到链表的表头位置，排在其他已有节点的前面。

### rehash
为让哈希表的负载因子维持在一个合理的范围之内，哈希表保存的键值对数量太多或者太少时，程序需要对哈希表的大小进行相应的拓展或者收缩，通过执行rehash（重新散列）操作来完成。步骤如下：

1. 为字典的ht[1]哈希表分配空间，哈希表的空间的大小取决于要执行的操作，以及ht[0]当前包含的键值对数量。
2. 若执行的是扩展操作，则ht[1]的大小为第一个大于等于ht[0].used*2的2^n;
若执行的是收缩操作，那么ht[1]的大小为第一个大于等于ht[0].used的2^n。
将保存在ht[0]中的所有键值对rehash到ht[1]上面：rehash重新计算键的哈希值和索引，然后将键值对放置到ht[1]哈希表的指定位置上。
3. 当ht[0]包含的所有键值对都迁移到了ht[1]之后（ht[0]表变为空表），释放ht[0]，将ht[1]设置为ht[0]，并在ht[1]新创建一个空白哈希表，为下一次rehash作准备。

`哈希表的拓展和收缩`：

>服务器目前没有执行BGSAVE命令或者BGREWRITEAOF命令，并且哈希表的负载因子大于等于1。  
服务器目前正在执行BGSAVE命令或者BGREWRITEAOF命令，并且哈希表的负载因子大于等于5。  
>哈希表的负载因子计算公式：  
 负载因子 = 哈希表已保存节点数量 / ht[0].size
 load_factor = ht[0].used / ht[0].size

根据BGSAVE命令和BGREWRITEAOF命令是否正在执行，服务器执行拓展操作所需的负载因子并不相同。在执行BGSAVE命令或者BGREWRITEAOF命令的过程中，redis需要创建当前服务器进程的子进程，大多数操作系统都采用写时复制（copy-on-write）技术来优化子进程的使用效率，在子进程存在期间，服务器会提高执行拓展操作所需的负载因子，尽可能地避免在子进程存在期间进行哈希表拓展操作，避免不必要的内存写入操作，节约内存。

当哈希表的负载因子小于0.1时，程序自动开始对哈希表执行收缩操作。

### 渐进式rehash
扩展或收缩哈希表需要将ht[0]里面的所有键值对rehash到ht[1]里面，为避免数据量过大rehash对服务器性能造成影响，rehash动作是分多次、渐进式地完成的，当数据量过大时将rehash键值对所需的计算工作均摊到对字典的每个添加、删除、查找和更新操作上，避免了集中式rehash而带来的庞大计算量。

哈希表渐进式rehash的步骤：

1. 为ht[1]分配空间，让字典同时持有ht[0]和ht[1]两个哈希表。
2. 在字典中维持一个索引计数器变量rehashidx，并将它的值设置为0，表示rehash工作正式开始。
3. 在rehash进行期间，每次对字典执行添加、删除、查找或者更新操作时，程序除了执行指定的操作之外，还会顺带将ht[0]哈希表在rehashidx索引上的所有键值对rehash到ht[1]，当rehash工作完成之后，程序将rehashidx属性的值增一。
4. 随着字典操作的不断执行，最终在某个时间点上，ht[0]的所有键值对都会被rehash至ht[1]，这时程序将rehashidx属性的值设为-1，表示rehash操作已经完成。

在渐进式rehash执行期间，字典的删除、查找、更新等操作会在两个哈希表上进行，新添加到字典的键值对一律会被保存到ht[1]里面，而ht[0]则不再进行任何操作。

### 字典API
字典的主要操作API

函数 | 作用 | 时间复杂度
:- | :- | :-
dictCreate | 创建一个新的字典 | O(1)
dictAdd | 将给定的键值对添加到字典里面 | O(1)
dictReplace | 将给定的键值对添加到字典里面，如果键已经存在于字典，用新值取代原有的值 | O(1)
dictFetchValue | 返回给定键的值 | O(1)
dictGetRandomKey | 从字典中随机返回一个键值对 | O(1)
dictDelete | 从字典中删除给定键所对应键值对 | O(1)
dictRelease | 释放给定字典，以及字典中包含的所有键值对 | O(N)，N为字典包含的键值对数量
