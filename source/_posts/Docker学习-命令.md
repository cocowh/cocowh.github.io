---
title: Docker学习-命令
tags: [Docker,mac,命令]
comments: true
categories: [Docker]
date: 2019-04-06 16:07:44
---

### 容器生命周期管理

#### run
docker run ：创建一个新的容器并运行一个命令

```
docker run [OPTIONS] IMAGE [COMMAND] [ARG...]
```

OPTIONS：

* -a stdin: 指定标准输入输出内容类型，可选 STDIN/STDOUT/STDERR 三项；
* -d: 后台运行容器，并返回容器ID；
* -i: 以交互模式运行容器，通常与 -t 同时使用；
* -p: 端口映射，格式为：主机(宿主)端口:容器端口
* -t: 为容器重新分配一个伪输入终端，通常与 -i 同时使用；
* --name="nginx-lb": 为容器指定一个名称；
* --dns 8.8.8.8: 指定容器使用的DNS服务器，默认和宿主一致；
* --dns-search example.com: 指定容器DNS搜索域名，默认和宿主一致；
* -h "mars": 指定容器的hostname；
* -e username="ritchie": 设置环境变量；
* --env-file=[]: 从指定文件读入环境变量；
* --cpuset="0-2" or --cpuset="0,1,2": 绑定容器到指定CPU运行；
* -m :设置容器使用内存最大值；
* --net="bridge": 指定容器的网络连接类型，支持 bridge/host/none/container: 四种类型；
* --link=[]: 添加链接到另一个容器；
* --expose=[]: 开放一个端口或一组端口；

EXAMPLES：

```
//使用docker镜像nginx:latest以后台模式启动一个容器,并将容器命名为mynginx
docker run --name mynginx -d nginx:latest

//使用镜像nginx:latest以后台模式启动一个容器,并将容器的80端口映射到主机随机端口
docker run -P -d nginx:latest

//使用镜像 nginx:latest，以后台模式启动一个容器,将容器的 80 端口映射到主机的 80 端口,主机的目录 /data 映射到容器的 /data
docker run -p 80:80 -v /data:/data -d nginx:latest

//绑定容器的 8080 端口，并将其映射到本地主机 127.0.0.1 的 80 端口上
docker run -p 127.0.0.1:80:8080/tcp ubuntu bash

//使用镜像nginx:latest以交互模式启动一个容器,在容器内执行/bin/bash命令。
docker run -it nginx:latest /bin/bash
```

#### start/stop/restart
docker start :启动一个或多个已经被停止的容器

```
docker start [OPTIONS] CONTAINER [CONTAINER...]
```

docker stop :停止一个运行中的容器

```
docker stop [OPTIONS] CONTAINER [CONTAINER...]
```

docker restart :重启容器

```
docker restart [OPTIONS] CONTAINER [CONTAINER...]
```

EXAMPLES:

```
//启动已被停止的容器myrunoob
docker start myrunoob

//停止运行中的容器myrunoob
docker stop myrunoob

//重启容器myrunoob

docker restart myrunoob
```

#### kill
docker kill :杀掉一个运行中的容器。

```
docker kill [OPTIONS] CONTAINER [CONTAINER...]
```

OPTIONS:

* -s :向容器发送一个信号

EXAMPLES:

```
//杀掉运行中的容器mynginx
docker kill -s KILL mynginx
```

#### rm 
docker rm ：删除一个或多少容器

```
docker rm [OPTIONS] CONTAINER [CONTAINER...]
```

OPTIONS:

* -f :通过SIGKILL信号强制删除一个运行中的容器
* -l :移除容器间的网络连接，而非容器本身
* -v :删除与容器关联的卷

EXAMPLES:

```
//强制删除容器db01、db02
docker rm -f db01 db02

//移除容器nginx01对容器db01的连接，连接名db
docker rm -l db 

//删除容器nginx01,并删除容器挂载的数据卷
docker rm -v nginx01
```

#### pause/unpause

docker pause :暂停容器中所有的进程。

```
docker pause [OPTIONS] CONTAINER [CONTAINER...]
```
docker unpause :恢复容器中所有的进程。

