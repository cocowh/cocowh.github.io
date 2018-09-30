---
title: EXPLAIN[查询执行计划]
tags: [mysql,explain]
comments: true
categories: [mysql]
date: 2018-08-02 20:33:32
---
### EXPLAIN
通过EXPLAIN命令获取关于查询执行计划的信息，是查看查询优化器如何决定执行查询的主要方法。
### 调用EXPLAIN
在查询中的SELECT关键字之前增加EXPLAIN，MySQL会在查询上设置一个标记，执行查询时，标记会使其返回关于在执行计划中每一步的信息，而不是执行它。返回一行或多行信息，显示出执行计划中的每一部分和执行的顺序。

```
explain select * from `users` where `remember_token` = 'y$ihqfHMTKSbq671vFbQ0/nePPH8dAYolKmuXzTcW7nF1BmoNcqjI0S' \G;
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: users
   partitions: NULL
         type: ref
possible_keys: remember_token
          key: remember_token
      key_len: 403
          ref: const
         rows: 1
     filtered: 100.00
        Extra: NULL
```
查询中每个表在输出中只有一行，若查询为两个表的联接，输出则有两行，别名表单算为一个表，因此把一个表与自己联接，输出也有两行。表：一个子查询，一个UNION结果等等。

EXPLAIN的两个主要变种：

* EXPLAIN EXTENED：使服务器“逆向编译”执行计划为一个SELECT语句。通过继续运行SHOW WARNINGS查看生成的语句。语句直接来自执行计划，不是原SQL语句，此时为一个数据结构。大部分场景下与原语句不同。

```
[mysql> explain extended select * from `users` where `remember_token` = 'y$ihqfHMTKSbq671vFbQ0/nePPH8dAYolKmuXzTcW7nF1BmoNcqjI0S' \G;
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: users
   partitions: NULL
         type: ref
possible_keys: remember_token
          key: remember_token
      key_len: 403
          ref: const
         rows: 1
     filtered: 100.00
        Extra: NULL
1 row in set, 2 warnings (0.00 sec)

ERROR: 
No query specified

mysql> show warnings;                                                                                                      +---------+------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Level   | Code | Message                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
+---------+------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Warning | 1681 | 'EXTENDED' is deprecated and will be removed in a future release.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Note    | 1003 | /* select#1 */ select `login`.`users`.`id` AS `id`,`login`.`users`.`name` AS `name`,`login`.`users`.`email` AS `email`,`login`.`users`.`password` AS `password`,`login`.`users`.`profile_status` AS `profile_status`,`login`.`users`.`remember_token` AS `remember_token`,`login`.`users`.`last_login_ip` AS `last_login_ip`,`login`.`users`.`created_at` AS `created_at`,`login`.`users`.`updated_at` AS `updated_at` from `login`.`users` where (`login`.`users`.`remember_token` = 'y$ihqfHMTKSbq671vFbQ0/nePPH8dAYolKmuXzTcW7nF1BmoNcqjI0S') |
+---------+------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
2 rows in set (0.00 sec)

mysql>
```
* EXPLAIN PARTITIONS：若查询基于分区表，显示查询将访问的分区

```
[mysql> explain partitions select * from `users` where `remember_token` = 'y$ihqfHMTKSbq671vFbQ0/nePPH8dAYolKmuXzTcW7nF1BmoNcqjI0S' \G;
*************************** 1. row ***************************
           id: 1
  select_type: SIMPLE
        table: users
   partitions: NULL
         type: ref
possible_keys: remember_token
          key: remember_token
      key_len: 403
          ref: const
         rows: 1
     filtered: 100.00
        Extra: NULL
1 row in set, 2 warnings (0.00 sec)
```
若查询的from子句中包括子查询，则mysql会执行子查询并将其结果放在一个临时表中，然后完成外层查询优化。必须在可以完成外层查询优化之前处理所有类似的子查询（V5.6中被取消），意味着若语句包含开销较大的子查询或使用临时表，实际会给服务器带来大量工作。

限制：

* 不会显示触发器、存储过程或UDF会如何影响查询。
* 不支持存储过程、尽管可以可以手动抽取查询并单独地对其进行EXPLAIN操作。
* 不会显示MySQL在查询执行中所做的特定优化。
* 不会显示关于查询的执行计划的所有信息。
* 不区分具有相同名字的事务。
* 可能会误导。

### 重写非SELECT查询
EXPLAIN只能解释SELECT查询，不会对存储程序调用和INSERT、UPDATE、DELETE或其他语句做解释。通过将非SELECT语句转化为一个等价的访问所有相同列的SELECT，重写这些语句以利用EXPLAIN。

显示计划时，对于写查询没有“等价”的读查询。一个SELECT查询只需要找到数据的一份副本并返回，任何修改数据的查询必须在所有索引上查找并修改其所有副本，比等价的SELECT查询的消耗要高的多。
### EXPLAIN中的列
#### id列
包含一个编号，标识SELECT所属的行。若语句中没有子查询或联合，只会有唯一的SELECT，显示1。否则，内层的SELECT语句一般会顺序编号，对应于其在原始语句中的位置。

MySQL将SELECT查询分为简单和复杂类型，复杂类型分为三大类：简单子查询、所谓的派生表（在FROM子句中的子查询）、以及UNION查询。

#### select_type列
显示对应行是简单还是复杂SELECT，SIMPLE意味着查询不包括子查询和UNION，若有复杂子部分，则最外层标记为PRIMARY，其他部分标记如下。

* SUBQUERY  
在SELECT列表中的子查询中的SELECT（不再FROM子句中）

