---
title: redis-跳跃表
tags: [redis,skiplist]
comments: true
categories: [redis]
date: 2018-09-12 21:37:34
---
跳跃表是一种有序的数据结构，通过在每个节点中维持多个指向其他节点的指针，达到快速访问节点的目的。支持平均O(logN)，最坏O(N)复杂度的节点查找。可以通过顺序性操作来批量处理节点。

redis使用跳跃表作为有序集合键的底层实现之一，若有序集合包含的元素数量比较多，或者有序集合中元素的成员是比较长的字符串时，redis就会使用跳跃表来作为有序集合键的底层实现。

redis只在实现有序集合键和在集群节点用作内部数据结构用到跳跃表。

### 跳跃表的实现
由redis.h/zskiplistNode和redis.h/zskiplist两个结构定义，前者用于表示跳跃表节点，后者用于保存跳跃表节点的相关信息，例如节点的数量、指向表头节点和表尾节点的指针等。

#### 跳跃表节点
由redis.h/zskiplistNode结构定义：

```
typedef struct zskiplistNode {
	struct zskiplistLevel {
		struct zskiplistNode *forward;//前进指针
		unsigned int 	span;//跨度
	} level[];//层
	struct zskiplistNode *backward;//后退指针
	double score;//分值
	robj *obj;//成员对象
} zskiplistNode;
```
* level数组可以包含多个元素，每个元素包含一个指向其他节点的指针，可通过这些层加快访问其他节点的速度，一般层数量越多访问其他节点的速度越快。每创建一个新跳跃表节点的时候，程序根据幂次定律随机生成一个介于1和32之间的值作为level数组的大小，即层的高度。
* 每个层都有一个指向表尾方向的前进指针，用于从表头向表尾方向访问节点。
* 跨度用于记录两个节点之间的距离，跨度越大，节点间距离越远，指向NULL的所有前进指针的跨度都为0。实际上用来计算排位（rank），在查找某个节点的过程中，将沿途访问过的所有层的跨度累计，得到的结果就是目标节点在跳跃表中的排位。
* 后退指针用于从表尾向表头方向访问节点，每个节点中有一个后退节点，每次只能后退至前一个节点。
* 分值是一个double类型的浮点数，跳跃表中的所有节点都按分值从小到大来排序，成员对象是一个指针，指向一个字符串对象，字符串对象则保存着一个SDS值。同一跳跃表中，各个节点保存的成员对象必须是唯一的，多个节点保存的分值可以相同：分值相同的节点按照成员对象在字典序中的大小进行排序，成员对象较小的节点排在前面。

#### 跳跃表
由redis.h/zskiplist结构定义：

```
typedef struct zskiplist {
	struct zskiplistNode *header, *tail;//表头节点和表尾节点
	unsigned long length;//表中节点的数量
	int level;//表中层数最大节点的层数
} zskiplist;
```
### 跳跃表API
跳跃表的所有操作API:

函数 | 作用 | 时间复杂度
:- | :- | :-
zslCreate | 创建一个新的跳跃表 | O(1)
zslFree | 释放给定跳跃表以及表中包含的所有节点 | O(N)，N为跳跃表的长度
zslInsert | 将包含给定成员和分值的新节点添加到跳跃表中 | 平均O(logN)，最坏O(N)，N为跳跃表长度
zslDelete | 删除跳跃表中包含给定成员和分值的节点 | 平均O(logN)，最坏O(N)，N为跳跃表长度
zslGetRank | 返回包含给定成员和分值的节点在跳跃表中的排位 | 平均O(logN)，最坏O(N)，N为跳跃表长度
zslGetElementByRank | 返回跳跃表在给定排位上的节点 | 平均O(logN)，最坏O(N)，N为跳跃表长度
zslIsInRange | 判断跳跃表中是否有节点的分值在给定分值范围内 | O(1）
zslFirstInrange | 返回跳跃表中第一个分值在给定分值范围内的节点 | 平均O(logN)，最坏O(N)，N为跳跃表长度
zslLastInrange | 返回跳跃表中最后一个分值在给定分值范围内的节点 | 平均O(logN)，最坏O(N)，N为跳跃表长度
zslDeleteRangeByScore | 删除跳跃表中所有在给定分值范围内的节点 | O(N)，N为被删除节点的数量
zslDeleteRangeByRank | 删除跳跃表中所有在给定排位范围内的节点 | O(N)，N为被删除节点的数量
