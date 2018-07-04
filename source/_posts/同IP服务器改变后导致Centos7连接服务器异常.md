---
title: 同IP服务器改变后导致Centos7连接服务器异常
tags: [Centos,ssh登陆,shell]
comments: true
categories: [linux]
date: 2018-05-09 13:22:18
---
### 背景
前段时间跟着《Go并发编程实战 1&2》和其他相关资料学习了go，现在着手进行相关的实践练习。与是把之前的服务器重置了下，重新配置go的相关运行环境。
### 问题
服务器用的阿里云的学生机，再过一个多月毕业就要到期了。一般可以直接使用ssh相关命令进行服务器的连接:
```code
[root@localhost]# ssh root@101.200.50.5 //亦可ssh 101.200.50.5(限root权限下)
root@101.200.50.5's password: 
Last login: Wed May  9 13:59:50 2018 from 220.249.99.148

Welcome to Alibaba Cloud Elastic Compute Service !

[root@iZjgheeixigi44Z ~]# 
```
此时连接登陆成功。

但是看到Centos7有自带的连接服务器功能，于是在重置服务器之前直接尝试进行了连接。
`其他位置`-`连接到服务器（S）`输入框输入：
>`fstp://101.200.50.5`

可正常连接并且直接显示服务器中的文件。在显示的文件里右键选择`在本地终端打开(L)`和`在远程终端打开(R)`，直接建立终端连接。选择后者等同于上面的直接通过ssh命令建立终端连接，打开的终端为：
>`[root@iZjgheeixigi44Z ~]# `

选择前者等同于通过本地的协议打开终端，非直接服务器终端，打开的终端为：
>`joker@localhost sftp:host=101.200.50.5]$ `

目前为止一切正常。但当我对服务器进行重置更换系统盘后再次使用centos7自带连接功能进行连接，报错提示主机连接失败。通过查询得知，`由于更换了服务器，使用了相同IP，导致公钥与服务器的私钥配对失败，无法登陆服务器。需要删除旧服务器(101.200.50.5)的公钥才行`，操作如下：
```code
ssh-keygen -f "/home/joker/.ssh/known_hosts" -R 101.200.50.5
```
此时会将原known_hosts文件（含101.200.50.5公钥）备份为known_hosts.old，删除公钥后的文件为known_hosts，文件内容私密此处不展示。

再次使用Centos7自带的进行连接报错信息为：`无法验证101.200.50.5（101.200.50.5）的标识。这会在您首次登陆计算机时发生。...`。然后需要点3次才能正确连接登陆成功。

此时使用普通用户权限运行`ssh 101.200.50.5`或者`ssh root@101.200.50.5`命令进行连接时报错为：
```code
[joker@localhost ~]# ssh 101.200.50.5
The authenticity of host '101.200.50.5 (101.200.50.5)' can't be established.
ECDSA key fingerprint is SHA256:3oG4dc22CqV2FOH1FS9ROi7yfi88y0nNN1JeBK8393g.
ECDSA key fingerprint is MD5:7c:5d:cd:15:1a:d7:7c:28:55:53:2f:47:ec:1b:6e:2a.
Are you sure you want to continue connecting (yes/no)? yes   
...
```
需要3次确认才通过，相当于上方的使用Centos7自带连接的报错。通过查询得到解决办法为修改/etc/ssh/ssh_config文件（或$HOME/.ssh/config）中的配置，添加：
```code
StrictHostKeyChecking no
```
执行仍提示错误：
```code
[joker@localhost ~]$ ssh 101.200.50.5
Failed to add the host to the list of known hosts (/home/joker/.ssh/known_hosts).
joker@101.200.50.5's password: 
```
因对.ssh中的文件没有写权限，需要切换到root赋权：
```code
[joker@localhost ~]$ su
密码：
[root@localhost joker]# chmod -R 777 .ssh
```
再切换到用户权限运行：
```code
[joker@localhost ~]$ ssh 101.200.50.5
Warning: Permanently added '101.200.50.5' (ECDSA) to the list of known hosts.
joker@101.200.50.5's password: 
Permission denied, please try again.
joker@101.200.50.5's password: 
```
提示说明已经将101.200.50.5添加到了known_hosts文件中，查看此文件可发现内容有改变。若使用普通用户权限下执行`ssh 101.200.50.5`登陆还需要其他设置，否则无法登录，但普通用户权限下执行`ssh root@101.200.50.5`可登陆。一般使用root权限进行服务器的登陆，两者都可正常登陆。

然后再回到最开始报错的Centos7自带的服务器连接，此时可正常连接登录了。但是`在远程终端打开（R）`仍然相当于在普通用户权限下的`ssh root@101.200.50.5`命令，需要其他的设置，使用`在本地终端打开（L）`无影响，恢复到最开始的状态。

### 总结
针对Centos7使用自带的功能连接服务器，同IP服务器改变后导致使用此自带功能连接出现无法登陆问题。实际解决步骤：  

移除known_hosts文件中的旧IP项
```code
ssh-keygen -f "/home/joker/.ssh/known_hosts" -R IP 
```
修改/etc/ssh/ssh_config中的配置，这一步主要是去除多次的连接询问提示，之后可改回来，添加：
```code
StrictHostKeyChecking no
```
普通用户权限下执行ssh IP将IP添加到known_hosts：
```code
chmod 777 known_hosts //若有写权限此步忽略，否则切换到root赋权后再切换到普通用户

ssh root@IP
password: 
```
这一步主要是将IP再此添加到known_hosts中，不是为了登陆。而且普通用户权限下`ssh IP`被禁止登陆，使用`ssh root@IP`指定root用户才可以登陆，在root权限下都可正常登陆。

之后再次使用Centos7自带的连接服务可正常连接。

感觉Centos7这个自带的可使用各种协议连接服务器没啥用，多了一个服务器端文件的直接显示，即将服务器桌面化显示。还是ssh命令直接连接方便实用。