* DERIVED  
表示包含在FROM子句的子查询中的SELECT，MySQL会递归执行并将结果放到一个临时表中

* UNION  
在UNION中的第二个和随后的SELECT被标记为UNION，若UNION被FROM子句中的子查询包含，第一个SELECT会被标记为DERIVED

* UNION RESULT  
UNION的匿名临时表检索结果的SELECT被标记为UNION RESULT

SUBQUERY和UNION还可以被标记为DEPENDENT和UNCACHEABLE。DEPENDENT意味着SELECT依赖于外层查询中发现的数据；UNCACHEABLE意味着SELECT中的某些特性阻止结果被缓存于一个Item_cache中。（Item_cache未被文档记载；不是查询缓存，可被一些相同的构件否定，例如RAND()函数。）

#### table列
显示对应行正在访问哪个表，为表或表的别名（若SQL中定义）。

用于观察MySQL的关联优化器为查询选择的关联顺序。

>MySQL的查询执行计划总是左侧深度优先树。

当FROM子句中有UNION时，table列会变得复杂。在FROM子句中有子查询时，table列是形式，N是子查询的id，指向EXPLAIN输出中的后面的一行。有UNION时，UNION RESULT的table列包含一个参入UNION的id列表。

#### type列
显示访问类型——MySQL决定如何查找表中的行。

访问方法，从最差到最优：

* ALL  
全表扫描，扫描整张表去找需要的行。（若查询中使用了LIMIT或者Extra列中显示“Using distinct/not exists”则不是）
* index  
与全表扫描一样，区别于MySQL扫描表时按索引次序进行而不是行。避免了排序，但是需要承担按索引次序读取整个表的开销。意味着若按随机次序访问，开销会很大。若Extra列为“Using index”表示MySQL使用覆盖索引，只扫描索引的数据，不按索引次序的每一行，比按索引次序全表扫描的开销小很多。
* range  
范围扫描实际上是有限制的索引扫描，开始于索引里的某一点，返回匹配这个域的行，开销跟索引类型相当。是带有BETWEEN或在WHERE子句里带有>的查询。
当MySQL使用索引去查找一系列值时，如In()和OR列表，也会显示为范围扫描。两者其实为不同的访问类型，性能上有重要的差异。
* ref  
索引访问（索引查找），返回所有匹配某个单个值的行。查找和扫描的混合体。只有当使用非唯一性索引或者唯一性索引的非唯一性前缀时才会发生。索引要跟某个参考值相比较，参考值或者是一个常数、或者是来自多表查询前一个表里的结果值。ref_or_null是ref之上的一个变体，意味着MySQL必须在初次查找的结果里进行第二次查找以找出NULL条目。
* eq_ref  
索引查找，MySQL最多只返回一条符合条件的记录。在MySQL使用主键或者唯一性索引查找时出现，将它们与某个参考值做比较。
* const，system  
MySQL对查询的某部分进行优化并将其转换成一个常量时出现。
* NULL  
意味着MySQL能在优化阶段分解查询语句，在执行阶段用不着再访问表或者索引。

#### possible_keys列
显示查询可以使用哪些索引，基于查询访问的列和使用的比较操作符来判断。

#### key列
显示MySQL决定采用哪个索引来优化对该表的访问。若该索引未出现在possible_keys列中，则MySQL选用它是出于另外的原因——如即使没有where子句却选择覆盖索引。

possible_keys显示哪一个索引能有助于高效地进行查找，key显示优化采用哪一个索引可以最小化查询成本。

#### key_len列
显示MySQL在索引里使用的字节数。通过查找表的定义而被计算出，而不是表中的数据。

#### ref列
显示之前的表在key列记录的索引中查找值所用的列或常量。

#### rows列
MySQL估计为了找到所需的行而要读取的行数。内嵌循环关联计划里的循环数目，不是MySQL认为它最终要从表里读取出来的行数，而是MySQL为了找到符合查询的每一点上标准的那些行而必须读取的行的平均数。是MySQL认为它要检查的行数，而不是结果集合里的行数。

#### filtered列
使用EXPLAIN EXTENDED时出现，显示针对表里符合某个条件（WHERE子句或联接条件）的记录数的百分比所做的一个悲观估算。将rows列乘此值，为MySQL估算它将和查询计划里前一个表关联的行数。

#### Extra列
包含不适合在其他列显示的额外信息。

常见的最重要的值有；

* “Using index”  
表示MySQL将使用覆盖索引，以避免访问表。
* “Using where”  
意味着MySQL服务器将在存储引擎检索行后再进行过滤。有时代表着查询可受益于不同的索引。
* “Using temporary”  
意味着MySQL在对查询结果排序时会使用一个临时表。
* “Using filesort”  
意味着MySQL会对结果使用一个外部索引排序，而不是按索引次序从表里读取行。有两种文件排序算法，两种方式都可在内存或磁盘上完成，不会显示将会使用哪一种文件排序，也不会显示是在内存里还是磁盘上完成。
* “Range checked for each record（index map：N）”  
意味着没有好用的索引，新的索引将在联接的每一行上重新估算。N是显示在possible_key列中索引的位图，并且是冗余的。

### MySQL 5.6中的改进
能对类似UPDATE、INSERT等查询进行解释。

对查询优化和执行引擎的改进，允许临时表尽可能晚地被具体化，而不总是在优化和执行使用到此临时表的部分查询时创建并填充它们。允许MySQL可以直接解释带子查询的查询语句，而不需要先实际地执行子查询。

通过在服务器中增加优化跟踪功能的方式改进优化器的相关部分。允许用户查看优化器做出选择，以及输入和抉择的原因。

