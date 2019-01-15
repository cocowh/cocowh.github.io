---
title: MySQL体系结构和存储引擎
tags: [mysql,note]
comments: true
categories: [MySQL技术内幕-InnoDB存储引擎]
date: 2019-01-10 17:07:34
---

### 定义数据库和实例

* 数据库：物理操作系统文件或其他形式文件类型的集合。
* 实例：MySQL数据库由后台线程以及一个共享内存区组成。

MySQL设计为单进程多线程架构，数据库实例在系统上表现为一个进程。

启动实例时，MySQL数据库会去读取配置文件，根据配置文件的参数来启动数据库实例，没有配置文件时，按照编译时的默认参数设置启动实例。使用`mysql --help | grep my.cnf`查看启动时从哪些位置查找配置文件。当几个配置文件都有同一个参数，MySQL数据库以读取到的最后一个配置文件中的参数为准。

配置文件参数`datadir`指定了数据库所在的路径。linux操作系统下默认为`/usr/local/mysql/data`，该路径只是一个链接，指向`/opt/mysql_data`目录，必须保证该目录的用户和权限使mysql用户和组可以访问。

### MySQL体系结构

MySQL组成部分：  
 
 * 连接池组件
 * 管理服务和工具组件
 * SQL接口组件
 * 查询分析器组件
 * 优化器组件
 * 缓冲（cache）组件
 * 插件式存储引擎
 * 物理文件

 区别于其他数据库的重要特点是插件式的表存储引擎。MySQL插件式存储引擎架构提供一系列标准的管理和服务支持，这些标准与存储引擎本身无关，存储引擎是底层物理结构的实现。存储引擎是基于表的，而不是数据库。
 
### MySQL存储引擎
每个存储引擎都有各自的特点，能够根据具体的应用建立不同存储引擎表。用户可以根据MySQL预定义的存储引擎接口编写自己的存储引擎。

通过`SHOW ENGINES`语句或者通过查找`information_schema`架构下的ENGINES表，查看当前使用的MySQL数据库所支持的存储引擎。

#### InnoDB存储引擎
InnoDB存储引擎支持事务，设计目标面向在线事务处理的应用。行锁设计、支持外键，支持类似Oracle的非锁定读，即默认读取操作不会产生锁。

InnoDB存储引擎将数据放在一个逻辑的表空间中，表空间由InnoDB存储引擎自身进行管理。每个InnoDB存储引擎的表单独存放到一个ibd文件中。InnoDB存储引擎支持用裸设备（row disk）来建立其表空间。

InnoDB通过使用多版本并发控制（MVCC）来获得高并发，实现了SQL标准的4种隔离级别，默认为REPEATABLE级别。使用被称为next-key locking策略避免幻读现象的产生。还提供了插入缓存（insert buffer）、二次写（double write）、自适应哈希索引（adaptive hash index）、预读（read ahead）等高性能和高可用的功能。

InnoDB存储引擎采用聚集（clustered）的方式存储表中的数据，每张表的存储都是按主键的顺序进行存放。当没有显示的指定主键，InnoDB存储引擎会为每一行生成一个6字节的ROWID，并以此作为主键。

#### MyISAM存储引擎
MyISAM存储引擎不支持事务，支持全文索引，表锁设计，主要面向一些OLAP数据库应用。MyISAM存储引擎的缓冲池只缓存索引文件，而不缓存数据文件。

MyISAM存储引擎表由MYD和MYI组成，MYD用来存放数据文件，MYI用来存放索引文件。可以通过使用`myisampack`工具进一步压缩数据文件，因myisampack工具使用哈夫曼编码静态算法来压缩数据，所以压缩后的表是只读的，也可以使用myisampack工具解压数据文件。

V5.0前MyISAM默认支持的表大小为4GB，制定MAX_ROWS和AVG_ROW_LENGTH属性拓展为大于4GB的表。V5.0及以后，默认支持256TB的表单数据。

### 连接MySQL
连接MySQL操作是一个连接进程和MySQL数据库实例进行通信。

#### TCP/IP
TCP/IP套接字方式是MySQL数据库在任何平台下都提供的连接方式。

```
wuhua:~ wuhua$ mysql -h 127.0.0.1 -u root -p
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 2
Server version: 5.7.22 MySQL Community Server (GPL)

Copyright (c) 2000, 2018, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> 
```

通过TCP/IP连接到MySQL实例时，MySQL会先检查一张权限视图，判断发起请求的客户端IP是否允许连接到MySQL实例。视图在mysql结构下，表名为`user`。

