---
title: pomelo起步
tags: [pomelo,note,nodejs]
comments: true
categories: [pomelo]
date: 2020-02-02 11:23:43
---

### 环境搭建

参考[安装pomelo](https://github.com/NetEase/pomelo/wiki/%E5%AE%89%E8%A3%85pomelo)

按部就班，注意相关版本号，没啥问题

### 运行demo

参考[pomelo的HelloWorld](https://github.com/NetEase/pomelo/wiki/pomelo%E7%9A%84HelloWorld)

按部就班，文档更新有点过时。

#### 服务端

按部就班，根据输出日志可了解大概启动流程。

#### 客户端

运行客户端提示了一些语法问题：

```
wuhua:web-server wuhua$ node app 
Warning: express.createServer() is deprecated, express
applications no longer inherit from http.Server,
please use:

  var express = require("express");
  var app = express();

connect.multipart() will be removed in connect 3.0
visit https://github.com/senchalabs/connect/wiki/Connect-3.0 for alternatives
connect.limit() will be removed in connect 3.0
Web server has started.
Please log on http://127.0.0.1:3001/index.html
(node:68041) [DEP0066] DeprecationWarning: OutgoingMessage.prototype._headers is deprecated
```

根据提示修正找到文件web-server/app.js：

```
var express = require('express');
var app = express.createServer();

==>

var express = require('express');
var app = express();
```
再运行无语法提示。

此依赖的还是express 3.4.8版本，比较旧。

### pomelo命令
参考[Pomelo命令行工具使用](https://github.com/NetEase/pomelo/wiki/pomelo%E5%91%BD%E4%BB%A4%E8%A1%8C%E5%B7%A5%E5%85%B7%E4%BD%BF%E7%94%A8)

```
wuhua:web-server wuhua$ which pomelo
/usr/local/bin/pomelo
wuhua:web-server wuhua$ pomelo --help

  Usage: pomelo [options] [command]

  Commands:

    init [path]            create a new application
    start [options]        start the application
    list [options]         list the servers
    add [options]          add a new server
    stop [options]         stop the servers, for multiple servers, use `pomelo stop server-id-1 server-id-2`
    kill [options]         kill the application
    restart [options]      restart the servers, for multiple servers, use `pomelo restart server-id-1 server-id-2`
    masterha [options]     start all the slaves of the master
    *                     

  Options:

    -h, --help     output usage information
    -V, --version  output the version number
    
wuhua:web-server wuhua$ pomelo -V
2.2.7
wuhua:web-server wuhua$ pomelo list
try to connect 127.0.0.1:3005
serverId           serverType pid   rss(M) heapTotal(M) heapUsed(M) uptime(m) 
connector-server-1 connector  68757 25.46  15.69        14.04       26.30     
master-server-1    master     68756 23.34  13.56        12.07       26.31    
```

#### 小记
`pomelo start`可追加可选参数：

```
pomelo start [-e,--env <env>] [-d,--directory <code directory>]
             [-D,--daemon]
```

可在<project_dir>/game-server/config/servers.json中为不同的服务器中添加不同参数(node和v8支持的参数)，用来指定和影响node及v8的行为的。例如，当我们想对某一个服务器开启调试的时候，就可以在服务器配置中，增加args配置项，并在args中配置开启调试的端口:

```
{"connector":[{"id":"connector-server-1", "host":"127.0.0.1", "port":4050, 
"clientPort":3050, "args":"--debug=[port]"}]}
```

practice example：

```code change
  "development":{
    "connector": [
    {"id": "connector-server-1", "host": "127.0.0.1", "port": 3150, "clientHost": "127.0.0.1", "clientPort": 3010, "args":"--debug=[port]", "frontend": true}
    ]
  },
```

run cli:

```
wuhua:HelloWorld wuhua$ pwd
/Users/wuhua/Desktop/pomelo/HelloWorld
wuhua:HelloWorld wuhua$ pomelo start -d ./game-server -e development  -D
The application is running in the background now.

wuhua:HelloWorld wuhua$ pomelo list -h 127.0.0.1 -P 3005 -u admin -p admin
try to connect 127.0.0.1:3005
serverId        serverType pid   rss(M) heapTotal(M) heapUsed(M) uptime(m) 
master-server-1 master     70166 38.36  14.06        11.49       0.25
```






