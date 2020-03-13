---
title: async/await的前世今生
tags: [ECMAScript,async,promise]
comments: true
categories: [node]
date: 2020-03-12 14:35:36
---

### 异步背景
JS设计之初服务于浏览器GUI编程语言，保证界面流畅，UI线程不能阻塞，采用异步非阻塞编程模式。

> 执行一个指令不会马上返回结果而执行下一个任务，基于事件机制，实际处理这个调用的部件在完成后，通过状态、通知和回调来通知调用者。

一般处理异步操作，流程间有结果依赖关系，需要依靠上一执行结果开始下一执行操作。

node.js中的异步操作：

- I/O
	- 网络I/O
	- 文件I/O
	- DNS操作
- 非I/O
	-  定时器（setTimeout，setInterval）
	-  microtask（promise）
	-  process.nextTick
	-  setImmedlate
	-  DNS.lookup


### 历史

#### 回调

```
step1(function (value1) {
    step2(value1, function(value2) {
        step3(value2, function(value3) {
            step4(value3, function(value4) {
                // Do something with value4
            });
        });
    });
});
```
example:

* pomelo启动多层嵌套回调

```
Application.start = function(cb) {
  this.startTime = Date.now();
  if(this.state > STATE_INITED) {
    utils.invokeCallback(cb, new Error('application has already start.'));
    return;
  }
  
  var self = this;
  appUtil.startByType(self, function() {
    appUtil.loadDefaultComponents(self);
    var startUp = function() {
      appUtil.optComponents(self.loaded, Constants.RESERVED.START, function(err) {
        self.state = STATE_START;
        if(err) {
          utils.invokeCallback(cb, err);
        } else {
          logger.info('%j enter after start...', self.getServerId());
          self.afterStart(cb);
        }
      });
    };
    var beforeFun = self.lifecycleCbs[Constants.LIFECYCLE.BEFORE_STARTUP];
    if(!!beforeFun) {
      beforeFun.call(null, self, startUp);
    } else {
      startUp();
    }
  });
};
```

#### Promise

> 是一个对象，从它可以获取异步操作的消息。异步操作有三种状态：Pending（进行中）、Resolved（已成功）和 Rejected（已失败）。除了异步操作的结果，任何其他操作都无法改变这个状态。Promise 对象只有：从 Pending 变为 Resolved 和从 Pending 变为 Rejected 的状态改变。只要处于 Resolved 和 Rejected ，状态就不会再改变。

code example：

多个依赖任务

```
let p1 = function(params) {
  return new Promise((resolve, reject) => {
    console.log('p1 task add ' + params);
    return resolve(params + 500);
  });
};

let p2 = function(params) {
  return new Promise((resolve, reject) => {
    console.log('p2 task add ' + params);
    return resolve(params + 500);
  });
};

let p3 = function(params) {
  return new Promise((resolve, reject) => {
    console.log('p3 task add ' + params);
    return resolve(params + 500);
  });
};

let p = p3(500);
console.log(' p ' + p);

p.then((result) => {
  console.log('p3 result ' + result);
  return p2(result);
}).then((result) => {
  console.log('p2 result ' + result);
  return p1(result);
}).then((result) => {
  return console.log('p1 result ' + result);
}).catch((error) => {
  console.log(' catch ' + error);
});
```

exec result:

```
wuhua:nodetest wuhua$ node testGeneratorAndPromise.js 
p3 task add 500
 p [object Promise]
p3 result 1000
p2 task add 1000
p2 result 1500
p1 task add 1500
p1 result 2000
```

回调写法：

```
let c1 = (params, cb) => {
  setTimeout(() => {
    console.log('c1 task do something with ' + params);
    params+=500;
    return cb(params);
  }, 500);
};
let c2 = (params, cb) => {
  setTimeout(() => {
    console.log('c1 task do something with ' + params);
    params+=500;
    return cb(params);
  }, 500);
};
let c3 = (params, cb) => {
  setTimeout(() => {
    console.log('c1 task do something with ' + params);
    params+=500;
    return cb(params);
  }, 500);
};
c1(500, (resultc1) => {
  c2(resultc1, (resultc2) => {
    c3(resultc2, (resultc3)=> {
      console.log('finally result ' + resultc3);
    });
  });
});
```
exec result:

