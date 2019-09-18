---
title: redis-整数集合
tags: [redis,intset]
comments: true
categories: [redis设计与实现]
date: 2018-09-13 21:42:03
---

详细参阅[redis源码解读(四):基础数据结构之intset](http://czrzchao.com/redisSourceIntset#intset)。

是集合键的底层实现之一，当一个集合只包含整数值元素，并且集合的元素数量不多时，redis使用整数集合作为集合键的底层实现。

### 整数集合的实现

是redis用于保存整数值的集合抽象数据结构，可以保存类型为int16_t、int32_t或者int64_t的整数值，并且保证集合中不会出现重复元素。

由intset.h/intset结构表示:

```
typedef struct intset {
	unint32_t encoding;//编码方式
	unint32_t length;//集合包含的元素数量
	int8_t contents[];//保存元素的数组
} intset;
```
contents数组是整数集合的底层实现：整数集合的每个元素都是contents数组的一个数组项，数组中各项按值从小到大排列，且数组中不包含重复项。

length属性记录整数集合包含的元素数量，即contents数组的长度。

contents数组的真正类型取决于encoding属性的值。

```
/*
 * intset 的编码方式
 */
#define INTSET_ENC_INT16 (sizeof(int16_t))
#define INTSET_ENC_INT32 (sizeof(int32_t))
#define INTSET_ENC_INT64 (sizeof(int64_t))
```

根据整数集合的升级规则，当向一个底层为int16_t数组的整数集合添加一个int64_t类型的整数值时，整数集合已有的所有元素都会被转换成int64_t类型。

### 升级
将新元素添加到整数集合里面且新元素的类型比整数集合现有所有元素的类型都要长时，整数集合需要先进行升级，然后将新元素添加到整数集合里面。

升级过程：

* 根据新元素的类型，拓展整数集合底层数组的空间大小，并为新元素分配空间。
* 将底层数组现有的所有元素都转换成与新元素相同的类型，并将转换后的元素放置到正确的位置上，在放置的过程中维持底层数组的有序性质不变。
* 将新元素添加到底层数组中。

引发升级的新元素的长度总是比整数集合现在所有元素的长度都大，所以新元素的值要么大于所有现有元素，要么就小于所有现有元素。前者将新元素放置在底层数组的最开头（索引0），后者将新元素放置在底层数组的最末尾（索引length-1）。

>升级策略能提升整数集合的灵活性，尽可能地节约内存。

### 降级
整数集合不支持降级操作，一旦对数组进行了升级，编码就会一直保持升级后的状态。

### 整数集合API
整数集合操作API：

函数 | 作用 | 时间复杂度
:- | :- | :-
intsetNew | 创建一个新的压缩列表 | O(1)
intsetAdd | 将给定元素添加到整数集合里 | O(N)
intsetRemove | 从整数集合中移除给定元素 | O(N)
intsetFind | 检查给定值是否存在于集合 | O(logN)，二分查找法
intsetRandom | 从整数集合中随机返回一个元素 | O(1)
intsetGet | 取出底层数组在给定索引上的元素 | O(1)
intsetLen | 返回整数集合包含的元素的个数 | O(1)
intsetBlobLen | 返回整数集合占用的内存字节数 | O(1)