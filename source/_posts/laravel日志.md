---
title: laravel日志
tags: [php,laravel]
comments: true
categories: [php]
date: 2018-07-27 19:16:30
---
### 日志
文档：[日志](https://laravel-china.org/docs/laravel/5.6/logging/1374)。

理解
>laravel框架使用monolog记录日志，在配置文件的channels中，可自定义通道，默认选用stack通道。通道即记录日志时选择记录的方式，通道有八种可选驱动，驱动决定了日志记录的位置、信息格式等，可参考配置文件中的其他通道配置自己业务所需的通道进行日志记录。  

>提供了八种在[RFC 5424 specification](https://tools.ietf.org/html/rfc5424)中定义的日志等级。在记录时，根据调用方法对应的等级对比选用通道中规定的最低等级，使用最低等级不高于调用方法对应等级的通道记录信息。

### 中间件记录sql
文档：[监听查询事件](https://laravel-china.org/docs/laravel/5.6/database/1397#97d96c)。
>在上方的文档中，larvel5.6提供的监听查询事件与之前版本的监听查询事件匿名函数的参数有不同，是个坑点。v5.6为一个参数带有sql、bindings、time属性，之前版本将这三个属性作为参数。

sql查询事件可能发生在任何请求中，应将其作为全局中间件进行注册。事件监听应在用户请求开始就启动，使用前置中间件。

在log配置文件中定义sql通道，选用daily驱动将日志按日期进行分割。

```
'sql' => [
    'driver' => 'daily',
    'path' => storage_path('logs/sql/sql.log'),
    'level' => 'info',
    'days' => 7,
],
```
中间件中逻辑：

```
public function handle($request, Closure $next)
{
    // 记录sql
    DB::listen(function($query) {
        $sql = $query->sql;
        $bindings = $query->bindings;
        foreach ($bindings as $replace) {
            $value = is_numeric($replace) ? $replace : "'" . $replace . "'";
            $sql = preg_replace('/\?/', $value, $sql, 1);
            Log::channel('sql')->info('SQL语句执行：'.$sql.',耗时：'.$query->time.'ms');
        }
    });
    return $next($request);
}
```
### 中间件记录IO
实际记录请求和响应。

request和response所包含的API文档：[Laravel API](https://laravel.com/api/5.6/index.html)。

对于请求考虑记录请求url、客户端ip、请求方法、请求参数，对于响应记录响应状态码、返回字节数。

新建通道io:

```
'io' => [
            'driver' => 'daily',
            'path' => storage_path('logs/io/io.log'),
            'level' => 'info',
            'days' => 7,
        ],
```
中间件中调用Log记录，注意请求响记录的时期：

```
public function handle($request, Closure $next)
{
    $data['request']['url'] = $request->fullUrl();
    $data['request']['ip'] = $request->getClientIp();
    $data['request']['method'] = $request->method();
    $data['request']['data'] = $request->all();
    $response = $next($request);
    $data['response']['status'] = $response->status();
    $data['response']['contentLen'] = strlen($response->content());
    Log::channel('io')->info(serialize($data));
    return $response;
}
```
### 记录异常
在App\Exceptions\Handler的report 方法中记录异常到日志。可在render方法中将异常消息作为response响应返回。

report function example

```
public function report(Exception $exception)
   {
       $data =  $exception->getMessage().PHP_EOL;
       $data .= 'file:'.$exception->getFile();
       $data .= '(line'.$exception->getLine().')'.PHP_EOL;
       $data .= $exception->getTraceAsString();
       Log::channel('myLog')->error($data);
       parent::report($exception);
   }
```
render function example

```
public function render($request, Exception $e)
  {
      if ($e instanceof ModelNotFoundException) {
          $e = new NotFoundHttpException($e->getMessage(), $e);
      }

      if ($e instanceof ExceptionBiz) {
          $result = [
              'errcode'   => $e->getCode(),
              'errmsg'    => $e->getMessage(),
              'data'      => [],
          ];
          if (!empty($e->getExtInfo())) {
              $result['data'] = $e->getExtInfo();
          }
          return response()->json($result);
      }
      return parent::render($request, $e);
  }
```