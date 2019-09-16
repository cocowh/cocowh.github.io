---
title: redis-链表
tags: [redis,链表]
comments: true
categories: [redis设计与实现]
date: 2018-09-09 21:24:28
---
redis构建了自己的链表实现。

列表键的底层实现之一就是链表，当一个列表键包含了数量比较多的元素，又或者列表中包含的元素都是比较长的字符串时，redis就会使用链表作为列表键的底层实现。

除列表键之外，发布与订阅、慢查询、监视器等功能也用到了链表，redis服务器本身还使用链表来保存多个客户端的状态信息，使用链表来构建客户端输出缓冲区。

### 链表和链表节点的实现
链表节点由adlist.h/listNode结构来表示：
```
typedef struct listNode {
	struct listNode *prev;//前置节点
	struct listNode *next;//后置节点
	void *value;//节点的值
} listNode;
```
使用多个listNode结构可组成链表，使用adlist.h/list来持有链表，操作起来更方便：

```
typedef struct list {
	listNode *head;//表头节点
	listNode *tail;//表尾节点
	unsigned long len;//链表所包含的节点的数量
	void *(*dup)(void *ptr);//节点值复制函数
	void *(*free)(void *ptr);//节点值释放函数
	int (*match)(void *ptr, void *key);//节点值对比函数
} list;
```
提供了表头指针head，表尾指针tail，链表长度计数器len，dup、free和match用于实现多态链表所需的类型特定函。

redis链表实现的特性：

* 双端。
* 无环。
* 带表头指针和表尾指针。
* 带链表长度计数器。
* 多态：链表节点使用void*指针来保存节点值，可以通过list结构的dup、free、match三个属性为节点值设置类型特定函数，链表可用于保存各种不同类型的值。

### 链表和链表节点的API
链表和链表节点的API：

函数 | 作用 | 时间复杂度
:- | :- | :-
listSetDupMethod | 将给定的函数设置为链表的节点值复制函数 | O(1)，可通过链表的dup属性直接获得
listGetDupMethod | 返回链表当前正在使用的节点值复制函数 | O(1)
listSetFreeMethod | 将给定的函数设置为链表的节点值释放函数 | O(1)，可通过链表的free属性直接获得
listGetFree | 返回链表当前正在使用的节点值释放函数 | O(1)
listSetMatchMethod | 将给定的函数设置为链表的节点值对比函数 | O(1)
listGetMatchMethod | 返回链表当前正在使用的节点值对比函数 | O(1)
listLength | 返回链表的长度（包含了多少个节点） | O(1)，链表的len属性
listFirst | 返回链表的表头节点 | O(1)，链表的head属性
listLast | 返回链表的表为节点 | O(1)，链表的tail属性
listPrevNode | 返回给定节点的前置节点 | O(1)，节点的prev属性
listNextNode | 返回给定节点的后置节点 | O(1)，节点的next属性
listNodeValue | 返回给定节点目前正在保存的值 | O(1)，节点的value属性
listCreate | 创建一个不包含任何节点的新链表 | O(1)
listAddNodeHead | 将一个包含给定值的新节点添加到给定链表的表头 | O(1)
listAddNodeTail | 将一个包含给定值的新节点添加到给定链表的表尾 | O(1)
listInsertNode | 将一个包含给定值的新节点添加到给定节点的之前或者之后 | O(1)
listSearchKey | 查找并返回链表中包含给定值的节点 | O(N)，N为链表长度
listIndex | 返回链表在给定索引上的节点 | O(N)，N为链表长度
listDelNode | 从链表中删除给定节点 | O(N)，N为链表长度
listRotate | 将链表的表尾节点弹出，然后将被弹出的节点插入到链表的表头，成为新的表头节点 | O(1)
listDup | 复制一个给定链表的副本 | O(N)，N为链表长度
listRelease | 释放给定链表，以及链表中的所有节点 | O(N)，N为链表长度