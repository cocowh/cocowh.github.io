---
title: nginx多站点配置及日志分析
tags: [php,nginx,linux,laravel]
comments: true
categories: [php]
date: 2018-07-23 09:29:09

---
nginx配置多个站点、nginx日志配置和查看，根据日志统计访问次数、响应时间

---

#### 参考文档
 1. [Nginx 中文官方文档
](https://www.kancloud.cn/wizardforcel/nginx-doc/92350)

#### 多站点配置
由于使用的brew安装的nginx，配置文件目录`/usr/local/etc/nginx`。

方法一：新建server，由于我们在本地操作，ip都是127.0.0.1对应localhost，所以为区分站点可只修改listen、root及php脚本fastcgi_param。需要指定路径下有站点目录。此时重启nginx，通过localhost:端口即可访问不同的站点。
	
方法二：在/etc/hosts文件中新增两个域名解析到127.0.0.1，我新增的是： 
 
```
127.0.0.1 bighua.com
127.0.0.1 bighua.cn
```
然后修改两个server的server_name、root及php脚本fastcgi_param。在指定路径下要有站点目录。此时重启nginx，通过两个域名即可正确访问两个不同的站点。

#### nginx日志配置和查看
使用brew安装的nginx默认的日志文件在目录`/usr/local/var/log/nginx`下，但是根据nginx文档可以自己在每个server中单独配置访问日志。
在第一个server中新增：

```
access_log   /Users/wuhua/Desktop/nginxlog/com.access_log;
```
在第二个server中新增：

```
access_log   /Users/wuhua/Desktop/nginxlog/cn.access_log;
```
在http外或server外新增（即全局）：

```
error_log    /Users/wuhua/Desktop/nginxlog/myerror_log;
```
errlog_log只会以第一个为准，即在两个server中定义不同的error_log只会生成第一个server中的error_log文件。  
之后重启nginx，在桌面上的nginxlog目录下会生成三个文件分别为：com.access_log、cn.access_log、cn.error_log。访问上面配置的两个域名，将会在两个访问日志中记录访问信息，出错信息记录到myerror_log。

#### 根据日志统计访问次数、响应时间
可以规定记录到日志中信息的格式，并为格式命名，然后在日志尾部通过命名应用格式。如下：

```
log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for"';
 
access_log   /Users/wuhua/Desktop/nginxlog/com.access_log main;
```

格式中的信息表示如下表：

变量 | 含义 | 示例
:- | :- | :-
$remote_addr | 客户端地址 | 127.0.0.1
$remote_user | 客户端用户名称 | --
$time_local | 访问时间和时区 | 23/Jul/2018:17:23:15 +0800
$request | 请求的url和http协议 | GET /login HTTP/1.1
$status | HTTP请求状态 | 200
$upstream_status | upstream状态 | 200
$body_bytes_sent | 发送给客户端文件内容大小 | 4618
$http_referer | url跳转来源 | http://bighua.cn/register
$http_user_agent | 用户终端浏览器等信息 | Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36
$http_x_forwarded_for |  客户端的真实ip | 127.0.0.1(通常web服务器放在反向代理的后面，这样就不能获取到客户的IP地址了，通过$remote_add拿到的IP地址是反向代理服务器的iP地址。反向代理服务器在转发请求的http头信息中，可以增加 x_forwarded_for信息，用以记录原有客户端的IP地址和原来客户端请求的服务器地址.)
$ssl_protocol | SSL协议版本 |	TLSv1（https请求）
$ssl_cipher | 交换数据中的算法 | RC4-SHA(https请求)
$upstream_addr | 后台upstream的地址，即真正提供服务的主机地址 | 127.0.0.1:80
$request_time | 整个请求的总时间 | 0.205
$upstream_response_time | 请求过程中，upstream响应时间 | 0.002

未经设置默认eccess_log中的一条日志信息：

```
127.0.0.1 - - [23/Jul/2018:17:23:15 +0800] "GET /login HTTP/1.1" 200 4618 "http://bighua.cn/register" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36"
```
统计访问次数和响应时间，我们根据客户端真实IP($http_x_forwarded_for)/客户端地址($remote_addr)确定用户统计次数，然后在格式中添加$upstream_response_time和$request_time记录每一次请求的服务器响应时间和整个请求的时间。

设置log_format如下：

```
log_format  myfmt   '$remote_addr - $remote_user [$time_local] "$request" '
					   '$request_time $upstream_response_time '
                    '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for" ';
```
重启nginx再次访问页面查看最新一条日志记录如下：

```
127.0.0.1 - - [23/Jul/2018:19:49:17 +0800] "GET /login HTTP/1.1" 0.045 0.045 200 4618 "http://bighua.cn/register" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36" "-"
```
第一项`127.0.0.1`为用户地址，第八项和第九项0.045为整个请求的时间和服务器响应时间，统计访问次数则是统计第一项每个地址的出现次数。

配置详情：

```
user  wuhua admin;
worker_processes  1;
#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;
error_log    /Users/wuhua/Desktop/nginxlog/myerror_log;

#pid        logs/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';
    
    log_format  myfmt   '$remote_addr - $remote_user [$time_local] "$request" '
			'$request_time $upstream_response_time '
                    	'$status $body_bytes_sent "$http_referer" '
                   	'"$http_user_agent" "$http_x_forwarded_for" ';
    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    #gzip  on;

    server {
    	listen 80;
    	server_name bighua.com;
   		root /Users/wuhua/Desktop/TAL-practice/login/public;
		access_log   /Users/wuhua/Desktop/nginxlog/com.access_log myfmt;	
	
    	add_header X-Frame-Options "SAMEORIGIN";
    	add_header X-XSS-Protection "1; mode=block";
   		add_header X-Content-Type-Options "nosniff";

    	index index.html index.htm index.php;

   		charset utf-8;
   		location / {
        	try_files $uri $uri/ /index.php?$query_string;
    	}

    	location = /favicon.ico { access_log off; log_not_found off; }
    	location = /robots.txt  { access_log off; log_not_found off; }

    	error_page 404 /index.php;

    	location ~ \.php$ {
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
        	fastcgi_pass    127.0.0.1:9000;
        	fastcgi_index   index.php;
        	fastcgi_param 	SCRIPT_FILENAME /Users/wuhua/Desktop/TAL-practice/login/public$fastcgi_script_name;
		include 	fastcgi_params;
    	}

    	location ~ /\.(?!well-known).* {
        	deny all;
    	}
    }
  
    server {
        listen 80;
        server_name bighua.cn;
        root /Users/wuhua/Desktop/TAL-practice/loginold/public;
        access_log   /Users/wuhua/Desktop/nginxlog/cn.access_log myfmt;

        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Content-Type-Options "nosniff";

        index index.html index.htm index.php;

        charset utf-8;
        location / {
                try_files $uri $uri/ /index.php?$query_string;
        }

        location = /favicon.ico { access_log off; log_not_found off; }
        location = /robots.txt  { access_log off; log_not_found off; }

        error_page 404 /index.php;

        location ~ \.php$ {
                fastcgi_split_path_info ^(.+\.php)(/.+)$;
                fastcgi_pass    127.0.0.1:9000;
                fastcgi_index   index.php;
                fastcgi_param   SCRIPT_FILENAME /Users/wuhua/Desktop/TAL-practice/loginold/public$fastcgi_script_name;
                include         fastcgi_params;
        }

        location ~ /\.(?!well-known).* {
                deny all;
        }
    } 
    include servers/*;
}
```
参考博客[Nginx 日志分析及性能排查](https://www.cnblogs.com/handongyu/p/6513185.html)使用awk命令对日志进行处理。

另外自己的想法也可以通过php进行读文件处理，或则将awk命令处理过的日志存储数据库等等。

##### 使用awk进行日志分析
根据日志格式：

```
log_format  myfmt   '$remote_addr - $remote_user [$time_local] "$request" '
					   '$request_time $upstream_response_time '
                    '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for" ';
```
第一次处理需要提取的信息有第一项、第五项、第六项，但是不加分隔符awk默认使用‘ ’空隔作为分隔符，按上方格式获取的一条日志记录如下。

```
127.0.0.1 - - [23/Jul/2018:19:49:17 +0800] "GET /login HTTP/1.1" 0.045 0.045 200 4618 "http://bighua.cn/register" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36" "-"
```
使用awk对应提取第一列、第九列、第十列。

提取数据command：

```
cat **._access_log | awk '{print $1,$9,$10}'
```
因为有两个日志文件，命令也比较长，整理成shell：

```
#!/bin/bash
cat $1 | awk '{print( $1,$9,$10)}' > $1.data.csv
```

调用脚本，以日志为参数，保存结果为csv文件。

统计访问次数则根据访问ip使用uniq进行处理，command：

```
cat **._access_log | awk '{print $1}' | uniq -c
```
根据参考博客可以导出为csv文件，command：

```
cat **.access_log | awk '{print $1}' | uniq -c | awk '{print $1,$2}' > **.countip.csv
```
整理成shell：

```
#!/bin/bash
cat $1 | awk '{print $1}' | uniq -c | awk '{print $1,$2}' > $1.countip.csv
```
调用脚本，以日志为参数，保存处理结果为csv文件。

##### 使用ngxtop统计实时数据
项目地址：[nginxtop](https://github.com/lebinh/ngxtop)

安装：

```
sudo easy_install pip
sudo easy_install ngxtop
```
使用文档：[Usage](https://github.com/lebinh/ngxtop#usage)   
示例：

```
ngxtop -c PATH/nginx.conf -t 1
```

##### 使用php进行日志分析
这里就不在详叙了，想法就是读取文件，按行读取，按空格分割，从分隔结果的数据中取需要的数据。

#### 业务分析感悟
>通常我们根据日期为每天访问建立日志，同时对日志的分析，可以通过crontab设置定时任务，每天进行自动分析，可以考虑将分析结果存储到数据库等，便与查看。