---
title: InnoDB存储引擎源代码的编译和调试
tags: [mysql,note,innodb]
comments: true
categories: [MySQL技术内幕-InnoDB存储引擎]
date: 2019-09-18 14:30:31
---

[源码](https://dev.mysql.com/downloads/mysql/)

### InnoDB源码结构

MySQL源码目录下storage文件夹下，文件夹名即为存储引擎名。

```
wuhua:storage wuhua$ pwd
/Users/wuhua/Downloads/mysql-8.0.17/storage
wuhua:storage wuhua$ tree -L 1
.
├── archive
├── blackhole
├── csv
├── example
├── federated
├── heap
├── innobase
├── myisam
├── myisammrg
├── ndb
├── perfschema
├── secondary_engine_mock
└── temptable

13 directories, 0 files
```

InnoDB源码结构：

```
wuhua:innobase wuhua$ tree -L 1
.
├── CMakeLists.txt   
├── COPYING.Google
├── COPYING.Percona
├── Doxyfile
├── api
├── arch
├── btr            	//B+ tree的实现
├── buf            	//缓冲池的实现，包括LRU算法，Flush刷新算法
├── clone
├── data
├── dict				//InnoDB存储引擎中内存数据字典的实现
├── eval
├── fil				//InnoDB存储引擎中文件数据结构及对文件的一些操作
├── fsp				//file space，对InnoDB engine物理文件的管理，如页、区、段等
├── fts				
├── fut
├── gis
├── ha					//哈希算法的实现
├── handler			//继承MySQL的handler，插件式存储引擎的实现
├── ibuf				//插入缓冲的实现
├── include			//头文件（.h，.ic）
├── innodb.cmake
├── lob
├── lock				//锁的实现，如S锁、X锁，以及定义锁的一系列算法
├── log				//日志缓冲和重做日志文件的实现
├── mach		
├── mem				//辅助缓冲池的实现，用来申请一些数据结构的内存
├── mtr				//事务的底层实现
├── os					//封装一些对于操作系统的操作
├── page				//页的实现
├── pars			
├── que
├── read
├── rem
├── row				//对于各种类型行数据的操作
├── srv				//对于InnoDB engine参数的设计
├── sync				//InnoDB engine互斥量（Mutex）的实现
├── trx				//事务的实现
├── usr
└── ut					//工具类
```


### 编译调试

源码中及各存储引擎中README文档。