---
title: redis基本数据结构及命令
tags: [redis,cli]
comments: true
categories: [redis]
date: 2018-08-01 19:46:12
---
### redis基本数据结构
结构类型 | 结构存储的值 | 结构的读写能力
:- | :- | :-
STRING	| 字符串、整数或者浮点数 | 对整个字符串或者字符串中的一部分执行操作；整数或浮点数自增、自减操作
LIST | 链表，链表上的每个节点都包含了一个字符 | 链表两端推入或者弹出元素；根据偏移量对链表进行修剪；读取单个或多个元素；根据指查找或着移除元素
SET | 字符串的无序收集器，被包含的每个字符串都是独一无二的、各不相同的 | 添加、获取、移除单个元素；检查一个元素是否存在于集合中；计算交集、并集、差集；从集合里面随机获取元素
HASH | 包含键值对的无序散列表 | 添加、获取、移除单个键值对；获取所有键值对
ZSET(有序集合) | 字符串成员与浮点数分值之间的有序映射，元素的排列顺序由分值的大小决定 | 添加、获取、删除单个元素；根据分值范围或者成员来获取元素

#### Redis中的字符串
与其他编程语言或者其他键值存储提供的字符串非常相似。

#### Redis中的列表
一个列表结构可以有序地存储多个字符串。可执行的操作与很多编程语言中的列表操作非常相似。

#### Redis中的集合
存储多个字符串，不同于列表，集合使用无序方式存储元素，使用散列表保证存储的每个字符串都是不同的。

#### Redis中的散列
存储多个键值对之间的映射，散列存储的值既可以是字符串也可以是数字值。类似文档数据库中的文档，关系数据库中的行，允许用户同时访问或者修改一个或多个域。

#### Redis中的有序集合
用于存储键值对，键被称为成员，每个成员各不相同，值被称为分值，分值必须为浮点数。唯一既可以根据成员访问元素，又可以根据分值及分值的排列顺序来访问元素的结构。

### Redis命令
#### 字符串
Redis中的自增命令和自减命令：

命令 | 用例和描述
:- | :-
LNCR | INCR key-name——将键存储的值加上1
DECR | DECR key-name——将键存储的值减去1
INCRBY | INCRBY key-name amount——将键存储的值加上amount
DECRBY | DECRBY key-name amount——将键存储的值减去amount
INCRBYFLOAT | INCRBYFLOAT key-name amount——将键存储的值加上浮点数amount，redis v2.6+
存储时，若值可被解释（interpret）为十进制整数或者浮点数，则允许用户对字符串执行各种INCR\*和DECR\*操作。对不存在的键或者保存了空串的键执行自增或者自减操作，Redis执行操作时将键的值当作0处理。对无法解释为整数或浮点数的字符串键执行自增或自减操作，将向用户返回一个错误。

处理子串和二进制位的命令：

命令 | 用例和描述
:- | :-
APPEND | APPEND key-name value——将值value追加到给定键key-name当前存储的值的末尾
GETRANGE | GETRANGE key-name start end——获取一个由偏移量start至偏移量end范围内所有字符组成的子串，包括start和end在内。
SETRANGE | SETRANGE key-name offset value——将start偏移量开始的子串设置为给定值
GETBIT | GETBIT key-name offset——将子节串看作是二进制位串，并将位串中偏移量为offset的二进制位的值设置为value
BITCOUNT | BITCOUNT key-name [start end]——统计二进制位串里面值为1的二进制位的数量，若给定偏移量start和end，则只对偏移量指定范围内的二进制位进行统计
BITOP | BITOP operation dest-key key-name [key-name …]——对一个或多个二进制位串执行包括并（AND）、或（OR）、异或（XOR）、非（NOT）在内的任意一种按位运算操作，并将计算结果保存在dest-key键里

使用STRANGE或者SETBIT命令对字符串进行写入的时候，若字符串当前的长度不能满足写入的要求，Redis会自动地使用空字节（null）将字符串扩展至所需的长度，然后才执行写入或者更新操作。使用GETRANGE读取字符串，超出字符串末尾的数据会被视为是空串，使用GETBIT读取二进制位串，超出字符串末尾的二进制位会被视为0。

