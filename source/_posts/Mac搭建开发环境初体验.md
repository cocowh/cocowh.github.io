---
title: Mac搭建开发环境初体验
tags: [php,redis,nginx,phpredis,mysql]
comments: true
categories: [php]
date: 2018-07-05 13:27:55
---
周一入职，已经是第4天了，这两天在配置开发环境上走了不少坑，记录下来以备后续查阅。

公司配的mac周二下午才到，全新的13.3寸256/8G的MacBookPro，希望自己的技术能力能配得上使用的工具。周一leader让在自带的电脑上配置nginx+mysql+redis+php开发环境，由于之前已经配置过很多次，所以主要是查看配置的合理性以及安装redis及相应的php拓展。redis在其官网上有相应的安装教程，phpredis找包然后下载解压缩，使用phpize生成configure文件，make & make install，在php.ini中添加拓展。在检查lnmp的过程中，发现nginx是用的默认包管理工具安装的，想将这些都安装在一个地方便与使用和管理，于是卸载之自己编译安装，安装过程根据自己之前记录的一篇博客来的。最后在配置nginx时，又遇到了权限问题，昨天在Mac上搭建时也遇到了这个问题，解决办法简洁点就是将user设置为当前用户组用户，将指定的web目录从根文件开始赋予能够访问的权限。

初次使用Mac，这几天的环境搭建过程中踩坑收获如下：
* 安装brew,mac下的包管理工具，感觉比centos的yum/rpm更好使，比自己动手编译安装的缺点是经常需要通过brew info得知安装软件的配置文件和执行文件位置，不便于管理。
* 自带php7.1.16，以php-fpm模式运行需要自己配置相关文件，在/etc目录下。   
* 在/etc/paths.d中以文件的方式添加环境变量更加方便管理，source后在另开的终端中才会生效。
* 编译安装nginx和使用brew安装nginx，配置web目录遇到的权限问题同上方式解决。
* 有mac下的mysql安装包，直接下载点点点，别忘了记下弹出的初始密码，也可使用brew安装。
* 使用brew安装redis，下载编译phpredis，phpize、./configure、make这三步没有问题，make install遇到`Operation not permitted`报错，查询得知Mac下的SIP机制导致的，需要在重启Mac过程中按`command`+`R`过程进入恢复模式，打开终端输入`csrutil disable`关闭SIP，再次重启电脑执行make install成功，在php.ini中添加拓展。

周三晚上终于把环境搞定了，然后配置git配置node把此博客进行了迁移。书到用时方恨少，今天开始，好好学习好好工作！

在[Laravel 的部署](https://laravel-china.org/docs/laravel/5.6/deployment/1357#nginx)，附份nginx配置文件以备后续参考。

```code
server {
    listen 80;
    server_name localhost;
    root /Users/wuhua/Desktop/TAL-practice/login/public;

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
        fastcgi_param   SCRIPT_FILENAME /Users/wuhua/Desktop/TAL-practice/login/public$fastcgi_script_name;
        include         fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```
