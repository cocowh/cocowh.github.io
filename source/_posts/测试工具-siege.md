---
title: 测试工具-siege
tags: [测试,siege]
comments: true
categories: [web杂记]
date: 2018-08-03 20:42:20
---
### 安装
mac下使用brew直接安装

```
brew install siege
```

`siege -C`查看相关的配置参数，可以自行修改，比如是否显示log，超时时间。

```
localhost:~ wuhua$ siege -C
CURRENT  SIEGE  CONFIGURATION
Mozilla/5.0 (apple-x86_64-darwin17.0.0) Siege/4.0.4
Edit the resource file to change the settings.
----------------------------------------------
version:                        4.0.4
verbose:                        true
color:                          true
quiet:                          false
debug:                          false
protocol:                       HTTP/1.1
HTML parser:                    enabled
get method:                     HEAD
connection:                     close
concurrent users:               25
time to run:                    n/a
repetitions:                    n/a
socket timeout:                 30
cache enabled:                  false
accept-encoding:                gzip, deflate
delay:                          0.000 sec
internet simulation:            false
benchmark mode:                 false
failures until abort:           1024
named URL:                      none
URLs file:                      /usr/local/Cellar/siege/4.0.4/etc/urls.txt
thread limit:                   10000
logging:                        false
log file:                       /Users/wuhua/var/siege.log
resource file:                  /Users/wuhua/.siege/siege.conf
timestamped output:             false
comma separated output:         false
allow redirects:                true
allow zero byte data:           true
allow chunked encoding:         true
upload unique files:            true
no-follow:
 - ad.doubleclick.net
 - pagead2.googlesyndication.com
 - ads.pubsqrd.com
 - ib.adnxs.com
```

项目：[siege](https://github.com/JoeDog/siege)

参考：[siege压力测试工具安装和介绍](https://blog.csdn.net/shangmingtao/article/details/73850292#1siege%E4%BB%8B%E7%BB%8D)，[如何使用siege测试服务器性能](https://www.cnblogs.com/lawlietfans/p/6873306.html)


### 输入参数
可在命令行中输入siege –help获取。

输入参数名 | 解释说明
:- | :-
-V,–version | 打印版本号
-h,–help | 打印帮助信息（输出这些命令参数及详情）
-C,–config | 显示当前配置信息
-v,–verbose | 将通知信息输出到屏幕
-q,–quiet | 停止verbose并抑制输出
-g,–get | 显示请求URL的HTTP头和返回详情，适用于调试
-p,–print | 打印，类似GET一样，打印整个页面（response html）
-c,–concurrent=NUM | 设置并发用户数，默认为10
-r,-–reps=NUM | 设置测试次数
-t,–time=NUMm | 设置测试时间，m修饰秒（S）、分（M）、时（H），例如–time=1H
-d,-–delay=NUM | 时间延迟，每次请求之前的延迟随机
-b,–benchmark | 基准测试，请求之间没有延迟
-i,–internet | 用户模拟、随机访问url
-f,-–file=FILE | 选择特定的URLS文件（读取文件选取其中的url进行访问）
-R,–rc=FILE | 指定一个siegerc文件
-l,–log[=FILE] | 记录测试日志到文件，如果未指定FILE，则使用默认值：PREFIX/var/siege.log
-m,-–mark=”text” | 标记，用字符串标记测试日志，介于.001和NUM之间。（未计入统计数据）
-H,-–header=”text” | 添加测试的请求头header，可以为多个
-A, –user-agent=”text” | 在请求中设置User-Agent
-T, –content-type=”text” | 在请求中设置Content-Type
–no-parser | 没有PARSER，关闭HTML页面解析器
–no-follow | 不遵循，不要遵循HTTP重定向

### 输出参数

输出参数名 | 解释说明
:-: | :- 
Transactions | 总共测试次数
Availability | 成功次数百分比
Elapsed time | 总共耗时多少秒
Data transferred | 总共数据传输
Response time | 平均响应时间
Transaction rate | 平均每秒处理请求数
Throughput | 吞吐率
Concurrency | 最高并发
Successful transactions | 成功的请求数
Failed transactions | 失败的请求数
Longest transaction | 最长响应时间
Shortest transaction | 最短响应时间

### 使用
示例：
  
 类别 | 数据
 :- | :- 
 请求登陆接口 | http://bighua.com/login
 请求类型 | POST
 请求参数 | {"_token": "qeXesWXLPl6BnNhPWvc44NeaCyY75ahpqA42ErT5","email": "228944883 @qq.com","password": "hualin123","remember": "on"}
 请求次数 | 10次
 请求并发数量 | 150

请求：

```
siege "http://bighua.com/login POST {"_token":"qeXesWXLPl6BnNhPWvc44NeaCyY75ahpqA42ErT5","email":"228944883@qq.com","password":"hualin123","remember":"on"}" -r 10 -c 150
```
测试结果：

```
Transactions:		        1490 hits
Availability:		       99.33 %
Elapsed time:		       41.63 secs
Data transferred:	        2.16 MB
Response time:		        3.04 secs
Transaction rate:	       35.79 trans/sec
Throughput:		        0.05 MB/sec
Concurrency:		      108.82
Successful transactions:           0
Failed transactions:	          10
Longest transaction:	       35.63
Shortest transaction:	        0.00
```

### 后记
siege默认的线程数为255，与apache的默认值相对应，nginx的默认最大连接数为1024。不修改isege配置文件的话，-c的最大值只能为255。 只能测试并发量在255以下。

另外操作系统对打开文件的多少有限制，即限制socket打开的数量。可通过ulimit命令进行修改。参看博客：[Mac打开文件最大数限制修改](https://blog.csdn.net/z1134145881/article/details/52573441/)、[mac中修改系统限制量–ulimit和sysctl](https://blog.csdn.net/whereismatrix/article/details/50582919)。

对nginx设置参考[单机 nginx 应对高并发处理](https://blog.csdn.net/hjh15827475896/article/details/53442800)。