#### 列表
常用的列表命令：

命令 | 用例和描述
:- | :-
RPUSH | RPUSH key-name value [value …]——将一个或多个值推入列表的右端
LPUSH | LPUSH key-name value [value …]——将一个或多个值推入列表的左端
RPOP | RPOP key-name——移除并返回列表最右端的元素
LPOP | LPOP key-name——移除并返回列表最左端的元素
LINDEX | LINDEX key-name offset——返回列表中偏移量为offset的元素
LRANGE | LRANGE key-name start end——返回列表从start偏移量到end偏移量范围内的所有元素，偏移量start和end的元素也会包含在被返回的元素之内
LTRIM | LTRIM ley-name start end——对列表进行修剪，只保留从start偏移量到end偏移量范围内的元素，偏移量start和end的元素也会保留

阻塞式的列表弹出民命令以及在列表之间移动元素的命令：

命令 | 用例和描述
:- | :-
BLPOP | BLPOP key-name [key-name …] timeout——从第一个非空列表中弹出位于最左端的元素，或者在timeout秒之内阻塞并等待可弹出的元素出现
BRPOP | BRPOP key-name [key-name …] timeout——从第一个非空列表中掏出位于最右端的元素，或者在timeout秒之内阻塞并等待可弹出的元素出现
RPOPLPUSH | RPOPLPUSH source-key dest-key——从source-key列表中弹出位于最右端的元素，然后将这个元素推入dest-key列表的最左端，并向用户返回这个元素
BRPOPLPUSH | BRPOPLPUSH source-key dest-key timeout——从source-key列表中弹出位于最右端的元素，然后将这个元素推入dest-key列表的最左端，并向用户返回这个元素，若source-key为空，则在timeout秒之内阻塞并等待可弹出的元素出现

应用于消息传递、任务队列。

#### 集合
以无序的方式存储多个各不相同的元素。

常用集合命令：

命令 | 用例和描述
:- | :-
SADD | SADD key-name item [item …]——将一个或多个元素添加到集合中，并返回被添加元素当中原本并不存在于集合里面的元素数量
SREM | SREM key-name item [item …]——从集合里面移除一个或多个元素，并返回被移除元素的数量
SISMEMBER | SISMEMBER key-name item——检查元素item是否存在于集合key-name里
SCARD | SCARD key-name——返回集合包含的元素的数量
SMEMBERS | SMEMBERS key-name——返回集合包含的所有元素
SRANDMEMBER | SRANDMEMBER key-name [count]——从集合里面随机地返回一个或多个元素。当count为正数时，命令返回的随机元素不会重复；当count为负数时，命令返回的随机元素可能会出现重复
SPOP | SPOP key-name——随机地移除集合中的一个元素，并返回被移除的元素
SMOVE | SMOVE source-key dest-key item——若集合source-key包含元素item，从集合source-key里面移除元素item，并将元素item添加到集合dest-key中；若item被成功移除，命令返回1，否则返回0

组合和处理多个集合的redis命令：

命令 | 用例和描述
:- | :-
SDIFF | SDIFF key-name [key-name …]——返回那些存在于第一个集合、但不存在于其他集合中的元素（差集运算）
SDIFFSTORE | SDIFFSTORE dest-key key-name [key-name …]——将存在于第一个集合但并不存在于其他集合中的元素（差集运算）存储到dest-key键里面
SINTER | SINTER key-name [key-name …]——返回那些同时存在于所有集合中的元素（交集运算）
SINTERSTORE | SINTERSTORE dest-key key-name [key-name …]——将同时存在于所有集合中的元素（交集运算）存储到dest-key键里面
SUNION | SUNION key-name [key-name …]——返回至少存在于一个集合中的元素（并集运算）
SUNIONSTORE | SUNIONSTORE desk-key key-name [key-name …]——将至少存在于一个集合中的元素（并集运算）存储到dest-key键里面

