---
title: laravel标准框架
tags: [php,laravel]
comments: true
categories: [php]
date: 2018-07-25 17:56:15
---
### laravel标准框架的理解
详情：路由、中间件、异常处理、MVC、定时任务、配置信息，课堂实际项目开发接口和风格了解，目录结构，日志分析。

---

### MVC 
M：Model，模型，数据库操作具体对象。  
V：View，视图，渲染返回的页面。  
C：Controller，处理业务逻辑。  

### 定时任务

文档：[任务调度](https://laravel-china.org/docs/laravel/5.6/scheduling/1396)。

#### 如何使用

于app/Console/Kernel.php 文件的schedule方法中定义所有调度任务。

通过`$schedule->call()`设置，传递匿名函数，匿名函数中执行调度任务。

```
$schedule->call(function () {
	//todo
})->timefunction();
```

通过`$schedule->command()`设置，传递命令名称或者类名称调度一个` Artisan `命令。

```
$schedule->command('emails:send --force')->timefunction();

$schedule->command(EmailsCommand::class, ['--force'])->timefunction();
```
通过`$schedule->job()`调度队列任务。

```
$schedule->job(new Heartbeat)->timefunction();
```

通`$schedule->exec()`向操作系统发出命令。

```
$schedule->exec('node /home/forge/script.js')->timefunction();
```

>`timefunction()`指代调度频率的函数，包含较广，在文档上有详细的介绍。


使用`withoutOverlapping`方法避免任务重复。

使用` onOneServer `方法让计划任务只在一台服务器上运行(必须使用` memcached `或` redis `作为你应用程序的默认缓存驱动程序，所有服务器都必须与同一个中央缓存服务器进行通信。 原理是获取到该任务的第一台服务器将对该任务加上原子锁，以防止其他服务器同时运行相同的任务。

使用` evenInMaintenanceMode `方法强制某个任务在维护模式下运行。

> 使用` runInBackground `方法可使当前计划任务进入后台运行，从而不阻塞其他任务的执行。

#### 输出
使用` sendOutputTo `方法将输出发送到单个文件上以便后续检查，参数为文件名。

使用` appendOutputTo `方法将输出附加到指定的文件上。

使用` emailOutputTo `方法通过电子邮件将输出发送到指定的邮箱上，参数为指定邮箱地址。

#### 任务勾子
通过` before `与` after `方法，指定要在调度任务完成之前和之后执行的代码，参数为匿名函数，于匿名函数中书写逻辑。

#### Ping 网址
使用` pingBefore `与` thenPing `方法使调度器在任务完成之前或之后自动ping给定的URL，参数为给定URL。  

需要Guzzle HTTP函数库的支持。

`composer require guzzlehttp/guzzle`

### 日志
文档：[日志](https://laravel-china.org/docs/laravel/5.6/logging/1374)。

使用Log facade 记录信息到日志。日志处理程序提供了八种在[RFC 5424 specification](https://tools.ietf.org/html/rfc5424)里定义的日志等级：emergency、 alert、critical、 error、 warning、 notice、 info 和 debug。

```
Log::emergency($message);
Log::alert($message);
Log::critical($message);
Log::error($message);
Log::warning($message);
Log::notice($message);
Log::info($message);
Log::debug($message);
```

### 配置文件
文档： [配置信息](https://laravel-china.org/docs/laravel/5.6/configuration/1353)。

#### 检索环境配置：

```
'debug' => env('APP_DEBUG', false),
```

#### 确定/检查当前环境:

```
$environment = App::environment();

if (App::environment('local')) {
    // The environment is local
}

if (App::environment(['local', 'staging'])) {
    // The environment is either local OR staging...
}
```

#### 访问/设置配置值：

```
$value = config('app.timezone');
config(['app.timezone' => 'America/Chicago']);
```
#### 配置缓存：
>为提升速度，应该使用` Artisan `命令` config:cache `将所有的配置文件缓存到单个文件中。这会把你的应用程序中所有的配置选项合并成一个单一的文件，然后框架会快速加载这个文件。应该把运行` php artisan config:cache `命令作为生产环境部署常规工作的一部分。这个命令不应在本地开发环境下运行，因为配置选项在应用程序开发过程中是经常需要被更改的。

#### 维护模式:  

执行` Artisan `命令` down `启用维护模式。
当应用程序处于维护模式时，所有对应用程序的请求都显示为一个自定义视图。在更新或执行维护时「关闭」应用程序。 维护模式检查包含在应用程序的默认中间件栈中。如果应用程序处于维护模式，则将抛出一个状态码为 503 的 MaintenanceModeException 异常。

```
php artisan down
```

向`down`命令提供`message`和`retry`选项。其中`message`选项的值可用于显示或记录自定义消息，而`retry`值可用于设置`HTTP`请求头中`Retry-After`的值：

```
php artisan down --message="Upgrading Database" --retry=60
```
#### 关闭维护模式：

```
php artisan up
```
>可以通过修改 resources/views/errors/503.blade.php 模板文件来自定义默认维护模式模板。
当应用程序处于维护模式时，不会处理 队列任务。而这些任务会在应用程序退出维护模式后再继续处理。

### 中间件
文档：[中间件](https://laravel-china.org/docs/laravel/5.6/middleware/1364)。

用于过滤进入应用的 HTTP 请求。

可分为前置中间件、后置中间件，在请求之前或之后运行取决于中间件本身。

在 app/Http/Kernel.php 中的` $middleware `属性中列出的中间件为全局中间件。

使用 Http kernel 的` $middlewareGroups `属性，使用一个 key 把多个中间件打包成一个组，方便将他们应用到路由中。

在中间件中定义一个 terminate 方法，则会在响应发送到浏览器后自动调用。

### 异常处理
文档：[错误处理](https://laravel-china.org/docs/laravel/5.6/errors/1373)。

App\Exceptions\Handler 类负责记录应用程序触发的所有异常并呈现给用户。

config/app.php 配置文件中的 debug 选项决定了对于一个错误实际上将显示多少信息给用户。默认情况下，该选项的设置将遵照存储在 .env 文件中的 APP_DEBUG 环境变量的值。

>对于本地开发，你应该将 APP_DEBUG 环境变量的值设置为 true。在生产环境中，该值应始终为 false。如果在生产中将该值设置为 true，则可能会将敏感配置值暴露给应用程序的最终用户。

#### report方法
report 方法用于记录异常或将它们发送给如 Bugsnag 或 Sentry 等外部服务。默认情况下，report 方法将异常传递给记录异常的基类。

report 辅助函数允许你使用异常处理器的 report 方法在不显示错误页面的情况下快速报告异常。

异常处理器的` $dontReport `属性包含一组不会被记录的异常类型。例如，由 404 错误导致的异常以及其他几种类型的错误不会写入日志文件。

#### Render方法
Render 方法负责将给定的异常转换为将被发送回浏览器的 HTTP 响应。默认情况下，异常将传递给为你生成响应的基类。可以按自己意愿检查异常类型或返回自己的自定义响应。

#### Reportable & Renderable 异常
除了在异常处理器的` report `和` render `方法中检查异常类型，还可以直接在自定义异常上定义` report `和` render `方法。当定义了这些方法时，它们会被框架自动调用。

#### HTTP异常
使用` abort `辅助函数从应用程序的任何地方生成这样的响应。

##### 自定义 HTTP 错误页面
创建一个 resources/views/errors/404.blade.php 视图文件。该文件将被用于你的应用程序产生的所有 404 错误。此目录中的视图文件的命名应匹配它们对应的 HTTP 状态码。由` abort `函数引发的` HttpException `实例将作为` $exception `变量传递给视图。

### 路由
对应文档：[路由](https://laravel-china.org/docs/laravel/5.6/routing/1363)。
文档比较详细，虽然复制粘贴，感觉对记住其主要用法还是有些作用的。

#### 基本路由：
```
Route::get('foo', function () {
    return 'Hello World';
});

Route::get('/user', 'UserController@index');

Route::get($uri, $callback);
Route::post($uri, $callback);
Route::put($uri, $callback);
Route::patch($uri, $callback);
Route::delete($uri, $callback);
Route::options($uri, $callback);
```
#### 响应多个HTTP的路由或者响应所有HTTP路由：
```
Route::match(['get', 'post'], '/', function () {
    //
});

Route::any('foo', function () {
    //
});
```
#### 重定向路由：
```
Route::redirect('/here', '/there', 301);
```

#### 视图路由(可带参数)：
```
Route::view('/welcome', 'welcome');

Route::view('/welcome', 'welcome', ['name' => 'Taylor']);
```
#### 路由参数
##### 必填参数
```
Route::get('user/{id}', function ($id) {
    return 'User '.$id;
});

Route::get('posts/{post}/comments/{comment}', function ($postId, $commentId) {
    //
});
```
##### 可选参数(要确保路由的相应变量有默认值)
```
Route::get('user/{name?}', function ($name = null) {
    return $name;
});

Route::get('user/{name?}', function ($name = 'John') {
    return $name;
});
```
##### 正则表达式约束
```
Route::get('user/{name}', function ($name) {
    //
})->where('name', '[A-Za-z]+');

Route::get('user/{id}', function ($id) {
    //
})->where('id', '[0-9]+');

Route::get('user/{id}/{name}', function ($id, $name) {
    //
})->where(['id' => '[0-9]+', 'name' => '[a-z]+']);
```
##### 全局约束
使用 pattern 方法在 RouteServiceProvider 的 boot 方法中定义这些模式：

```
public function boot()
{
    Route::pattern('id', '[0-9]+');

    parent::boot();
}
```

#### 路由命名
```
Route::get('user/profile', function () {
    //
})->name('profile');
Route::get('user/profile', 'UserController@showProfile')->name('profile');
```

##### 生成指定路由的 URL
```
// 生成 URL...
$url = route('profile');

// 生成重定向...
return redirect()->route('profile');


Route::get('user/{id}/profile', function ($id) {
    //
})->name('profile');

$url = route('profile', ['id' => 1]);
```
#### 检查当前路由
调用路由实例上的 named 方法。

```
public function handle($request, Closure $next)
{
    if ($request->route()->named('profile')) {
        //
    }

    return $next($request);
}
```

#### 路由组
使大量路由间共享路由属性：中间件、命名空间。共享属性应该以数组的形式传入` Route::group `方法的第一个参数中。	

##### 中间件
给路由组中所有的路由分配中间件，在group之前调用middleware方法，中间件会依照它们在数组中列出的顺序来运行：

```
Route::middleware(['first', 'second'])->group(function () {
    Route::get('/', function () {
        // 使用 first 和 second 中间件
    });

    Route::get('user/profile', function () {
        // 使用 first 和 second 中间件
    });
});
```

##### 命名空间
使用 namespace 方法将相同的 PHP 命名空间分配给路由组的中所有的控制器：

```
Route::namespace('Admin')->group(function () {
    // 在 "App\Http\Controllers\Admin" 命名空间下的控制器
});
```
默认情况下，` RouteServiceProvider `会在命名空间组中引入路由文件，不用指定完整的 ` App\Http\Controllers `命名空间前缀就能注册控制器路由。因此，只需要指定命名空间` App\Http\Controllers `之后的部分。

##### 子域名路由
路由组也可以用来处理子域名。子域名可以像路由` URI `一样被分配路由参数，允许你获取一部分子域名作为参数给路由或控制器使用。可以在` group `之前调用` domain `方法来指定子域名：

```
Route::domain('{account}.myapp.com')->group(function () {
    Route::get('user/{id}', function ($account, $id) {
        //
    });
});
```
##### 路由前缀
用` prefix `方法为路由组中给定的URL增加前缀.

```
Route::prefix('admin')->group(function () {
    Route::get('users', function () {
        // 匹配包含 "/admin/users" 的 URL
    });
});
```
##### 路由名称前缀
name 方法可以用来给路由组中的每个路由名称添加一个给定的字符串。 例如，您可能希望以 「admin」为所有分组路由的名称加前缀。 给定的字符串与指定的路由名称前缀完全相同，因此我们将确保在前缀中提供尾部的` . `字符：

```
Route::name('admin.')->group(function () {
    Route::get('users', function () {
        // 路由分配名称“admin.users”...
    })->name('users');
});
```
##### 路由模型绑定
当向路由或控制器行为注入模型 ID 时，就需要查询这个 ID 对应的模型。Laravel 为路由模型绑定提供了一个直接自动将模型实例注入到路由中的方法。例如，你可以注入与给定 ID 匹配的整个 User 模型实例，而不是注入用户的 ID。

#### 路由模型绑定
当向路由或控制器行为注入模型 ID 时，就需要查询这个 ID 对应的模型。Laravel 为路由模型绑定提供了一个直接自动将模型实例注入到路由中的方法。例如，你可以注入与给定 ID 匹配的整个 User 模型实例，而不是注入用户的 ID。
##### 隐式绑定
Laravel 会自动解析定义在路由或控制器行为中与类型提示的变量名匹配的路由段名称的 Eloquent 模型。例如：

```
Route::get('api/users/{user}', function (App\User $user) {
    return $user->email;
});
```
>自定义键名.
如果你想要模型绑定在检索给定的模型类时使用除 id 之外的数据库字段，你可以在 Eloquent 模型上重写 getRouteKeyName 方法：

```
 * 为路由模型获取键名。
 *
 * @return string
 */
public function getRouteKeyName()
{
    return 'slug';
}
```
##### 显示绑定
要注册显式绑定，使用路由器的 model 方法来为给定参数指定类。在 RouteServiceProvider 类中的 boot 方法内定义这些显式模型绑定：

```
public function boot()
{
    parent::boot();

    Route::model('user', App\User::class);
}
```
接着，定义一个包含 {user} 参数的路由:

```
Route::get('profile/{user}', function (App\User $user) {
    //
});
```
>自定义逻辑解析.  
使用` Route::bind `方法自定义的解析逻辑。传递到` bind `方法的闭包会接受` URI `中大括号对应的值，并且返回想要在该路由中注入的类的实例：

```
public function boot()
{
    parent::boot();

    Route::bind('user', function ($value) {
        return App\User::where('name', $value)->first() ?? abort(404);
    });
}
```
#### 访问控制
Laravel 包含了一个 中间件 用于控制应用程序对路由的访问。如果想要使用，请将 throttle 中间件分配给一个路由或一个路由组。throttle 中间件会接收两个参数，这两个参数决定了在给定的分钟数内可以进行的最大请求数。 例如，让我们指定一个经过身份验证并且用户每分钟访问频率不超过 60 次的路由：

```
Route::middleware('auth:api', 'throttle:60,1')->group(function () {
    Route::get('/user', function () {
        //
    });
});
```
##### 动态访问控制
根据已验证的 User 模型的属性指定动态请求的最大值。 例如，如果您的 User 模型包含rate_limit属性，则可以将属性名称传递给 throttle 中间件，以便它用于计算最大请求计数：

```
Route::middleware('auth:api', 'throttle:rate_limit,1')->group(function () {
    Route::get('/user', function () {
        //
    });
});
```
#### 表单方法伪造
HTML表单不支持PUT、PATCH或DELETE行为。所以当你要从HTML表单中调用定义了PUT、PATCH或DELETE路由时，你将需要在表单中增加隐藏的_method 输入标签。使用_method字段的值作为HTTP的请求方法：

```
<form action="/foo/bar" method="POST">
    <input type="hidden" name="_method" value="PUT">
    <input type="hidden" name="_token" value="{{ csrf_token() }}">
</form>

<form action="/foo/bar" method="POST">
    @method('PUT')
    @csrf
</form>
```
#### 访问当前路由
可以使用`Route Facade`上的` current `、` currentRouteName `和` currentRouteAction `方法来访问处理传入请求的路由的信息：

```
$route = Route::current();

$name = Route::currentRouteName();

$action = Route::currentRouteAction();
```