```
docker unpause [OPTIONS] CONTAINER [CONTAINER...]
```

EXAMPLES:

```
//暂停数据库容器db01提供服务。
docker pause db01

//恢复数据库容器db01提供服务。
docker unpause db01
```
#### create

docker create ：创建一个新的容器但不启动它

```
docker create [OPTIONS] IMAGE [COMMAND] [ARG...]
```

同`docker run`
EXAMPLES:

```
//使用docker镜像nginx:latest创建一个容器,并将容器命名为myrunoob
docker create  --name myrunoob  nginx:latest      
```

#### exec

docker exec ：在运行的容器中执行命令

```
docker exec [OPTIONS] CONTAINER COMMAND [ARG...]
```

OPTIONS:

* -d :分离模式: 在后台运行
* -i :即使没有附加也保持STDIN 打开
* -t :分配一个伪终端


EXAMPLES:

```
//在容器mynginx中以交互模式执行容器内/root/runoob.sh脚本
docker exec -it mynginx /bin/sh /root/runoob.sh
//在容器mynginx中开启一个交互模式的终端
docker exec -i -t  mynginx /bin/bash
```

### 容器操作
#### ps
docker ps : 列出容器

```
docker ps [OPTIONS]
```

OPTIONS:

* -a :显示所有的容器，包括未运行的。
* -f :根据条件过滤显示的内容。
* --format :指定返回值的模板文件。
* -l :显示最近创建的容器。
* -n :列出最近创建的n个容器。
* --no-trunc :不截断输出。
* -q :静默模式，只显示容器编号。
* -s :显示总的文件大小。

EXAMPLES:

```
//列出所有在运行的容器信息
wuhua:blog wuhua$ docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
```

####inspect
docker inspect : 获取容器/镜像的元数据。

```
docker inspect [OPTIONS] NAME|ID [NAME|ID...]
```
OPTIONS:

* -f :指定返回值的模板文件。
* -s :显示总的文件大小。
* --type :为指定类型返回JSON。

EXAMPLES:

```
//获取镜像mysql:5.6的元信息
docker inspect mysql:5.6
//获取正在运行的容器mymysql的 IP
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' mymysql
```
#### top
docker top :查看容器中运行的进程信息，支持 ps 命令参数

```
docker top [OPTIONS] CONTAINER [ps OPTIONS]
```

容器运行时不一定有/bin/bash终端来交互执行top命令，而且容器还不一定有top命令，可以使用docker top来实现查看container中正在运行的进程。

EXAMPLES:

```
 docker top mymysql
```

#### attach
docker attach :连接到正在运行中的容器。

```
docker attach [OPTIONS] CONTAINER
```

要attach上去的容器必须正在运行，可以同时连接上同一个container来共享屏幕（与screen命令的attach类似）。

官方文档中说attach后可以通过CTRL-C来detach，但实际上经过我的测试，如果container当前在运行bash，CTRL-C自然是当前行的输入，没有退出；如果container当前正在前台运行进程，如输出nginx的access.log日志，CTRL-C不仅会导致退出容器，而且还stop了。这不是我们想要的，detach的意思按理应该是脱离容器终端，但容器依然运行。好在attach是可以带上--sig-proxy=false来确保CTRL-D或CTRL-C不会关闭容器。

EXAMPLES:

```
//容器mynginx将访问日志指到标准输出，连接到容器查看访问信息
docker attach --sig-proxy=false mynginx
```

#### events
docker events : 从服务器获取实时事件

```
docker events [OPTIONS]
```

OPTIONS:

* -f ：根据条件过滤事件；
* --since ：从指定的时间戳后显示所有事件;
* --until ：流水时间显示到指定的时间为止；

EXAMPLES:

```
//显示docker 2016年7月1日后的所有事件
docker events  --since="1467302400"
//显示docker 镜像为mysql:5.6 2016年7月1日后的相关事件
docker events -f "image"="mysql:5.6" --since="1467302400" 
```

如果指定的时间是到秒级的，需要将时间转成时间戳。如果时间为日期的话，可以直接使用，如--since="2016-07-01"。

#### logs
docker logs : 获取容器的日志
```
docker logs [OPTIONS] CONTAINER
```