#### 散列
适用于将一些相关的数据存储在一起。

添加和删除键值对的散列操作：

命令 | 用例和描述
:- | :-
HMGET | HMGET key-name key [key …]——从散列里面获取一个或多个键的值
HMSET | HMSET key-name key value [key value …]——为散列里面的一个或多个键设置值
HDEL | HDEL key-name key [key …]——删除散列里面的一个或多个键值对，返回成功找到并删除的键值对的数量
HLEN | HLEN key-name——返回散列包含的键值对的数量

散列的批量操作命令以及和字符串操作类似的散列命令：

命令 | 用例和描述
:- | :-
HEXISTS | HEXISTS key-name key——检查给定键是否存在于散列中
HKEYS | HKEYS key-name——获取散列包含的所有键
HVALS | HVALS key-name——获取散列包含的所有值
HGETALL | HGETALL key-name——获取散列包含的所有键值对
HINCRBY | HINCRBY key-name key increment——将键key存储的值加上整数increment
HINCRBYFLOAT | HINCRBYFLOAT key-name key increment——将键key存储的值加上浮点数increment


#### 有序集合
存储着成员与分值之间的映射，提供了分值处理命令，分值在Redis中以IEEE 175双精度浮点数的格式存储。

常用的有序集合命令：

命令 | 用例和描述
:- | :-
ZADD | ZADD key-name score member [score member …]——将带有给定分值的成员添加到有序集合里面
ZREM | ZREM key-name member [member …]——从有序集合里面移除给定的成员，并返回被移除成员的数量
ZCARD | ZCARD key-name——返回有序集合包含的成员数量
ZINCRBY | ZINCRBY key-name increment member——将member成员的分值加上increment
ZCOUNT | ZCOUNT key-name min max——返回分值介于min和max之间的成员数量
ZRANK | ZRANK key-name member——返回成员member在有序集合中的排名
ZSCORE | ZSCORE key-name member——返回成员memebr的分值
ZRANGE | ZRANGE key-name start stop [WITHSCORES]——返回有序集合中排名介于start和stop之间的成员，若给定了可选的WITHSCORES选项，则命令会将成员的分值一并返回

有序集合的范围型数据获取命令和范围型数据删除命令、并集命令、交集命令：

