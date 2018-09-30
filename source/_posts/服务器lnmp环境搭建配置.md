---
title: 服务器lnmp环境搭建配置
tags: [linux,nginx,mysql,php7,shell]
comments: true
categories: [php]
date: 2018-05-09 23:26:50
---
搭建本博客之初的原因之一，就是在搭建lnmp和其他系列环境时遇到了很多问题，今天将服务器重置了，先配置好了go环境，在{% post_link Golang笔记-基础篇-一 %}的初始部分进行了相关步骤的补充。下面记录下lnmp环境的搭建配置。

## nginx编译安装
### 下载
可通过[https://nginx.org/en/download.html](https://nginx.org/en/download.html)选择版本，然后服务器端下载到/usr/local，此处选择最新稳定版1.14.0。
```code
[root@iZjgheeixigi44Z local]# wget -c https://nginx.org/download/nginx-1.14.0.tar.gz
```
解压缩
```code
[root@iZjgheeixigi44Z local]# tar -zxvf nginx-1.14.0.tar.gz
```
### 配置
#### 使用默认配置
```code
[root@iZjgheeixigi44Z nginx-1.14.0]# ./configure --prefix=/usr/local/nginx --conf-path=/usr/local/nginx/nginx.conf
```
但是报错
```code
./configure: error: the HTTP rewrite module requires the PCRE library.
You can either disable the module by using --without-http_rewrite_module
option, or install the PCRE library into the system, or build the PCRE library
statically from the source with nginx by using --with-pcre=<path> option.
```
提示缺少pcre库，给出了解决办法忽略此项或者安装缺少的pcre库，经过搜索得知库为`pcre-devel`而不是`pcre`。安装库
```code
[root@iZjgheeixigi44Z nginx-1.14.0]# yum -y install pcre-devel
```
再次运行`./configure`正确。
#### 自定义配置（不推荐）
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
将临时文件目录指定为/var/temp/nginx，需要在/var下创建temp及nginx目录，另外前两两项需要先创建好用户和用户组。
### 编译安装
```code
make & make install
```
可使用`whereis nginx`查看安装的路径。
### 为nginx的启动、重启、重载配置添加脚本
#### 直接启动方法
```code
/usr/local/nginx/sbin/nginx
```
#### 添加脚本控制
>新建文件
```code
vim /usr/lib/systemd/system/nginx.service
```

>添加内容
```code
[Unit]
Description=nginx - high performance web server
Documentation=http://nginx.org/en/docs/
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/usr/local/nginx/logs/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
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
```code
[root@izjgheeixigi44z ~]# systemctl enable nginx.service
Created symlink from /etc/systemd/system/multi-user.target.wants/nginx.service to /usr/lib/systemd/system/nginx.service.
```
至此以安装成功，通过IP可访问显示nginx页面。

---
## mysql安装（centos7默认mariadb）
### 安装
```code
[root@iZjgheeixigi44Z /]# yum -y install mariadb mariadb-server
```
### 启动MariaDB并加入开机启动
```code
[root@iZjgheeixigi44Z /]# systemctl start mariadb
[root@iZjgheeixigi44Z /]# systemctl enable mariadb
Created symlink from /etc/systemd/system/multi-user.target.wants/mariadb.service to /usr/lib/systemd/system/mariadb.service.
```
其他命令
```code
systemctl start mariadb #启动服务
systemctl enable mariadb #设置开机启动
systemctl restart mariadb #重新启动
systemctl stop mariadb.service #停止MariaDB
```
### 初次登陆设置密码等
登陆到数据库，初次登陆密码为空
```code
[root@iZjgheeixigi44Z /]# mysql -uroot
```
配置root密码，第一步密码为空，初次设置
```code
[root@iZjgheeixigi44Z /]# mysql_secure_installation

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
有些指令忘记了，要常用呀。
```code
[root@iZjgheeixigi44Z /]# mysql -uroot -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 3
Server version: 5.5.56-MariaDB MariaDB Server

Copyright (c) 2000, 2017, Oracle, MariaDB Corporation Ab and others.

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
[root@iZjgheeixigi44Z /]# mysql -uhuagege -p 
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 4
Server version: 5.5.56-MariaDB MariaDB Server

Copyright (c) 2000, 2017, Oracle, MariaDB Corporation Ab and others.

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
[root@iZjgheeixigi44Z /]# 
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
可以通过[http://php.net/downloads.php](http://php.net/downloads.php)查看现有的版本，然后直接在服务器端下载源码包，此处选择最新版7.2.5，此源下载很慢，建议选择其他源。
```code
[root@iZjgheeixigi44Z local]# wget -c http://cn2.php.net/distributions/php-7.2.5.tar.gz
```
解压缩
```code
tar -xvzf php-7.2.5.tar.gz
cd php-7.2.5
```
### 编译配置
#### 安装依赖库
根据之前的编译安装，centos7缺少的libmcrypt、mhash、mcrypt这三个库需要添加源才能下载到（源忘记了），使用的阿里云虚拟机可以直接下载安装。后续编译过程中根据所缺再增加。
```code
[root@iZjgheeixigi44Z local]# yum -y install libmcrypt mhash mcrypt
```
也可先运行直接全部安装所需库
```code
[root@iZjgheeixigi44Z local]# yum -y install wget vim pcre pcre-devel openssl openssl-devel libicu-devel gcc gcc-c++ autoconf libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel zlib zlib-devel glibc glibc-devel glib2 glib2-devel ncurses ncurses-devel curl curl-devel krb5-devel libidn libidn-devel openldap openldap-devel nss_ldap jemalloc-devel cmake boost-devel bison automake libevent libevent-devel gd gd-devel libtool* libmcrypt libmcrypt-devel mcrypt mhash libxslt libxslt-devel readline readline-devel gmp gmp-devel libcurl libcurl-devel openjpeg-devel
```
有些没有的话可以尝试更新源
```code
yum install epel-release
yum update
```
若源找不到对应库，也可直接将yum源更换为阿里云源
```yum
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum makecache
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
一般将nginx、php-fpm及网站根目录运行在nobody，不选择相应配置项默认即为nobody。创建用户用户组(自己用的默认nobody)：
```code
groupadd www
useradd -g www www
```
最终配置为：
```code
./configure -prefix=/usr/local/php7 -with-config-file-path=/usr/local/php7/etc -with-config-file-scan-dir=/usr/local/php7/etc/conf.d -enable-fpm -enable-soap -with-openssl -with-openssl-dir -with-pcre-regex -with-zlib -with-iconv -with-bz2 -enable-calendar -with-curl -with-cdb -enable-dom -enable-exif -with-pcre-dir -enable-ftp -with-gd -with-jpeg-dir -with-png-dir -with-freetype-dir -with-gettext -with-gmp -with-mhash -enable-mbstring -with-libmbfl -with-onig -enable-pdo -with-pdo-mysql -with-zlib-dir -with-readline -enable-session -enable-shmop -enable-simplexml -enable-sockets -enable-sysvmsg -enable-sysvsem -enable-sysvshm -enable-wddx -with-libxml-dir -with-xsl -enable-zip -enable-mysqlnd -with-mysqli -enable-embedded-mysqli -enable-bcmath -enable-inline-optimization -enable-mbregex -enable-pcntl  -with-xmlrpc -enable-opcache
```
注意：php7.2版本不支持–with-mcrypt, –enable-gd-native-ttf。在phh7.1时，官方就开始建议用openssl_\*系列函数代替mcrypt_\*系列的函数。7.2版本加上这两项配置无法通过的。
### 编译安装
```code
make && make install
make test
```
### 安装后配置
安装完成后直接运行`/usr/local/php7/sbin/php-fpm`会报错缺少配置的，需要进行相关的文件配置。
可以用编译后的配置文件复制到PHP7的配置目录（/usr/local/php7/etc/），推荐使用 github中的配置。
#### 方法一：直接使用编译后未经优化处理的配置
```code
[root@iZjgheeixigi44Z php-7.2.5]# cp php.ini-production /usr/local/php7/etc/php.ini
[root@iZjgheeixigi44Z php-7.2.5]# cp /usr/local/php-7.2.5/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
[root@iZjgheeixigi44Z php-7.2.5]# cp /usr/local/php7/etc/php-fpm.conf.default /usr/local/php7/etc/php-fpm.conf
[root@iZjgheeixigi44Z php-7.2.5]# cp /usr/local/php7/etc/php-fpm.d/www.conf.default /usr/local/php7/etc/php-fpm.d/www.conf
```
#### 方法二：使用https://github.com/lizer2014/mylnmp/tree/master/PHP文中的配置
参考博客[PHP7中php.ini、php-fpm和www.conf的配置](https://typecodes.com/web/php7configure.html)
#### 修改php.ini参数
```code
[root@iZjgheeixigi44Z extensions]# vi /usr/local/php7/etc/php.ini
```
extension_dir改为自己的，设置时区，开启OPcache
```code
/extension_dir  //vi查找extension_dir配置
extension_dir = "/usr/local/php7/lib/php/extensions/no-debug-non-zts-20170718/"
/timezone       //vi查找timezone配置
date.timezone =  PRC

zend_extension=opcache.so;
```
#### 添加php的环境变量
创建php.sh添加内容
```code
export PATH=$PATH:/usr/local/php7/bin/:/usr/local/php7/sbin/
```
```code
[root@iZjgheeixigi44Z etc]# vim /etc/profile.d/php.sh
[root@iZjgheeixigi44Z etc]# source /etc/profile.d/php.sh
[root@iZjgheeixigi44Z etc]# php -v
PHP 7.2.5 (cli) (built: May 10 2018 14:03:12) ( NTS )
Copyright (c) 1997-2018 The PHP Group
Zend Engine v3.2.0, Copyright (c) 1998-2018 Zend Technologies
    with Zend OPcache v7.2.5, Copyright (c) 1999-2018, by Zend Technologies
[root@iZjgheeixigi44Z etc]# 
```
此时已经启动php-fpm，可正常运行。
### 添加到centos7开机自动启动
在系统服务目录里创建php-fpm.service文件
```code
vi /lib/systemd/system/php-fpm.service
```
添加内容
```code
[Unit]
Description=php-fpm
After=network.target
[Service]
Type=forking
ExecStart=/usr/local/php7/sbin/php-fpm
PrivateTmp=true
[Install]
WantedBy=multi-user.target
```
设置开机自启动
```code
[root@iZjgheeixigi44Z lib]# systemctl enable php-fpm.service
Created symlink from /etc/systemd/system/multi-user.target.wants/php-fpm.service to /usr/lib/systemd/system/php-fpm.service.
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