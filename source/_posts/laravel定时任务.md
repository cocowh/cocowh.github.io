---
title: laravel定时任务
tags: [php,linux,laravel]
comments: true
categories: [php]
date: 2018-07-26 19:05:44
---
### mac下laravel定时任务
#### 添加Cron条目到mac（服务器）
文档：[crontab](http://www.runoob.com/linux/linux-comm-crontab.html)。

```
crontab服务的重启关闭，开启
sudo /usr/sbin/cron start
sudo /usr/sbin/cron restart
sudo /usr/sbin/cron stop
```
将php artisan schedule:run 添加到crontab：

```
crontab -e
```
添加：

```
* * * * * /usr/bin/php /Users/wuhua/Desktop/TAL-practice/login/artisan schedule:run >> /dev/null 2>&1
```
`* * * * *`分别代表每小时中第几分钟、每天中第几小时、每月中第几日、每年中第几月、每周中第几天。`/usr/bin/php`为php执行路径（cli）。`/Users/wuhua/Desktop/TAL-practice/login/artisan schedule:run`为项目`artisan`路径，要执行的命令。`>> /dev/null`表示将标准输出重定向到`/dev/null`（空设备文件）中（丢弃标准输出），` 2>&1 `将错误输出和标准输出绑定在一起，使用同一个文件描述符。

查看设置的定时任务：

```
crontab -l
* * * * * /usr/bin/php /Users/wuhua/Desktop/TAL-practice/login/artisan schedule:run >> /dev/null 2>&1
```
#### 任务调度书写
```
protected function schedule(Schedule $schedule)
{
	$schedule->call(function () {
            $addUserInfoIntoredis = new UserInfoController();
           $addUserInfoIntoredis->addUsersInfo();
        })->everyMinute();
}
```
在UserInfoController的addUsersInfo方法中取数据库今日注册新用户添加到redis中。其中的逻辑省略。
### 调用钉钉接口发送新用户注册通知
Guzzle文档：[Guzzle中文文档](http://guzzle-cn.readthedocs.io/zh_CN/latest/index.html)。

自定义钉钉机器人：[自定义机器人](https://open-doc.dingtalk.com/docs/doc.htm?spm=a219a.7629140.0.0.vcNk2y&treeId=257&articleId=105735&docType=1)。

坑点：文档中对各种请求方式的参数未做详细说明，钉钉机器人需要以post请求发送json格式的数据，Guzzle发送请求中的第三项参数（数组）为要发送的数据，键名代表着要发送的数据的格式，键值（真正发送的数据）为发送的数据。
代码：

```
$client = new Client([
            'base_uri' => 'https://oapi.dingtalk.com/robot/send?access_token=62cad18354083b35ebf8ebcdc9dd164bb25cf9f0a96e9737f191e8a69c637924'
        ]);
$data = [
       'json' => [
       'msgtype' => 'text',
       'text' => [
              'content' => '新注册用户：'.$req->get('name').'；邮箱：'.$req->get('email').'。',
                ]
       ]
];
$client->request('POST','',$data);
```
数据的json代表着以json格式发送数据。
### 对发消息进行解偶
消息发送机制应该做成独立的模块，考虑使用事件和队列。
#### 事件
文档：[事件系统](https://laravel-china.org/docs/laravel/5.6/events/1389)。

于EventServiceProvider的listen数组中添加：

```
'App\Events\RegisterMsg' =>[
     'App\Listeners\SendRegisterMsgToRobot',
]
```

生成事件和监听器：

```
php artisan event:generate
```
于事件的构造函数中接收事件的数据：

```
 * @var 
 */
public $info;
/**
 * Create a new event instance.
 *
 * @return void
 */
public function __construct($info)
{
    $this->info = $info;
}
```
于监听器SendRegisterMsgToRobot的handle函数中书写业务逻辑。

```
$info = $event->info;
$client = new Client([
      'base_uri' => 'https://oapi.dingtalk.com/robot/send?access_token=62cad18354083b35ebf8ebcdc9dd164bb25cf9f0a96e9737f191e8a69c637924'
]);
$data = [
     	'json' => [
        		'msgtype' => 'text',
        		'text' => [
                	'content' => 'Message from EventListener。新注册用户：'.$info['name'].'；邮箱：'.$info['email'].'。',
               ]
         ]
];
$client->request('POST','',$data);
```
使用enent函数触发事件：

```
event(new RegisterMsg($info));
```
#### 队列
事件的处理过程可能会引起用户等待。加入队列中进行处理更适合场景。

文档：[队列](https://laravel-china.org/docs/laravel/5.6/queues/1395#260f10)。

生成任务：

```
php artisan make:job SendRegisterMsg
```
于SendRegisterMsg的handle函数中书写业务逻辑：

```
public function handle()
{
    $info = $this->info;
    $client = new Client([
        'base_uri' => 'https://oapi.dingtalk.com/robot/send?access_token=62cad18354083b35ebf8ebcdc9dd164bb25cf9f0a96e9737f191e8a69c637924'
    ]);
    $data = [
        'json' => [
            'msgtype' => 'text',
            'text' => [
                'content' => 'Message from job。新注册用户：'.$info['name'].'；邮箱：'.$info['email'].'。',
            ]
        ]
    ];
    $client->request('POST','',$data);
}
```
分发任务：

```
SendRegisterMsg::dispatch($info)
```
#### 代码组织及结构调整
一个大型项目往往是慢慢集成的，添加的每一个模块应该在一个独立的子目录中，与原项目间互不影响。将所有代码文件添加父目录Login。

反思此消息发送，功能太单一，仅为text消息发送，而钉钉接口支持多种消息类型。若需要发送markdown、link、ActionCard、FeedCard等类型消息，这样写的复用率很低，因考虑进行功能的封装。其次，应该将配置相关的文件单独存放，便于管理配置。