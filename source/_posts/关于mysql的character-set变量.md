---
title: 关于mysql的character_set变量
tags: [mysql,character_set]
comments: true
categories: [mysql]
date: 2019-01-25 16:08:27
---

### 背景
今天查寻数据时，发现结果中汉字都成了乱码，查看数据表相关乱码字段字符集结果：

```
mysql>  show full columns from table_name;
+--------------------+---------------------+-----------------+------+-----+---------+----------------+----------------------+-------------+
| Field              | Type                | Collation       | Null | Key | Default | Extra          | Privileges           | Comment     |
+--------------------+---------------------+-----------------+------+-----+---------+----------------+----------------------+-------------+
...
| user_name          | varchar(100)        | utf8_general_ci | YES  |     | NULL    |                | select,insert,update | ????        |
| chapter_name       | varchar(255)        | utf8_general_ci | YES  |     | NULL    |                | select,insert,update | ?????       |
...

```

查看数据库字符集设置：

```
mysql> show variables like 'char%';
+--------------------------+-------------------------------------+
| Variable_name            | Value                               |
+--------------------------+-------------------------------------+
| character_set_client     | latin1                              |
| character_set_connection | latin1                              |
| character_set_database   | utf8                                |
| character_set_filesystem | binary                              |
| character_set_results    | latin1                              |
| character_set_server     | utf8                                |
| character_set_system     | utf8                                |
| character_sets_dir       | /usr/share/percona-server/charsets/ |
+--------------------------+-------------------------------------+
8 rows in set (0.00 sec)
```

大致感觉到原因是由于数据表相关字段字符集设置为utf8，以utf8编码存储，但是查询结果以latin1编码输出，导致汉字出现乱码。

搜索得解决办法，在查询语句中对出现乱码字段字符集编码进行转换，具体转换语句为：

```
convert(unhex(hex(convert(user_name using utf8))) using latin1) as user_name,convert(unhex(hex(convert(chapter_name using utf8))) using latin1) as chapter_name
```

最终得到正确无乱码的查询结果。

经过搜索，下面对`character_set`的学习了解进行记录。

### 各character_set变量的含义
参考博客[深入Mysql字符集设置](http://www.laruence.com/2008/01/05/12.html),
[Mysql中各種與字符編碼集（character_set）有關的變量含義](https://hk.saowen.com/a/9c46af2db75e4f83be2d3eecd0d8de1246c3a69aed5facfbebe19ad46ca2600c)

* `character_set_client` :设置客户端使用的字符集，即查询语句使用的字符集，要与客户端输出的字节流采用的编码一致。
* `character_set_connection `:连接层字符集,接受到用户查询，按照character_set_client将其转换为character_set_connection设定的字符集。
* `character_set_database `:当前选中数据库的默认字符集，如果在创建数据库时没有设置编码格式，就按照这个格式设置。
* `character_set_filesystem `:文件系统的编码格式，把操作系统上的文件名转化成此字符集，即把 character_set_client转换character_set_filesystem， 默认binary不做任何转换。
* `character_set_results `:查询结果字符集，数据库给客户端返回时使用的编码格式，如果没有指明，使用服务器默认的编码格式。
* `character_set_server `:默认的内部操作字符集，由系统自己管理，不能人为定义。
* `character_set_system `:系统元数据(字段名等)字符集，一直是utf8，不需要设置。
* `character_sets_dir `:字符集安装的目录。


`character_set_server`决定了服务器的默认编码，`character_set_database `决定了新建数据库的默认字符集，新建数据库的字符集决定了新建表的默认字符集，表的字符集决定了字段的默认字符集，若没有通过`DEFAULT CHARACTER SET = xxx`改变表的字符集，则新表使用`character_set_database `指定的字符集。

查询语句的字符串比较时，由`collation_connection`限定比较的规则，其形式如：字符集_语言_ci(大小写不敏感)、字符集_语言_cs(大小写敏感),