```
mysql> use mysql
Database changed
mysql> show columns from user;
+------------------------+-----------------------------------+------+-----+-----------------------+-------+
| Field                  | Type                              | Null | Key | Default               | Extra |
+------------------------+-----------------------------------+------+-----+-----------------------+-------+
| Host                   | char(60)                          | NO   | PRI |                       |       |
| User                   | char(32)                          | NO   | PRI |                       |       |
| Select_priv            | enum('N','Y')                     | NO   |     | N                     |       |
| Insert_priv            | enum('N','Y')                     | NO   |     | N                     |       |
| Update_priv            | enum('N','Y')                     | NO   |     | N                     |       |
| Delete_priv            | enum('N','Y')                     | NO   |     | N                     |       |
| Create_priv            | enum('N','Y')                     | NO   |     | N                     |       |
| Drop_priv              | enum('N','Y')                     | NO   |     | N                     |       |
| Reload_priv            | enum('N','Y')                     | NO   |     | N                     |       |
| Shutdown_priv          | enum('N','Y')                     | NO   |     | N                     |       |
| Process_priv           | enum('N','Y')                     | NO   |     | N                     |       |
| File_priv              | enum('N','Y')                     | NO   |     | N                     |       |
| Grant_priv             | enum('N','Y')                     | NO   |     | N                     |       |
| References_priv        | enum('N','Y')                     | NO   |     | N                     |       |
| Index_priv             | enum('N','Y')                     | NO   |     | N                     |       |
| Alter_priv             | enum('N','Y')                     | NO   |     | N                     |       |
| Show_db_priv           | enum('N','Y')                     | NO   |     | N                     |       |
| Super_priv             | enum('N','Y')                     | NO   |     | N                     |       |
| Create_tmp_table_priv  | enum('N','Y')                     | NO   |     | N                     |       |
| Lock_tables_priv       | enum('N','Y')                     | NO   |     | N                     |       |
| Execute_priv           | enum('N','Y')                     | NO   |     | N                     |       |
| Repl_slave_priv        | enum('N','Y')                     | NO   |     | N                     |       |
| Repl_client_priv       | enum('N','Y')                     | NO   |     | N                     |       |
| Create_view_priv       | enum('N','Y')                     | NO   |     | N                     |       |
| Show_view_priv         | enum('N','Y')                     | NO   |     | N                     |       |
| Create_routine_priv    | enum('N','Y')                     | NO   |     | N                     |       |
| Alter_routine_priv     | enum('N','Y')                     | NO   |     | N                     |       |
| Create_user_priv       | enum('N','Y')                     | NO   |     | N                     |       |
| Event_priv             | enum('N','Y')                     | NO   |     | N                     |       |
| Trigger_priv           | enum('N','Y')                     | NO   |     | N                     |       |
| Create_tablespace_priv | enum('N','Y')                     | NO   |     | N                     |       |
| ssl_type               | enum('','ANY','X509','SPECIFIED') | NO   |     |                       |       |
| ssl_cipher             | blob                              | NO   |     | NULL                  |       |
| x509_issuer            | blob                              | NO   |     | NULL                  |       |
| x509_subject           | blob                              | NO   |     | NULL                  |       |
| max_questions          | int(11) unsigned                  | NO   |     | 0                     |       |
| max_updates            | int(11) unsigned                  | NO   |     | 0                     |       |
| max_connections        | int(11) unsigned                  | NO   |     | 0                     |       |
| max_user_connections   | int(11) unsigned                  | NO   |     | 0                     |       |
| plugin                 | char(64)                          | NO   |     | mysql_native_password |       |
| authentication_string  | text                              | YES  |     | NULL                  |       |
| password_expired       | enum('N','Y')                     | NO   |     | N                     |       |
| password_last_changed  | timestamp                         | YES  |     | NULL                  |       |
| password_lifetime      | smallint(5) unsigned              | YES  |     | NULL                  |       |
| account_locked         | enum('N','Y')                     | NO   |     | N                     |       |
+------------------------+-----------------------------------+------+-----+-----------------------+-------+
45 rows in set (0.00 sec)

mysql> SELECT host,user,password_expired FROM user;
+-----------+---------------+------------------+
| host      | user          | password_expired |
+-----------+---------------+------------------+
| localhost | root          | N                |
| localhost | mysql.session | N                |
| localhost | mysql.sys     | N                |
+-----------+---------------+------------------+
3 rows in set (0.00 sec)
```

#### 命名管道和共享内存
Win 2000、Win XP、Win 2003和Win Vista以及在此之上的平台，若两个需要进程通信的进程在同一台服务器上，可以使用命名管道。MySQL数据库须在配置文件中启用--enable-named-pipe。V4.1后提供共享内存的连接方式，须在配置文件中添加--shared-memory，在连接时客户端还必须使用--protocol=memory选项。

#### UNIX套接字
Linux和UNIX环境下，可以使用UNIX域套接字，因其非网络协议，只能在MySQL客户端和数据库实例在一台服务器上的情况下使用。用户可以在配置文件中指定套接字文件的路径`--socket=/tmp/mysql.sock`。

查询UNIX域套接字文件：

```
mysql> show variables like 'socket';
+---------------+-----------------+
| Variable_name | Value           |
+---------------+-----------------+
| socket        | /tmp/mysql.sock |
+---------------+-----------------+
1 row in set (0.03 sec)
```

使用UNIX域套接字方式进行连接：

```
wuhua:~ wuhua$ mysql -uroot -S /tmp/mysql.sock -p
Enter password: 
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 4
Server version: 5.7.22 MySQL Community Server (GPL)

Copyright (c) 2000, 2018, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
```