命令 | 用例和描述
:- | :-
ZREVRANK | ZREVRANK key-name member——返回有序集合里成员member的排名，成员按照分值从大到小排列
ZREVRANGE | ZREVRANGE key-name start stop [WITHSCORES]——返回有序集合给定排名范围内的成员，成员按照分值从大到小排列
ZRANGEBYSCORE | ZRANGEBYSCORE key min max [WITHSCORES][LIMIT offset count]——返回有序集合中，分值介于min和max之间的所有成员
ZREVRANGEBYSCORE | ZREVRANGEBYSCORE key max min [WITHSCORES][LIMIT offset count]——获取有序集合中分值介于min和max之间的所有成员，并按照分值从大到小的顺序来返回它们
ZREMRANGEBYRANK | ZREMRANGEBYRANK key-name start stop——移除有序集合中排名介于start和stop之间的所有所有成员
ZREMRANGEBYSCORE | ZREMRANGEBYSCORE key-name min max——移除有序集合中分值介于min和max之间的所有成员
ZINTERSTORE | ZINTERSTORE dest-key key-count key [key …][WEIGHTS weight [weight …]][AGGREGATE SUM &#124; MIN &#124; MAX]——对给定的有序集合执行类似于集合的交集运算
ZUNIONSTORE | ZUNIONSTORE dest-key key-count key [key …][WEIGHTS weight [weight …]][AGGREGATE SUM &#124; MIN &#124; MAX]——对给定的有序集合执行类似于集合的并集运算

#### 发布与订阅
发布与订阅（pub/sub）是订阅者（listener）负责订阅频道（channel），发送者（publisher）负责向频道发送二进制字符串消息。当有消息被发送至给定频道时，频道的所有订阅者都会收到消息。

发布与订阅命令：

命令 | 用例和描述
:- | :-
SUBSCRIBE | SUBSCRIBE channel [channel …]——订阅给定的一个或多个频道
UNSUBSCRIBE | UNSUBSCRIBE [channel [channel …]]——退订给定的一个或多个频道，若执行时没给定频道，则退订所有频道
PUBLISH | PUBLISH channel message——向给定频道发送消息
PSUBSCRIBE | PSUBSCRIBE pattern [pattern …]——订阅与给定模式相匹配的所有频道
PUNSUBSCRIBE | PUNSUBSCRIBE [pattern [pattern …]]——退订给定的模式，如果执行时没有给定任何模式，则退订所有模式

#### 其他命令
##### 排序
同其他编程语言的排序操作，可以根据某种比较规则对一系列元素进行有序的排列。可根据字符串、列表、集合、有序集合、散列这5种键里面存储着的数据，对列表、集合以及有序集合进行排序，相当于SQL中的order by子句。

命令 | 用例和描述
:- | :-
SORT | SORT source-key [BY pattern][LIMIT offset count][GET pattern [GET PATTERN …]][ASC &#124; DESC][ALPHA][STORE dest-key]——根据给定的选项，对输入列表、集合或者有序集合进行排序，然后返回或者存储排序的结果

可实现的功能：根据降序而不是默认的升序来排序元素；将元素看作是数字来进行排序，或则将元素看作是数字来进行排序，或者将元素看作是二进制字符串来进行排序；使用被排序元素之外的其他值作为权重来进行排序，可从输入的列表、集合、有序集合以外的其他地方进行取值。

对集合进行排序返回一个列表形式的排序结果。

##### 基本的Redis事务
让用户在不被打断的情况下对多个键执行操作：WATCH、MULTI、EXEC、UNWATCH和DISCARD。

基本事务（basic transaction）使用MULTI命令和EXEC命令，让一个客户端在不被其他客户端打断的情况下执行多个命令。被MULTI命令和EXEC命令包围的所有命令会一个接一个地执行，直到所有命令都执行完毕为止。事务执行后，Redis才会处理其他客户端的命令。

Redis接收到MULTI命令时，Redis会将这个客户端之后发送的所有命令都放入到一个队列里面，直到这个客户端发送EXEC命令为止，接着Redis在不被打断的情况下，一个接一个地执行存储在队列里面的命令。

使用WATCH命令对键进行监视之后，直到用户执行EXEC命令的这段时间里，如果有其他客户端抢先对键进行了替换、更新或删除等操作，当用户尝试执行EXEC命令时，事务将失败并返回一个错误。UNWATCH命令可以在WATCH命令执行以后、MULTI命令执行之前对连接进行重置；DISCARD命令在MULTI命令执行之后、EXEC命令执行之前对连接进行重置。即在用户使用WATCH监视一个或多个键，接着使用MULTI开始一个新的事务，并将多个命令入队到事务队列后，仍然可以通过发送DISCARD命令来取消WATCH命令并清空所有已入队命令。

##### 键的过期时间
指Redis会在键的过期时间到达时自动删除该键。

为键设置过期时间的命令：

命令 | 示例和描述
:- | :-
PERSIST | PERSIST key-name——移除键的过期时间
TTL | TTL key-name——查看给定键距离过期还有多少秒
EXPIRE | EXPIRE key-name seconds——让给定键在指定的秒数之后过期
EXPIREAT | EXPIREAT key-name timestamp——将给定键的过期时间设置为给定的UNIX时间戳
PTTL | PTTL key-name——查看给定键距离过期时间还有多少毫秒，Redis V2.6+
PEXPIRE | PEXPIRE key-name milliseconds——让给定键在指定的毫秒数之后过期，Redis V2.6+
PEXPIREAT | PEXPIREAT key-name timestamp-milliseconds——将一个毫秒级精度的UNIX时间戳设置为给定键的过期时间，Redis V2.6+