OPTIONS:

* -f : 跟踪日志输出
* --since :显示某个开始时间的所有日志
* -t : 显示时间戳
* --tail :仅列出最新N条容器日志

EXAMPLES:

```
//跟踪查看容器mynginx的日志输出
docker logs -f mynginx
//查看容器mynginx从2016年7月1日后的最新10条日志
docker logs --since="2016-07-01" --tail=10 mynginx
```


#### wait
docker wait : 阻塞运行直到容器停止，然后打印出它的退出代码。

```
docker wait [OPTIONS] CONTAINER [CONTAINER...]
```

EXAMPLES:

```
docker wait CONTAINER
```

#### export
docker export :将文件系统作为一个tar归档文件导出到STDOUT。

```
docker export [OPTIONS] CONTAINER
```

OPTIONS:

* -o :将输入内容写到文件。

EXAMPLES:

```
//将id为a404c6c174a2的容器按日期保存为tar文件。
runoob@runoob:~$ docker export -o mysql-`date +%Y%m%d`.tar a404c6c174a2
runoob@runoob:~$ ls mysql-`date +%Y%m%d`.tar
mysql-20160711.tar
```

#### port
docker port :列出指定的容器的端口映射，或者查找将PRIVATE_PORT NAT到面向公众的端口。

```
docker port [OPTIONS] CONTAINER [PRIVATE_PORT[/PROTO]]
```

EXAMPLES:

```
runoob@runoob:~$ docker port mymysql
3306/tcp -> 0.0.0.0:3306
```

###容器rootfs命令
#### commit
docker commit :从容器创建一个新的镜像。

```
docker commit [OPTIONS] CONTAINER [REPOSITORY[:TAG]]
```

OPTIONS:

* -a :提交的镜像作者；
* -c :使用Dockerfile指令来创建镜像；
* -m :提交时的说明文字；
* -p :在commit时，将容器暂停。

EXAMPLES:

```
//将容器a404c6c174a2 保存为新的镜像,并添加提交人信息和说明信息。
runoob@runoob:~$ docker commit -a "runoob.com" -m "my apache" a404c6c174a2  mymysql:v1 
sha256:37af1236adef1544e8886be23010b66577647a40bc02c0885a6600b33ee28057
runoob@runoob:~$ docker images mymysql:v1
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
mymysql             v1                  37af1236adef        15 seconds ago      329 MB
```

#### cp
docker cp :用于容器与主机之间的数据拷贝。

```
docker cp [OPTIONS] CONTAINER:SRC_PATH DEST_PATH|-
docker cp [OPTIONS] SRC_PATH|- CONTAINER:DEST_PATH
```

OPTIONS:

* -L :保持源目标中的链接

EXAMPLES:

```
//将主机/www/runoob目录拷贝到容器96f7f14e99ab的/www目录下。
docker cp /www/runoob 96f7f14e99ab:/www/
//将主机/www/runoob目录拷贝到容器96f7f14e99ab中，目录重命名为www。
docker cp /www/runoob 96f7f14e99ab:/www
//将容器96f7f14e99ab的/www目录拷贝到主机的/tmp目录中。
docker cp  96f7f14e99ab:/www /tmp/
```

#### diff
docker diff : 检查容器里文件结构的更改。

```
docker diff [OPTIONS] CONTAINER
```

EXAMPLES:

```
//查看容器mymysql的文件结构更改。
runoob@runoob:~$ docker diff mymysql
A /logs
A /mysql_data
C /run
C /run/mysqld
A /run/mysqld/mysqld.pid
A /run/mysqld/mysqld.sock
C /tmp
```

### 镜像仓库
####login/logout
docker login : 登陆到一个Docker镜像仓库，如果未指定镜像仓库地址，默认为官方仓库 Docker Hub

docker logout : 登出一个Docker镜像仓库，如果未指定镜像仓库地址，默认为官方仓库 Docker Hub

```
docker login [OPTIONS] [SERVER]
docker logout [OPTIONS] [SERVER]
```

OPTIONS:

* -u :登陆的用户名
* -p :登陆的密码

EXAMPLES:

