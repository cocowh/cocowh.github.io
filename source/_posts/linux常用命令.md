---
title: linux常用命令
tags: [shell,linux]
comments: true
categories: [linux]
date: 2018-07-24 17:47:29
---
### linux基础命令tail/cat/top/mkdir/vi/chmod等
linux命令使用的详细参数可以通过man command进行查询，一般比较容易忘记命令的具体作用，下面仅对这些命令的具体功能及作用进行记录，并给出相应的命令使用。

参考：[Linux 命令大全](http://www.runoob.com/linux/linux-command-manual.html)

### tail命令
作用：查看文件的尾部内容，不带参数则默认显示后十条。

查看正在改变的nginx日志：

```
tail -f  com.access_log
```
查看第5条开始往后信息：

```
tail +5 com.access_log
```
查看最后十个字符：

```
tail -c 10 com.access_log
```
### cat命令
作用：连接文件并打印到标准输出设备上。

将nginx日志文件显示行号输入到备份文件中：

```
cat -n com.access_log backup_log
```
将nginx日志文件cn.access_log和com.access_log加上行号（空白行不加）附加到备份文件中：

```
cat -b com.access_log cn.access_log >> backup_log
```
清空日志com.access_log内容（遇到权限问题，需要sudo su到root）：

```
cat /dev/null > com.access_log
```
制作镜像文件（假设软盘放好后）：

```
cat /dev/fd0 > OUTFILE
```
把镜像写入软盘（假设软盘放好后）：

```
cat IMG_FILE > /dev/fd0
```
### top命令
作用：实时显示进程状态。

mac和linux（服务器为centos7）下top的参数是有些不一致的。

[参考文档](http://www.runoob.com/linux/linux-comm-top.html)上是linux下的使用。

### mkdir命令
作用：创建目录。

于TEST目录下创建test子目录，若TEST目录不存在则创建一个。

```
mkdir TEST/test
```
### vi命令
作用：文本编辑器。

[Vim快捷键键位图](https://www.runoob.com/w3cnote/all-vim-cheatsheat.html)
[vi/vim 的使用](http://www.runoob.com/linux/linux-vim.html)

### chmod
作用：修改文件权限。

[linux文件的权限表示](https://www.cnblogs.com/123-/p/4189072.html)。

[实例](http://www.runoob.com/linux/linux-comm-chmod.html)。

### ssh及scp

```
ssh -p 22 root@ip
```
mac上传文件/目录到服务器：

上传目录到服务器

```
scp -r dir root@ip:/root/
```
上传文件到服务器

```
scp -r file.txt root@ip:/root/
```
拷贝服务器文件到本地则调换后两个参数顺序。