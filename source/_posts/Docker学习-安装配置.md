---
title: Docker学习-安装配置
tags: [Docker,mac]
comments: true
categories: [Docker]
date: 2019-04-06 15:50:07
---
mac环境桌面版

下载

```
wuhua:src wuhua$ brew search docker
==> Formulae
docker                                   docker-machine-completion
docker-clean                             docker-machine-driver-hyperkit
docker-cloud                             docker-machine-driver-vultr
docker-completion                        docker-machine-driver-xhyve
docker-compose                           docker-machine-nfs
docker-compose-completion                docker-machine-parallels
docker-credential-helper                 docker-squash
docker-credential-helper-ecr             docker-swarm
docker-gen                               docker2aci
docker-ls                                dockerize
docker-machine

==> Casks
docker                                   homebrew/cask-versions/docker-edge
docker-toolbox
wuhua:src wuhua$ brew cask install docker
Updating Homebrew...
==> Satisfying dependencies
==> Downloading https://download.docker.com/mac/stable/31259/Docker.dmg
######################################################################## 100.0%
==> Verifying SHA-256 checksum for Cask 'docker'.
==> Installing Cask docker
==> Moving App 'Docker.app' to '/Applications/Docker.app'.
🍺  docker was successfully installed!
```

点`访达`边的`启动台` 可看到下载好的桌面版docker，点击启动按步骤操作输入密码授权

配置后启动查看信息

```
wuhua:src wuhua$ docker info
Error response from daemon: Bad response from Docker engine
wuhua:src wuhua$ docker info
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
 Goroutines: 51
 System Time: 2019-04-06T07:47:49.465200315Z
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
第一次`docker info`查询失败是因为未启动完毕。

关于docker命令参考[Docker 命令大全](http://www.runoob.com/docker/docker-command-manual.html)

关于设置docker国内镜像参考[Docker国内镜像](https://www.cnblogs.com/anliven/p/6218741.html)

关于其他系统Doker安装参考[MacOS Docker 安装](http://www.runoob.com/docker/macos-docker-install.html)

关于`brew`和`brew cask`参考[mac brew和brew cask的区别](https://blog.csdn.net/yanxiaobo1991/article/details/78455908)