```
//登陆到Docker Hub
docker login -u 用户名 -p 密码
//登出Docker Hub
docker logout
```

#### pull
docker pull : 从镜像仓库中拉取或者更新指定镜像

```
docker pull [OPTIONS] NAME[:TAG|@DIGEST]
```

OPTIONS:

* -a :拉取所有 tagged 镜像
* --disable-content-trust :忽略镜像的校验,默认开启

EXAMPLES:

```
//从Docker Hub下载java最新版镜像。
docker pull java
//从Docker Hub下载REPOSITORY为java的所有镜像。
docker pull -a java
```

#### push
docker push : 将本地的镜像上传到镜像仓库,要先登陆到镜像仓库

```
docker push [OPTIONS] NAME[:TAG]
```

OPTIONS:

```
--disable-content-trust :忽略镜像的校验,默认开启
```

EXAMPLES:

```
//上传本地镜像myapache:v1到镜像仓库中。
docker push myapache:v1
```

#### search
docker search : 从Docker Hub查找镜像

```
docker search [OPTIONS] TERM
```

OPTIONS:

* --automated :只列出 automated build类型的镜像；
* --no-trunc :显示完整的镜像描述；
* -s :列出收藏数不小于指定值的镜像。

EXAMPLES:

```
wuhua:blog wuhua$ docker search -s 10 java
Flag --stars has been deprecated, use --filter=stars=3 instead
NAME                                         DESCRIPTION                                     STARS               OFFICIAL            AUTOMATED
node                                         Node.js is a JavaScript-based platform for s…   7238                [OK]                
tomcat                                       Apache Tomcat is an open source implementati…   2333                [OK]                
java                                         Java is a concurrent, class-based, and objec…   1967                [OK]                
openjdk                                      OpenJDK is an open-source implementation of …   1599                [OK]                
ghost                                        Ghost is a free and open source blogging pla…   951                 [OK]                
anapsix/alpine-java                          Oracle Java 8 (and 7) with GLIBC 2.28 over A…   402                                     [OK]
jetty                                        Jetty provides a Web server and javax.servle…   294                 [OK]                
couchdb                                      CouchDB is a database that uses JSON for doc…   269                 [OK]                
ibmjava                                      Official IBM® SDK, Java™ Technology Edition …   67                  [OK]                
groovy                                       Apache Groovy is a multi-faceted language fo…   66                  [OK]                
tomee                                        Apache TomEE is an all-Apache Java EE certif…   64                  [OK]                
lwieske/java-8                               Oracle Java 8 Container - Full + Slim - Base…   43                                      [OK]
cloudbees/jnlp-slave-with-java-build-tools   Extends cloudbees/java-build-tools docker im…   25                                      [OK]
zabbix/zabbix-java-gateway                   Zabbix Java Gateway                             16                                      [OK]
frekele/java                                 docker run --rm --name java frekele/java        13                                      [OK]
davidcaste/alpine-java-unlimited-jce         Oracle Java 8 (and 7) with GLIBC 2.21 over A…   11                                      [OK]
```

### 本地镜像管理
#### images
docker images : 列出本地镜像。


```
docker images [OPTIONS] [REPOSITORY[:TAG]]
```
OPTIONS:

* -a :列出本地所有的镜像（含中间映像层，默认情况下，过滤掉中间映像层）；
* --digests :显示镜像的摘要信息；
* -f :显示满足条件的镜像；
* --format :指定返回值的模板文件；
* --no-trunc :显示完整的镜像信息；
* -q :只显示镜像ID.

EXAMPLES:

```
//查看本地镜像列表
wuhua:blog wuhua$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
//列出本地镜像中REPOSITORY为ubuntu的镜像列表
wuhua:blog wuhua$ docker images  ubuntu
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
```

#### rmi
docker rmi : 删除本地一个或多少镜像。

```
docker rmi [OPTIONS] IMAGE [IMAGE...]
```

OPTIONS:

* -f :强制删除；
* --no-prune :不移除该镜像的过程镜像，默认移除；


EXAMPLES:

