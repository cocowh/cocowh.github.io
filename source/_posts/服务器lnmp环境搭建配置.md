---
title: 服务器lnmp环境搭建配置
tags: [linux,nginx,mysql,php7,shell]
comments: true
categories: [php]
date: 2018-05-09 23:26:50
---
搭建本博客之初的原因之一，就是在搭建lnmp和其他系列环境时遇到了很多问题，今天将服务器重置了，先配置好了go环境，在{% post_link Golang笔记-基础篇-一 %}的初始部分进行了相关步骤的补充。下面记录下lnmp环境的搭建配置。

## 服务器用户设置
全新的腾讯云服务器，CentOS 7.5。

### ssh登陆

```
wuhua:~ wuhua$ ssh -p 22 root@188.131.143.137
root@188.131.143.137's password: 
Last login: Sun Sep 30 11:27:15 2018 from 119.29.96.147
```
### 新建用户

```
[root@VM_0_10_centos ~]# adduser wuhua
[root@VM_0_10_centos ~]# passwd wuhua
更改用户 wuhua 的密码 。
新的 密码：
无效的密码： 密码未通过字典检查 - 它基于字典单词
重新输入新的 密码：
passwd：所有的身份验证令牌已经成功更新。
```
### 授权
创建的用户只有其home下的完整权限，若不需要超级权限此步骤可取消。


修改sudoers权限为可读可写

```
[root@VM_0_10_centos ~]# whereis sudoers
sudoers: /etc/sudoers /etc/sudoers.d /usr/share/man/man5/sudoers.5.gz
[root@VM_0_10_centos ~]# ls -l /etc/sudoers
-r--r----- 1 root root 3938 6月  27 02:07 /etc/sudoers
[root@VM_0_10_centos ~]# chmod -v u+w /etc/sudoers
mode of "/etc/sudoers" changed from 0440 (r--r-----) to 0640 (rw-r-----)
[root@VM_0_10_centos ~]# vim /etc/sudoers
```
添加

```
## Allow root to run any commands anywhere 
root    ALL=(ALL)       ALL
wuhua   ALL=(ALL)       ALL
```
取消sudoers可写权限

```
[root@VM_0_10_centos ~]# chmod -v u-w /etc/sudoers
mode of "/etc/sudoers" changed from 0640 (rw-r-----) to 0440 (r--r-----)
```
### 新用户登陆
若无上一步，无法以root权限操作，无法使用sudo。

```
[root@VM_0_10_centos ~]# exit
登出
Connection to 188.131.143.137 closed.
wuhua:~ wuhua$ ssh -p 22 wuhua@188.131.143.137
wuhua@188.131.143.137's password: 
[wuhua@VM_0_10_centos ~]$ pwd
/home/wuhua
[wuhua@VM_0_10_centos ~]$ sudo su

我们信任您已经从系统管理员那里了解了日常注意事项。
总结起来无外乎这三点：

    #1) 尊重别人的隐私。
    #2) 输入前要先考虑(后果和风险)。
    #3) 权力越大，责任越大。

[sudo] wuhua 的密码：
[root@VM_0_10_centos wuhua]# 
```

