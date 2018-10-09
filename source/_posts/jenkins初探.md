---
title: jenkins初探
tags: [持续集成,jenkins]
comments: true
categories: [web杂记]
date: 2018-10-08 19:33:45
---
参考文档[Jenkins学习文档](https://www.kancloud.cn/louis1986/jenkins/481896)，[CentOS7Jenkins安装](https://blog.csdn.net/sms15732621690/article/details/71336224)

### 安装JDK
```
[wuhua@VM_0_10_centos local]$ sudo wget http://soft.51yuki.cn/jdk-8u131-linux-x64.rpm
```

```
[wuhua@VM_0_10_centos local]$ sudo rpm -ivh jdk-8u131-linux-x64.rpm
```

```
[wuhua@VM_0_10_centos local]$ sudo vim /etc/profile.d/jdk.sh
```

```
#set java environment
JAVA_HOME=/usr/java/jdk1.8.0_131/
CLASSPATH=.:${JAVA_HOME}/lib.tools.jar
PATH=$PATH:${JAVA_HOME}/bin
```

```
[wuhua@VM_0_10_centos local]$  sudo sh /etc/profile.d/jdk.sh
[wuhua@VM_0_10_centos local]$ java -version
java version "1.8.0_131"
Java(TM) SE Runtime Environment (build 1.8.0_131-b11)
Java HotSpot(TM) 64-Bit Server VM (build 25.131-b11, mixed mode)
```

### 安装jenkins
```
[wuhua@VM_0_10_centos src]$ sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
```

```
[wuhua@VM_0_10_centos src]$ sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
```

```
yum install jenkins
```

```
sudo service jenkins start
```

### 运行
浏览器中输入`ip:8080`

获取登录密码：

```
[wuhua@VM_0_10_centos src]$ sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### 重置密码

参考[忘记Jenkins管理员密码的解决办法](https://blog.csdn.net/jlminghui/article/details/54952148)