```
//强制删除本地镜像runoob/ubuntu:v4。
root@runoob:~# docker rmi -f runoob/ubuntu:v4
Untagged: runoob/ubuntu:v4
Deleted: sha256:1c06aa18edee44230f93a90a7d88139235de12cd4c089d41eed8419b503072be
Deleted: sha256:85feb446e89a28d58ee7d80ea5ce367eebb7cec70f0ec18aa4faa874cbd97c73
```

#### tag
docker tag : 标记本地镜像，将其归入某一仓库。

```
docker tag [OPTIONS] IMAGE[:TAG] [REGISTRYHOST/][USERNAME/]NAME[:TAG]
```

EXAMPLES:

```
//将镜像ubuntu:15.10标记为 runoob/ubuntu:v3 镜像
root@runoob:~# docker tag ubuntu:15.10 runoob/ubuntu:v3
root@runoob:~# docker images   runoob/ubuntu:v3
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
runoob/ubuntu       v3                  4e3b13c8a266        3 months ago        136.3 MB
```

#### build
docker build 命令用于使用 Dockerfile 创建镜像。

```
docker build [OPTIONS] PATH | URL | -
```

OPTIONS:

* --build-arg=[] :设置镜像创建时的变量；
* --cpu-shares :设置 cpu 使用权重；
* --cpu-period :限制 CPU CFS周期；
* --cpu-quota :限制 CPU CFS配额；
* --cpuset-cpus :指定使用的CPU id；
* --cpuset-mems :指定使用的内存 id；
* --disable-content-trust :忽略校验，默认开启；
* -f :指定要使用的Dockerfile路径；
* --force-rm :设置镜像过程中删除中间容器；
* --isolation :使用容器隔离技术；
* --label=[] :设置镜像使用的元数据；
* -m :设置内存最大值；
* --memory-swap :设置Swap的最大值为内存+swap，"-1"表示不限swap；
* --no-cache :创建镜像的过程不使用缓存；
* --pull :尝试去更新镜像的新版本；
* --quiet, -q :安静模式，成功后只输出镜像 ID；
* --rm :设置镜像成功后删除中间容器；
* --shm-size :设置/dev/shm的大小，默认值是64M；
* --ulimit :Ulimit配置。
* --tag, -t: 镜像的名字及标签，通常 name:tag 或者 name 格式；可以在一次构建中为一个镜像设置多个标签。
* --network: 默认 default。在构建期间设置RUN指令的网络模式


EXAMPLES:

```
//使用当前目录的 Dockerfile 创建镜像，标签为 runoob/ubuntu:v1
docker build -t runoob/ubuntu:v1 . 
//使用URL github.com/creack/docker-firefox 的 Dockerfile 创建镜像
docker build github.com/creack/docker-firefox
//通过 -f Dockerfile 文件的位置
 docker build -f /path/to/a/Dockerfile .
//在 Docker 守护进程执行 Dockerfile 中的指令前，首先会对 Dockerfile 进行语法检查，有语法错误时会返回
$ docker build -t test/myapp .
Sending build context to Docker daemon 2.048 kB
Error response from daemon: Unknown instruction: RUNCMD
```

#### history
docker history : 查看指定镜像的创建历史。

```
docker history [OPTIONS] IMAGE
```

OPTIONS:

* -H :以可读的格式打印镜像大小和日期，默认为true；
* --no-trunc :显示完整的提交记录；
* -q :仅列出提交记录ID。

EXAMPLES:

```
//查看本地镜像runoob/ubuntu:v3的创建历史
root@runoob:~# docker history runoob/ubuntu:v3
IMAGE             CREATED           CREATED BY                                      SIZE      COMMENT
4e3b13c8a266      3 months ago      /bin/sh -c #(nop) CMD ["/bin/bash"]             0 B                 
<missing>         3 months ago      /bin/sh -c sed -i 's/^#\s*\(deb.*universe\)$/   1.863 kB            
<missing>         3 months ago      /bin/sh -c set -xe   && echo '#!/bin/sh' > /u   701 B               
<missing>         3 months ago      /bin/sh -c #(nop) ADD file:43cb048516c6b80f22   136.3 MB
```

#### save
docker save : 将指定镜像保存成 tar 归档文件。