## nginx编译安装
### 下载
可通过[https://nginx.org/en/download.html](https://nginx.org/en/download.html)选择版本，然后服务器端下载到/usr/local，此处选择最新稳定版1.14.0。

```
[wuhua@VM_0_10_centos ~]$ wget -c https://nginx.org/download/nginx-1.14.0.tar.gz
```
解压缩

```code
[wuhua@VM_0_10_centos local]$ tar -zxvf nginx-1.14.0.tar.gz
```
### 配置
全新服务器无编译器

运行:

```
[wuhua@VM_0_10_centos nginx-1.14.0]$ sudo yum -y install gcc gcc-c++ autoconf automake make
```

#### 可能出现的问题

缺少pcre库，安装库`pcre-devel`:

```code
[wuhua@VM_0_10_centos nginx-1.14.0]$ sudo yum -y install pcre-devel
```

缺少zlib库，安装库：

```
[wuhua@VM_0_10_centos nginx-1.14.0]$ sudo yum install -y zlib-devel
```

#### 自定义配置
可选项：

```code
./configure \
--user=nginx \
--group=nginx \
--with-http_stub_status_module \
--with-http_ssl_module \  
--prefix=/usr/local/nginx \
--conf-path=/usr/local/nginx/conf/nginx.conf \
--pid-path=/usr/local/nginx/conf/nginx.pid \
--lock-path=/var/lock/nginx.lock \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--with-http_gzip_static_module \
--http-client-body-temp-path=/var/temp/nginx/client \
--http-proxy-temp-path=/var/temp/nginx/proxy \
--http-fastcgi-temp-path=/var/temp/nginx/fastcgi \
--http-uwsgi-temp-path=/var/temp/nginx/uwsgi \
--http-scgi-temp-path=/var/temp/nginx/scgi
```

自定义，安装到用户目录local文件夹nginx下：

```
[wuhua@VM_0_10_centos nginx-1.14.0]$ ./configure --user=wuhua --group=wuhua --prefix=/home/wuhua/local/nginx --conf-path=/home/wuhua/local/nginx/conf/nginx.conf --pid-path=/home/wuhua/local/nginx/conf/nginx.pid --lock-path=/home/wuhua/local/nginx/nginx.lock --error-log-path=/home/wuhua/local/nginx/logs/error.log --http-log-path=/home/wuhua/local/nginx/logs/access.log --http-client-body-temp-path=/home/wuhua/local/nginx/client --http-proxy-temp-path=/home/wuhua/local/nginx/proxy --http-fastcgi-temp-path=/home/wuhua/local/nginx/fastcgi --http-uwsgi-temp-path=/home/wuhua/local/nginx/uwsgi --http-scgi-temp-path=/home/wuhua/local/nginx/scgi
```

将临时文件目录指定为/var/temp/nginx，需要在/var下创建temp及nginx目录，另外前两两项需要先创建好用户和用户组。
### 编译安装

```
[wuhua@VM_0_10_centos nginx-1.14.0]$ make & make install
```
若使用yum命令直接安装可使用`whereis nginx`查看安装的路径。

### 配置
主要修改`user`,`pid`,`error_log`:

```
[wuhua@VM_0_10_centos conf]$ pwd
/home/wuhua/local/nginx/conf
[wuhua@VM_0_10_centos conf]$ cat nginx.conf

user  wuhua;
worker_processes  1;

error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;
pid	   conf/nginx.pid;

events {
    worker_connections  1024;
}
```

`worker_processes`根据文档提示一般设置为CPU核心数，或者`auto`启动时自动根据核心数设置worker进程数，nginx作为http服务器`worker_connenctions`\*`worker_processes`/2 <= max_client，nginx作为反向代理服务器`worker_connenctions`\*`worker_processes`/4 <= max_client。

参考[Nginx 中文官方文档](https://www.kancloud.cn/wizardforcel/nginx-doc/92360),[nginx 并发数问题思考](http://blog.51cto.com/liuqunying/1420556)

### 为nginx的启动、重启、重载配置添加脚本
#### 直接启动方法

```
[wuhua@VM_0_10_centos sbin]$ pwd
/home/wuhua/local/nginx/sbin
[wuhua@VM_0_10_centos sbin]$ sudo ./nginx
```

初次启动后可以查看conf目录下是否新增nginx.pid文件，里面保存有nginx的主进程号：

```
[wuhua@VM_0_10_centos ~]$ pwd
/home/wuhua
[wuhua@VM_0_10_centos ~]$ ps aux | grep nginx
wuhua    15922  0.0  0.0 112720   984 pts/0    R+   15:32   0:00 grep --color=auto nginx
[wuhua@VM_0_10_centos ~]$ ls local/nginx/conf/
fastcgi.conf          fastcgi_params.default  mime.types          nginx.conf.default   uwsgi_params
fastcgi.conf.default  koi-utf                 mime.types.default  scgi_params          uwsgi_params.default
fastcgi_params        koi-win                 nginx.conf          scgi_params.default  win-utf
[wuhua@VM_0_10_centos ~]$ sudo local/nginx/sbin/nginx 
[wuhua@VM_0_10_centos ~]$ ps aux | grep nginx
root     15934  0.0  0.0  20548   608 ?        Ss   15:32   0:00 nginx: master process local/nginx/sbin/nginx
wuhua    15935  0.0  0.0  23076  1380 ?        S    15:32   0:00 nginx: worker process
wuhua    15938  0.0  0.0 112720   984 pts/0    R+   15:32   0:00 grep --color=auto nginx
[wuhua@VM_0_10_centos ~]$ ls local/nginx/conf/
fastcgi.conf          fastcgi_params.default  mime.types          nginx.conf.default  scgi_params.default   win-utf
fastcgi.conf.default  koi-utf                 mime.types.default  nginx.pid           uwsgi_params
fastcgi_params        koi-win                 nginx.conf          scgi_params         uwsgi_params.default
[wuhua@VM_0_10_centos ~]$ cat local/nginx/conf/nginx.pid 
15934
```
#### 添加脚本控制
>新建文件

```code
[wuhua@VM_0_10_centos sbin]$ sudo vim /usr/lib/systemd/system/nginx.service
```

>添加内容

```
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/home/wuhua/local/nginx/conf/nginx.pid
ExecStartPre=/home/wuhua/local/nginx/sbin/nginx -t -c /home/wuhua/local/nginx/conf/nginx.conf
ExecStart=/home/wuhua/local/nginx/sbin/nginx -c /home/wuhua/local/nginx/conf/nginx.conf
ExecReload=/home/wuhua/local/nginx/sbin/nginx -s reload 
ExecStop=/home/wuhua/local/nginx/sbin/nginx -s stop
ExecQuit=/home/wuhua/local/nginx/sbin/nginx -s quit
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

>systemctl的一些使用方法

```code
systemctl is-enabled servicename.service #查询服务是否开机启动
systemctl enable xxx.service #开机运行服务
systemctl disable xxx.service #取消开机运行
systemctl start xxx.service #启动服务
systemctl stop xxx.service #停止服务
systemctl restart xxx.service #重启服务
systemctl reload xxx.service #重新加载服务配置文件
systemctl status xxx.service #查询服务运行状态
systemctl --failed #显示启动失败的服务
```

在使用前先刷新配置：

```
[wuhua@VM_0_10_centos ~]$ sudo systemctl daemon-reload
```
关闭直接使用sbin/nginx打开的进程：

```
[wuhua@VM_0_10_centos ~]$ ps aux | grep nginx
root     15934  0.0  0.0  20548   608 ?        Ss   15:32   0:00 nginx: master process local/nginx/sbin/nginx
wuhua    15935  0.0  0.0  23076  1380 ?        S    15:32   0:00 nginx: worker process
wuhua    16307  0.0  0.0 112720   984 pts/0    R+   15:38   0:00 grep --color=auto nginx
[wuhua@VM_0_10_centos ~]$ sudo kill 15934
[sudo] wuhua 的密码：
[wuhua@VM_0_10_centos ~]$ ps aux | grep nginx
wuhua    16317  0.0  0.0 112720   984 pts/0    R+   15:38   0:00 grep --color=auto nginx
[wuhua@VM_0_10_centos ~]$ 
```

疑惑：
>此次配置过程中若未提前杀死使用nginx/sbin/nginx启动的nginx主进程，使用systemctl stop或者reload等操作无效。待探究。



>添加脚本后centos7 中操作nginx的方法有

```code
systemctl is-enabled nginx.service #查询nginx是否开机启动
systemctl enable nginx.service #开机运行nginx
systemctl disable nginx.service #取消开机运行nginx
systemctl start nginx.service #启动nginx
systemctl stop nginx.service #停止nginx
systemctl restart nginx.service #重启nginx
systemctl reload nginx.service #重新加载nginx配置文件
systemctl status nginx.service #查询nginx运行状态
systemctl --failed #显示启动失败的服务
```
>添加到开机自动启动

```
[wuhua@VM_0_10_centos ~]$ sudo systemctl enable nginx.service
Created symlink from /etc/systemd/system/multi-user.target.wants/nginx.service to /usr/lib/systemd/system/nginx.service.
```
至此以安装成功，通过IP可访问显示nginx页面。

---

## mysql安装
### 安装（centos7默认mariadb）
单机不考虑分离，直接安装（作本地开发快速安装）,一般有单独的数据库服务器。

```
[wuhua@VM_0_10_centos multi-user.target.wants]$ yum -y install mariadb mariadb-server
```
### 启动MariaDB并加入开机启动

```
[wuhua@VM_0_10_centos multi-user.target.wants]$ sudo systemctl start mariadb
[wuhua@VM_0_10_centos multi-user.target.wants]$ sudo systemctl enable mariadb
Created symlink from /etc/systemd/system/multi-user.target.wants/mariadb.service to /usr/lib/systemd/system/mariadb.service.
```
其他命令

```
systemctl start mariadb #启动服务
systemctl enable mariadb #设置开机启动
systemctl restart mariadb #重新启动
systemctl stop mariadb.service #停止MariaDB
```
### 初次登陆设置密码等
登陆到数据库，初次登陆密码为空

```
[wuhua@VM_0_10_centos multi-user.target.wants]$ mysql -uroot
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 2
Server version: 5.5.60-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> 
```

配置root密码，第一步密码为空，初次设置

```
[wuhua@VM_0_10_centos multi-user.target.wants]$ sudo mysql_secure_installation
[sudo] wuhua 的密码：

NOTE: RUNNING ALL PARTS OF THIS SCRIPT IS RECOMMENDED FOR ALL MariaDB
      SERVERS IN PRODUCTION USE!  PLEASE READ EACH STEP CAREFULLY!

In order to log into MariaDB to secure it, we'll need the current
password for the root user.  If you've just installed MariaDB, and
you haven't set the root password yet, the password will be blank,
so you should just press enter here.

Enter current password for root (enter for none): 
OK, successfully used password, moving on...

Setting the root password ensures that nobody can log into the MariaDB
root user without the proper authorisation.

Set root password? [Y/n] y
New password: 
Re-enter new password: 
Password updated successfully!
Reloading privilege tables..
 ... Success!


By default, a MariaDB installation has an anonymous user, allowing anyone
to log into MariaDB without having to have a user account created for
them.  This is intended only for testing, and to make the installation
go a bit smoother.  You should remove them before moving into a
production environment.

Remove anonymous users? [Y/n] y
 ... Success!

Normally, root should only be allowed to connect from 'localhost'.  This
ensures that someone cannot guess at the root password from the network.

Disallow root login remotely? [Y/n] y
 ... Success!

By default, MariaDB comes with a database named 'test' that anyone can
access.  This is also intended only for testing, and should be removed
before moving into a production environment.

Remove test database and access to it? [Y/n] y
 - Dropping test database...
 ... Success!
 - Removing privileges on test database...
 ... Success!

Reloading the privilege tables will ensure that all changes made so far
will take effect immediately.

Reload privilege tables now? [Y/n] y
 ... Success!

Cleaning up...

All done!  If you've completed all of the above steps, your MariaDB
installation should now be secure.

Thanks for using MariaDB!
```
### 创建用户及设置权限

```
[wuhua@VM_0_10_centos multi-user.target.wants]$ mysql -uroot -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 13
Server version: 5.5.60-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> create user 'huagege'@'%' identified by '123456789';
Query OK, 0 rows affected (0.00 sec)

MariaDB [(none)]> create user 'huagege'@'localhost' identified by '123456789';
Query OK, 0 rows affected (0.00 sec)

MariaDB [(none)]> grant all privileges on *.* to 'huagege'@'localhost' identified by '123456789';
Query OK, 0 rows affected (0.00 sec)

MariaDB [(none)]> grant all privileges on *.* to 'huagege'@'%' identified by '123456789';
Query OK, 0 rows affected (0.00 sec)

MariaDB [(none)]> flush privileges;
Query OK, 0 rows affected (0.00 sec)

MariaDB [(none)]> exit
Bye
[wuhua@VM_0_10_centos multi-user.target.wants]$ mysql -uhuagege -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 14
Server version: 5.5.60-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> show databases
    -> ;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
3 rows in set (0.00 sec)

MariaDB [(none)]> exit
Bye
[wuhua@VM_0_10_centos multi-user.target.wants]$ 
```
### 配置Mariadb数据库字符
```code
//在/etc/my.cnf中的mysqld标签下,新增字符设置:
init_connect='SET collation_connection = utf8_unicode_ci' 
init_connect='SET NAMES utf8' character-set-server=utf8

// 在/etc/my.cnf.d/client.cnf中的client标签下,新增字符设:
default-character-set=utf8

//在/etc/my.cnf.d/mysql-clients.cnf下的[mysql]标签下,新增字符设置:
default-character-set=utf8
```
登陆mysql输入命令:
>`show variables like "%character%";show variables like "%collation%";`

---

## PHP编译安装
### 下载
可以通过[http://php.net/downloads.php](http://php.net/downloads.php)查看现有的版本，然后直接在服务器端下载源码包，此处选择最新版7.2.10，此源下载很慢，建议选择其他源。
```code
[wuhua@VM_0_10_centos local]$ wget -c http://cn2.php.net/distributions/php-7.2.10.tar.gz
```
解压缩
```code
[wuhua@VM_0_10_centos local]$ tar -xvzf php-7.2.10.tar.gz
[wuhua@VM_0_10_centos local]$ cd php-7.2.10
```

### 编译配置
#### 安装依赖库
根据之前的编译安装，centos7缺少的libmcrypt、mhash、mcrypt这三个库需要添加源才能下载到（源忘记了），使用的阿里云虚拟机可以直接下载安装。后续编译过程中根据所缺再增加。
```code
[wuhua@VM_0_10_centos local]$ yum -y install libmcrypt mhash mcrypt
```
也可先运行直接全部安装所需库
```code
[wuhua@VM_0_10_centos local]$ yum -y install wget vim pcre pcre-devel openssl openssl-devel libicu-devel gcc gcc-c++ autoconf libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel zlib zlib-devel glibc glibc-devel glib2 glib2-devel ncurses ncurses-devel curl curl-devel krb5-devel libidn libidn-devel openldap openldap-devel nss_ldap jemalloc-devel cmake boost-devel bison automake libevent libevent-devel gd gd-devel libtool* libmcrypt libmcrypt-devel mcrypt mhash libxslt libxslt-devel readline readline-devel gmp gmp-devel libcurl libcurl-devel openjpeg-devel bzip2-devel
```
有些没有的话可以尝试更新源
```code
[wuhua@VM_0_10_centos local]$ sudo yum install epel-release
[wuhua@VM_0_10_centos local]$ sudo yum update
```
若源找不到对应库，也可直接将yum源更换为阿里云源
```yum
[wuhua@VM_0_10_centos local]$ sudo mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
[wuhua@VM_0_10_centos local]$ sudo wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
[wuhua@VM_0_10_centos local]$ sudo yum makecache
```

#### 编译配置

可用`./configure --help`查看配置项和说明，可查阅官网[http://php.net/manual/zh/install.php](http://php.net/manual/zh/install.php)和[http://php.net/manual/zh/configure.about.php](http://php.net/manual/zh/configure.about.php)以及源码包中的INSTALL文档。参考配置：
```code
./configure --prefix=/usr/local/php7 \
--with-config-file-path=/usr/local/php7/etc \
--enable-fpm \
--with-fpm-user=www \
--with-fpm-group=www \
--enable-mysqlnd \
--with-mysqli=mysqlnd \
--with-pdo-mysql=mysqlnd \
--enable-mysqlnd-compression-support \
--with-iconv-dir \
--with-freetype-dir \
--with-jpeg-dir \
--with-png-dir \
--with-zlib \
--with-libxml-dir \
--enable-xml \
--disable-rpath \
--enable-bcmath \
--enable-shmop \
--enable-sysvsem \
--enable-inline-optimization \
--with-curl \
--enable-mbregex \
--enable-mbstring \
--enable-intl \
--with-mcrypt \
--with-libmbfl \
--enable-ftp \
--with-gd \
--enable-gd-jis-conv \
--enable-gd-native-ttf \
--with-openssl \
--with-mhash \
--enable-pcntl \
--enable-sockets \
--with-xmlrpc \
--enable-zip \
--enable-soap \
--with-gettext \
--disable-fileinfo \
--enable-opcache \
--with-pear \
--enable-maintainer-zts \
--with-ldap=shared \
--without-gdbm
```
将nginx、php-fpm运行在正在登录的wuhua用户，不选择相应配置项默认即为nobody。

最终配置为：
```code
[wuhua@VM_0_10_centos php-7.2.10]$  ./configure -prefix=/home/wuhua/local/php7 -with-config-file-path=/home/wuhua/local/php7/etc -with-config-file-scan-dir=/home/wuhua/local/php7/etc/conf.d -enable-fpm -enable-soap -with-openssl -with-openssl-dir -with-pcre-regex -with-zlib -with-iconv -with-bz2 -enable-calendar -with-curl -with-cdb -enable-dom -enable-exif -with-pcre-dir -enable-ftp -with-gd -with-jpeg-dir -with-png-dir -with-freetype-dir -with-gettext -with-gmp -with-mhash -enable-mbstring -with-libmbfl -with-onig -enable-pdo -with-pdo-mysql -with-zlib-dir -with-readline -enable-session -enable-shmop -enable-simplexml -enable-sockets -enable-sysvmsg -enable-sysvsem -enable-sysvshm -enable-wddx -with-libxml-dir -with-xsl -enable-zip -enable-mysqlnd -with-mysqli -enable-embedded-mysqli -enable-bcmath -enable-inline-optimization -enable-mbregex -enable-pcntl  -with-xmlrpc -enable-opcache
```
注意：php7.2版本不支持–with-mcrypt, –enable-gd-native-ttf。在phh7.1时，官方就开始建议用openssl_\*系列函数代替mcrypt_\*系列的函数。7.2版本加上这两项配置无法通过的。

### 编译安装
```
[wuhua@VM_0_10_centos php-7.2.10]$ make
[wuhua@VM_0_10_centos php-7.2.10]$ make install
[wuhua@VM_0_10_centos php-7.2.10]$ make test
```
在阿里云低配服务器中编译安装报错：

```
virtual memory exhausted: 无法分配内存	
make: *** [ext/fileinfo/libmagic/apprentice.lo] 错误 1
```
参考[阿里云 virtual memory exhausted: 无法分配内存](https://www.cnblogs.com/kccdzz/p/8005944.html)

```
[wuhua@iZ2zeam0ijtd4z6q0e4y8eZ php-7.2.10]$  free -m
              total        used        free      shared  buff/cache   available
Mem:            992         147         726           0         118         710
Swap:             0           0           0
[wuhua@iZ2zeam0ijtd4z6q0e4y8eZ php-7.2.10]$ sudo  dd if=/dev/zero of=/swap bs=1024 count=1M 
[sudo] wuhua 的密码：
记录了1048576+0 的读入
记录了1048576+0 的写出
1073741824字节(1.1 GB)已复制，8.44555 秒，127 MB/秒
[wuhua@iZ2zeam0ijtd4z6q0e4y8eZ php-7.2.10]$ sudo  mkswap /swap
正在设置交换空间版本 1，大小 = 1048572 KiB
无标签，UUID=2c71ba39-626b-4a40-92e0-531f102125fb
[wuhua@iZ2zeam0ijtd4z6q0e4y8eZ php-7.2.10]$ sudo su
[root@iZ2zeam0ijtd4z6q0e4y8eZ php-7.2.10]# swapon /swap 
swapon: /swap：不安全的权限 0644，建议使用 0600。
swapon: /swap：swapon 失败: 设备或资源忙
[root@iZ2zeam0ijtd4z6q0e4y8eZ php-7.2.10]#  echo "/swap swap swap sw 0 0" >> /etc/fstab
[root@iZ2zeam0ijtd4z6q0e4y8eZ php-7.2.10]# free -m
              total        used        free      shared  buff/cache   available
Mem:            992         150          69           0         772         686
Swap:          1023           0        1023
```

### 安装后配置
安装完成后直接运行`/usr/local/php7/sbin/php-fpm`会报错缺少配置的，需要进行相关的文件配置。
可以用编译后的配置文件复制到PHP7的配置目录（/usr/local/php7/etc/）。
#### 方法一：直接使用编译后未经优化处理的配置
```
[wuhua@VM_0_10_centos local]$  cp php-7.2.10/php.ini-production php7/etc/php.ini
[wuhua@VM_0_10_centos local]$ sudo cp php-7.2.10/sapi/fpm/init.d.php-fpm /etc/php-fpm
[wuhua@VM_0_10_centos etc]$ cp php-fpm.conf.default php-fpm.conf
[wuhua@VM_0_10_centos php-fpm.d]$  cp www.conf.default www.conf
```
#### 方法二：使用https://github.com/lizer2014/mylnmp/tree/master/PHP文中的配置
参考博客[PHP7中php.ini、php-fpm和www.conf的配置](https://typecodes.com/web/php7configure.html)
#### 修改php.ini参数
```
[wuhua@VM_0_10_centos etc]$ vi php.ini
```
extension_dir改为自己的，设置时区，开启OPcache
```
/extension_dir  //vi查找extension_dir配置
extension_dir = "/home/wuhua/local/php7/lib/php/extensions/no-debug-non-zts-20170718/"
/timezone       //vi查找timezone配置
date.timezone =  PRC

opcache.enable=1;
```
#### 添加php的环境变量
创建php.sh添加内容

```
export PATH=$PATH:/home/wuhua/local/php7/bin/:/home/wuhua/local/php7/sbin/
```

```
[wuhua@VM_0_10_centos profile.d]$ sudo vim /etc/profile.d/php.sh
[wuhua@VM_0_10_centos profile.d]$ source /etc/profile.d/php.sh
[wuhua@VM_0_10_centos profile.d]$ php -v
PHP 7.2.10 (cli) (built: Oct  8 2018 17:39:07) ( NTS )
Copyright (c) 1997-2018 The PHP Group
Zend Engine v3.2.0, Copyright (c) 1998-2018 Zend Technologies
```

### 添加到centos7开机自动启动
在系统服务目录里创建php-fpm.service文件

添加内容

```
[wuhua@VM_0_10_centos profile.d]$ sudo vi /lib/systemd/system/php-fpm.service
[sudo] wuhua 的密码：
[wuhua@VM_0_10_centos profile.d]$ cat  /lib/systemd/system/php-fpm.service
[Unit]
Description=php-fpm
After=network.target
[Service]
Type=forking
ExecStart=/home/wuhua/local/php7/sbin/php-fpm
PrivateTmp=true
[Install]
WantedBy=multi-user.target
[wuhua@VM_0_10_centos profile.d]$ 
```

设置开机自启动

```
[wuhua@VM_0_10_centos profile.d]$ sudo systemctl enable php-fpm.service
Created symlink from /etc/systemd/system/multi-user.target.wants/php-fpm.service to /usr/lib/systemd/system/php-fpm.service.
[wuhua@VM_0_10_centos profile.d]$ 
```

当php-fpm启动时使用`systemctl start php-fpm.service`启动会报错，需要先`pa aux | grep php`查找对应的pid，杀死进程后再启动。

---
## nginx配置fast-cgi并测试lnmp
`mkdir /var/www`新建www目录，`cp /usr/local/nginx/html/* /var/www`将nginx自带web目录内文件复制到www中，即将/var/www作为web目录。新建index.php，内容为：
```code
<?php
//echo phpinfo();
$servername = "127.0.0.1";
$username = "huagege";
$password = "123456789";

try {
    $conn = new PDO("mysql:host=$servername;dbname=huagege", $username, $password);
    echo "连接成功";
}
catch(PDOException $e)
{
    echo $e->getMessage();
}      
```
`vi /usr/local/nginx/conf/nginx.conf`打开配置文件将root指令一一改为"/var/www"，注意php后缀解析的设置。
```code
location / {
    root   /var/www;
    index  index.html index.htm;
}

location = /50x.html {
    root   /var/www;
}

location ~ \.php$ {
    root           /var/www;
    fastcgi_pass   127.0.0.1:9000;
    fastcgi_index  index.php;
    fastcgi_param  SCRIPT_FILENAME  /var/www$fastcgi_script_name;
    include        fastcgi_params;
}
```
尝试浏览器输入IP/index.php，显示成功连接数据库。由于之前将各项服务都加入到了开机启动，重启后再次访问仍然正常。至此，lnmp搭建完成。