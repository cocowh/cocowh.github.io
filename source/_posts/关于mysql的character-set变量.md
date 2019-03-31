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

### 各character_set变量的含义
参考博客[深入Mysql字符集设置](http://www.laruence.com/2008/01/05/12.html),
[Mysql中各種與字符編碼集（character_set）有關的變量含義](https://hk.saowen.com/a/9c46af2db75e4f83be2d3eecd0d8de1246c3a69aed5facfbebe19ad46ca2600c)