```
wuhua:nodetest wuhua$ node testGeneratorAndPromise.js 
c1 task do something with 500
c1 task do something with 1000
c1 task do something with 1500
finally result 2000
```

当处理复杂逻辑时，回调嵌套逻辑深，promise流程长。

#### Generator函数

> 是一个状态机，封装了多个内部状态，还是一个遍历器对象生成函数。  
> 执行Generator函数会返回一个遍历器对象，依次遍历Generator函数内部的每一个状态。  
> Generator函数是一个普通函数，但是有两个特征。一是，function关键字与函数名之间有一个星号；二是，函数体内部使用yield语句，定义不同的内部状态）

##### generator、thunkify处理异步

Thunk函数：[参考](https://www.w3cschool.cn/ecmascript/vis51q5w.html)

```
const thunkify = require('thunkify');
function statusAsyncFun(params, cb) {
  setTimeout(() => {
    return cb(params);
  }, 1000);
}

let statusThunk = thunkify(statusAsyncFun);

function* testGeneratorThunk() {
  let ret1 = yield statusThunk('status1');
  console.log(ret1);
  let ret2 = yield statusThunk('status2');
  console.log(ret2);
  return 'finally result';
}

function runThunkGen(fn) {
  var gen = fn();
  function next(data) {
    var result = gen.next(data);
    if (result.done) return;
    result.value(next);
  }
  next();
}
runThunkGen(testGeneratorThunk);
```
exec result:

```
wuhua:nodetest wuhua$ node testGeneratorAndPromise.js 
status1
status2
```

##### generator、co处理promise

co模块：[git](https://github.com/tj/co)

```
const co = require('co');

function statusPromiseFun(params) {
  return new Promise((resolve) => {
    setTimeout(() => {
      return resolve(params);
    },500);
  });
}

function* testGeneratorCo() {
  let ret1 = yield statusPromiseFun('status1');
  console.log('console in gen ' + ret1);
  let ret2 = yield statusPromiseFun('status2');
  console.log('console in gen ' + ret2);
  return ' finally result ';
}

co(testGeneratorCo).then((result) => {
  console.log('co promise result' + result);
}).catch((error) => {
  console.log(error);
});
```

exec result:

```
wuhua:nodetest wuhua$ node testGeneratorAndPromise.js 
console in gen status1
status1
console in gen status2
co promise result finally result 
status2
```

#### async/await

async/await: [参考](https://www.w3cschool.cn/ecmascript/vis51q5w.html#async%E5%87%BD%E6%95%B0)

验证：

```
'use strict';

class TestAsync{

  fun1() {
    return 'fun1';
  }
  fun2() {
    return 'fun2';
  }

  promiseFun() {
    return new Promise(resolve => {
      setTimeout(() => resolve('promise async fun'), 1000);
    });
  }

  async funWithAwait() {
    return await this.promiseFun();
  }
  async funWithoutAwait() {
    return 'function without await';
  }
}

module.exports = TestAsync;

/**
 * test begin
 */
 const obj = new TestAsync();
console.log(obj.fun1());
console.log(obj.fun2());
console.log(obj.funWithoutAwait());
console.log(obj.funWithAwait());
obj.funWithoutAwait().then((result) => {
  console.log(result);
}).catch((error) => {
  console.log(error);
});
obj.funWithAwait().then((result) => {
  console.log(result);
}).catch((error) => {
  console.log(error);
});
```

exec result:

```
wuhua:nodetest wuhua$ node testAsync.js 
fun1
fun2
Promise { 'function without await' }
Promise { <pending> }
function without await
promise async fun
```





