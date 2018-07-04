---
title: Git使用中发生的一些莫名错误
tags: [Git,shell]
comments: true
categories: [shell]
date: 2018-04-27 11:40:09
---
### git push报错 Tags:[index,master]
背景：`git add`和`git commit`后未及时`git push`，第二天`git push`报错。
错误详情：
```code
fatal: index file smaller than expected
fatal: index file smaller than expected
error: unable to resolve reference refs/remotes/origin/master: ??
error: Cannot lock the ref 'refs/remotes/origin/master'.
```
解决方式：
```code
rm .git/index
rm .git/refs/remotes/origin/master
git add -A
git commit -m "update"
git push origin master
```
原因：查询stackoverflow得上方解决结果，直接删除相应的报错文件，然后再重新将改变的工作提交到仓库中，最后再推倒远程仓库。可能原因猜测index文件和master文件被污染，不知具体原因。