```
docker save [OPTIONS] IMAGE [IMAGE...]
```

OPTIONS:

* -o :输出到的文件。

EXAMPLES:

```
//将镜像runoob/ubuntu:v3 生成my_ubuntu_v3.tar文档
runoob@runoob:~$ docker save -o my_ubuntu_v3.tar runoob/ubuntu:v3
runoob@runoob:~$ ll my_ubuntu_v3.tar
-rw------- 1 runoob runoob 142102016 Jul 11 01:37 my_ubuntu_v3.ta
```

#### import
docker import : 从归档文件中创建镜像。

```
docker import [OPTIONS] file|URL|- [REPOSITORY[:TAG]]
```

OPTIONS:

* -c :应用docker 指令创建镜像；
* -m :提交时的说明文字；

EXAMPLES:

```
//从镜像归档文件my_ubuntu_v3.tar创建镜像，命名为runoob/ubuntu:v4
runoob@runoob:~$ docker import  my_ubuntu_v3.tar runoob/ubuntu:v4  
sha256:63ce4a6d6bc3fabb95dbd6c561404a309b7bdfc4e21c1d59fe9fe4299cbfea39
runoob@runoob:~$ docker images runoob/ubuntu:v4
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
runoob/ubuntu       v4                  63ce4a6d6bc3        20 seconds ago      142.1 MB
```

### info|version
#### info
docker info : 显示 Docker 系统信息，包括镜像和容器数。。

```
docker info [OPTIONS]
```

EXAMPLES:

```
wuhua:~ wuhua$ docker info
Containers: 0
 Running: 0
 Paused: 0
 Stopped: 0
Images: 0
Server Version: 18.09.2
Storage Driver: overlay2
 Backing Filesystem: extfs
 Supports d_type: true
 Native Overlay Diff: true
Logging Driver: json-file
Cgroup Driver: cgroupfs
Plugins:
 Volume: local
 Network: bridge host macvlan null overlay
 Log: awslogs fluentd gcplogs gelf journald json-file local logentries splunk syslog
Swarm: inactive
Runtimes: runc
Default Runtime: runc
Init Binary: docker-init
containerd version: 9754871865f7fe2f4e74d43e2fc7ccd237edcbce
runc version: 09c8266bf2fcf9519a651b04ae54c967b9ab86ec
init version: fec3683
Security Options:
 seccomp
  Profile: default
Kernel Version: 4.9.125-linuxkit
Operating System: Docker for Mac
OSType: linux
Architecture: x86_64
CPUs: 2
Total Memory: 1.952GiB
Name: linuxkit-025000000001
ID: VWVF:EJP2:5EGI:AWPX:KD3K:5ILZ:KTJ6:CXKL:UBGN:XY5N:ZQUT:YDMB
Docker Root Dir: /var/lib/docker
Debug Mode (client): false
Debug Mode (server): true
 File Descriptors: 24
 Goroutines: 50
 System Time: 2019-04-11T12:27:47.5699614Z
 EventsListeners: 2
HTTP Proxy: gateway.docker.internal:3128
HTTPS Proxy: gateway.docker.internal:3129
Registry: https://index.docker.io/v1/
Labels:
Experimental: false
Insecure Registries:
 127.0.0.0/8
Registry Mirrors:
 https://hqx51nri.mirror.aliyuncs.com/
Live Restore Enabled: false
Product License: Community Engine
```

#### version
docker version :显示 Docker 版本信息。

```
docker version [OPTIONS]
```


OPTIONS:

* -f :指定返回值的模板文件。

EXAMPLES:

```
wuhua:~ wuhua$ docker version
Client: Docker Engine - Community
 Version:           18.09.2
 API version:       1.39
 Go version:        go1.10.8
 Git commit:        6247962
 Built:             Sun Feb 10 04:12:39 2019
 OS/Arch:           darwin/amd64
 Experimental:      false

Server: Docker Engine - Community
 Engine:
  Version:          18.09.2
  API version:      1.39 (minimum version 1.12)
  Go version:       go1.10.6
  Git commit:       6247962
  Built:            Sun Feb 10 04:13:06 2019
  OS/Arch:          linux/amd64
  Experimental:     false
```