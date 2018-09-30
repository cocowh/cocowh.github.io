---
title: git命令
tags: [shell,git]
comments: true
categories: [git]
date: 2018-08-01 20:04:27
---

记录一些不常用到或者易遗忘的git命令。

---

参考：[Book](https://git-scm.com/book/zh/v2)

### 记录每次更新到仓库
参考：Book

#### 状态简览

```
git status -s
```
或

```
git status --short
```
#### 忽略文件
文件 .gitignore 的格式规范如下：

* 所有空行或者以 ＃ 开头的行都会被 Git 忽略。
* 可以使用标准的 glob 模式匹配。
* 匹配模式可以以（/）开头防止递归。
* 匹配模式可以以（/）结尾指定目录。
* 要忽略指定模式以外的文件或目录，可以在模式前加上惊叹号（!）取反。

#### 查看已暂存和未暂存的修改
通过文件补丁的格式显示具体哪些行发生了改变:

```
git diff
```
#### 查看已暂存的将要添加到下次提交里的内容:

```
git diff --cached
```
或

```
git diff --staged
```
#### 跳过使用暂存区域
自动把所有已经跟踪过的文件暂存起来一并提交，从而跳过 git add 步骤：

```
git commit -a -m 'description message'
```
#### 移除文件
从已跟踪文件清单中移除（确切地说，是从暂存区域移除，然后提交：

```
git rm filename
```
若删除之前修改过并且已经放到暂存区域，用强制删除选项 -f（译注：即 force 的首字母）,不能被 Git 恢复.

让文件保留在磁盘，不让 Git 继续跟踪:

```
git rm --cached filename
```
#### 移动文件
在 Git 中对文件改名:

```
git mv filename new_filename
```
相当于：

```
mv filename new_filename
git rm filename
git add new_filename
```
### 查看提交历史
回顾下提交历史:

```
git log
```
不用任何参数，按提交时间列出所有的更新，最近的更新排在最上面。加参数-p，用来显示每次提交的内容差异，加上-2来仅显示最近两次提交。

```
git log -p -2
```
使用–stat参数查看每次提交的简略的统计信息：

```
git log --stat
```
参数–pretty指定使用不同于默认格式的方式展示提交历史，有一些内建的子选项供使用。如参数oneline将每个提交放在一行显示，参数format定制要显示的记录格式，还有short，full和fuller可用，展示的信息或多或少有些不同。

```
git log --pretty=format:"%h - %an, %ar : %s"
```
format[常用的选项](https://git-scm.com/book/zh/v2/Git-%E5%9F%BA%E7%A1%80-%E6%9F%A5%E7%9C%8B%E6%8F%90%E4%BA%A4%E5%8E%86%E5%8F%B2#rpretty_format)。

oneline或format与log选项–graph结合使用,添加一些ASCII字符串来形象地展示分支、合并历史：

```
git log --pretty=format:"%h %s" --graph
```
git log[常用选项](https://git-scm.com/book/zh/v2/Git-%E5%9F%BA%E7%A1%80-%E6%9F%A5%E7%9C%8B%E6%8F%90%E4%BA%A4%E5%8E%86%E5%8F%B2#rlog_options)

–since和–until按照时间作限制:

```
git log --since=2.weeks
```
限制git log[输出的选项](https://git-scm.com/book/zh/v2/Git-%E5%9F%BA%E7%A1%80-%E6%9F%A5%E7%9C%8B%E6%8F%90%E4%BA%A4%E5%8E%86%E5%8F%B2#rlimit_options)

### 撤销操作
尝试重新提交，覆盖上一次的提交：

```
git commit --amend
```
#### 取消暂存的文件

```
git reset HEAD filename
```
#### 撤消对文件的修改
将文件还原成上次提交时的样子（或者刚克隆完的样子，或者刚把它放入工作目录时的样子）:

```
git checkout -- filename
```
实际上是拷贝了另一个文件来覆盖。

>Git中任何已提交的东西几乎总是可以恢复的，任何未提交的东西丢失后很可能无法恢复。

### 远程仓库的使用
#### 查看远程仓库
运行`git remote`命令，列出指定的每一个远程服务器的简写。
指定选项 -v，显示需要读写远程仓库使用的Git保存的简写与其对应的URL。

```
git remote -v
```
#### 添加远程仓库
运行`git remote add <shortname> <url>`添加一个新的远程Git仓库，同时指定一个可以轻松引用的简写。

运行`git fetch shortname`拉取url所指仓库中有但自己没有的信息。

#### 从远程仓库中抓取与拉取

```
git fetch [remote-name]
```
若有一个分支设置为跟踪一个远程分支，使用`git pull`命令来自动的抓取然后合并远程分支到当前分支。

#### 推送到远程仓库
`git push [remote-name] [branch-name]`

```
git push origin master
```
#### 查看远程仓库
`git remote show [remote-name]`

```
git remote show origin
```
#### 远程仓库的移除与重命名
`git remote rename`修改远程仓库的简写名。

```
git remote rename oldshortname newshortname
```
git remote rm移除一个远程仓库.

```
git remote rm shortname
```
### 打标签
给历史中的某一个提交打上标签，以示重要。

#### 列出标签
`git tag`

```
git tag -l 'v1.8.5*'
```
#### 创建标签
两种主要类型的标签：轻量标签（lightweight）与附注标签（annotated）。

轻量标签很像一个不会改变的分支 - 它只是一个特定提交的引用。

附注标签是存储在 Git 数据库中的一个完整对象。 它们是可以被校验的；其中包含打标签者的名字、电子邮件地址、日期时间；还有一个标签信息；并且可以使用 GNU Privacy Guard （GPG）签名与验证。 通常建议创建附注标签，这样你可以拥有以上所有信息；但是如果你只是想用一个临时的标签，或者因为某些原因不想要保存那些信息，轻量标签也是可用的。

#### 附注标签
运行 tag 命令时指定 -a 选项:

```
git tag -a tagname -m 'description in tag'
```
-m 选项指定了一条将会存储在标签中的信息。

#### 轻量标签
轻量标签本质上是将提交校验和存储到一个文件中 - 没有保存任何其他信息。 创建轻量标签，不需要使用 -a、-s 或 -m 选项，只需要提供标签名字：

```
git tag tagname
```
#### 后期打标签
```
//查看提交日志
git log --pretty=oneline
//使用显示的校验打标签
git tag -a tagname  部分或完整校验和
```
#### 共享标签
默认情况下，`git push`命令并不会传送标签到远程仓库服务器上。在创建完标签后你必须显式地推送标签到共享服务器上。 这个过程就像共享远程分支一样 - 你可以运行`git push origin [tagname]`。

```
git push origin tagname
```
一次性推送很多标签，也可以使用带有 –tags 选项的 git push 命令。 这将会把所有不在远程仓库服务器上的标签全部传送到那里。

```
git push origin --tags
```
#### 检出标签
使用`git checkout -b [branchname] [tagname]`在特定的标签上创建一个新分支：

```
git checkout -b newbranchshartname tagname.
```
### Git别名
通过git config文件为命令设置别名:

```
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
```
### Git分支
#### 分支创建
`git branch`命令

```
git branch branchname
```
`git log --oneline --decorate`查看各个分支当前所指的对象

#### 分支切换
`git checkout`命令

```
git checkout branchname
```
`git log --oneline --decorate --graph --all`查看分叉历史

#### 分支合并
基于master的紧急分支的创建、合并、删除

```
git checkout -b iss53
git checkout master
git checkout -b hotfix
git checkout master
git merge hotfix
git branch -d hotfix
git checkout iss53
git checkout master
git merge iss53
```
#### 遇到冲突时的分支合并
在两个分支中对同一个文件的同一个部分进行了不同的更改，Git没法干净的合并

使用`git status`命令查看那些因包含合并冲突而处于未合并（unmerged）状态的文件

可以打开这些包含冲突的文件然后手动解决冲突

包含特殊区段

```
<<<<<<< HEAD:index.html
<div id="footer">contact : email.support@github.com</div>
=======
<div id="footer">
 please contact us at support@github.com
</div>
>>>>>>> iss53:index.html
```
改为
```
<div id="footer">
please contact us at email.support@github.com
</div>
```
运行`git mergetool`，命令启动一个合适的可视化合并工具

### 分支管理
`git branch`不加任何参数运行，得到当前所有分支的一个列表:

```
localhost:algorithm wuhua$ git branch
  iss21
* master
  test
```
运行`git branch -v`查看每一个分支的最后一次提交:

```
localhost:algorithm wuhua$ git branch -v
  iss21  49dba1c sort
* master 49dba1c sort
  test   49dba1c sort
```
运行`git branch --merged`查看哪些分支已经合并到当前分支:

```
localhost:algorithm wuhua$ git branch --merged
  iss21
* master
  test
```
运行`git branch --no-merged`查看所有包含未合并工作的分支:

使用`git branch -d`命令删除还未合并的分支会失败。

### 分支开发工作流
#### 长期分支
只在master分支上保留完全稳定的代码，在名为develop或者next的平行分支上做后续开发或者测试稳定性——这些分支不必保持绝对稳定，但是一旦达到稳定状态，它们就可以被合并入master分支了。

#### 特性分支
特性分支是一种短期分支，它被用来实现单一特性或其相关工作，在合并完成后即可被删除。例如bug的修改，功能的新增等。
### 远程分支
远程引用是对远程仓库的引用（指针），包括分支、标签等等。

通过`git ls-remote (remote)`显式地获得远程引用的完整列表，通过`git remote show (remote)`获得远程分支的更多信息。 更常见利用远程跟踪分支。远程跟踪分支是远程分支状态的引用。远程跟踪分支像是你上次连接到远程仓库时，那些分支所处状态的书签。以`(remote)/(branch)`形式命名。

>“origin” 并无特殊含义。远程仓库名字“origin”与分支名字“master”一样，在Git中并没有任何特别的含义一样。 同时“master”是运行`git init`时默认的起始分支名字，原因仅仅是它的广泛使用，“origin”是当运行`git clone`时默认的远程仓库名字。如果运行`git clone -o booyah`，则默认的远程分支名字将会是`booyah/master`。

运行`git fetch origin`命令，查找 “origin” 是哪一个服务器，从中抓取本地没有的数据，并且更新本地数据库，移动`origin/master`指针指向新的、更新后的位置。

运行`git remote add`命令添加一个新的远程仓库引用到当前的项目。

#### 推送
运行`git push (remote) (branch)`推送到分支。

抓取到新的远程跟踪分支时，本地不会自动生成一份可编辑的副本（拷贝），即不会有一个新的brach分支 - 只有一个不可以修改的`origin/branch`指针。

运行`git merge origin/serverfix`将工作合并到当前所在的分支。

运行`git checkout -b branch origin/branch`将自己的分支建立在远程跟踪分支之上，及本地新建本地分支branch并且起点位于`origin/serverfix`。

#### 跟踪分支
克隆一个仓库通常会自动地创建一个跟踪`origin/master`的master分支。运行`git checkout -b [branch] [remotename]/[branch]`设置其他的跟踪分支。可使用`--track`快捷方式。

```
git checkout --track [remotename]/[branch]
```
使用`-u`或`--set-upstream-to`选项运行`git branch`显式地设置已有的本地分支跟踪一个刚刚拉取下来的远程分支。

```
git branch -u [remotename]/[branch]
```
使用`git branch`的`-vv`选项查看设置的所有跟踪分支。

#### 拉取
`git fetch`命令从服务器上抓取本地没有的数据，不会修改工作目录中的内容，只获取数据然后自己合并。命令`git pull`在大多数情况下它的含义是一个`git fetch`紧接着一个`git merge`命令。若有跟踪分支，不管它是显式地设置还是通过`clone`或`checkout`命令创建，`git pull`会查找当前分支所跟踪的服务器分支，从服务器上抓取数据然后尝试合并入那个远程分支。

通常单独显式地使用`fetch`与`merge`命令会更好一些。

#### 删除远程分支
运行带有`--delete`选项的`git push`命令删除一个远程分支。

```
git push origin --delete branchname
```
### 变基
使用`rebase`命令将提交到某一分支上的所有修改都移至另一分支上。原理是首先找到这两个分支（即当前分支、变基操作的目标基底分支）的最近共同祖先，然后对比当前分支相对于该祖先的历次提交，提取相应的修改并存为临时文件，然后将当前分支指向目标基底, 最后以此将之前另存为临时文件的修改依序应用。

目的是为了确保在向远程分支推送时能保持提交历史的整洁——例如向某个其他人维护的项目贡献代码时。在这种情况下，首先在自己的分支里进行开发，当开发完成时需要先将自己的代码变基到`origin/master`上，然后再向主项目提交修改。这样的话，该项目的维护者就不再需要进行整合工作，只需要快进合并便可。

变基是将一系列提交按照原有次序依次应用到另一分支上，而合并是把最终结果合在一起。

使用`git rebase`命令的`--onto`选项截取分支的分支变基到其他分支：

```
git rebase --onto master branch sonbranch
```
取sonbranch分支，找到处于分支branch和分支的分支sonbranch的共同祖先之后的修改，然后把它们在master分支上重放一遍。之后合并：

```
git checkout master
git merge sonbranch
```
使用`git rebase [basebranch] [topicbranch]`命令直接将特性分支变基到目标分支上。省去先切换到topicbranch分支，再对其执行变基命令的多个步骤:

使用`git pull --rebase`命令而不是直接`git pull`，或者先`git fetch`，再`git rebase origin/master`。防变基已提交造成的混乱。

>不要对在仓库外有副本的分支执行变基。只对尚未推送或分享给别人的本地修改执行变基操作清理历史，从不对已推送至别处的提交执行变基操作。把变基命令当作是在推送前清理提交使之整洁的工具，并且只在从未推送至共用仓库的提交上执行变基命令。

### 协议
Git 可以使用四种主要的协议来传输资料：本地协议（Local），HTTP 协议，SSH（Secure Shell）协议及 Git 协议。

#### 本地协议
远程版本库就是硬盘内的另一个目录。若使用用共享文件系统，可以从本地版本库克隆（clone）、推送（push）以及拉取（pull）。

```
git clone /opt/git/project.git

git clone file:///opt/git/project.git

git remote add local_proj /opt/git/project.git
```
#### HTTP 协议
新版本(V1.6.6+)的 HTTP 协议一般被称为“智能” HTTP 协议，旧版本的一般被称为“哑” HTTP 协议。

#### 智能（Smart） HTTP 协议
“智能” HTTP 协议的运行方式和 SSH 及 Git 协议类似，只是运行在标准的 HTTP/S 端口上并且可以使用各种 HTTP 验证机制，这意味着使用起来会比 SSH 协议简单的多，比如可以使用 HTTP 协议的用户名／密码的基础授权，免去设置 SSH 公钥。

[智能（Smart） HTTP 协议](https://git-scm.com/book/zh/v2/%E6%9C%8D%E5%8A%A1%E5%99%A8%E4%B8%8A%E7%9A%84-Git-%E5%8D%8F%E8%AE%AE)

#### 哑（Dumb） HTTP 协议
[哑（Dumb） HTTP 协议](https://git-scm.com/book/zh/v2/%E6%9C%8D%E5%8A%A1%E5%99%A8%E4%B8%8A%E7%9A%84-Git-%E5%8D%8F%E8%AE%AE)

#### SSH 协议
[SSH 协议](https://git-scm.com/book/zh/v2/%E6%9C%8D%E5%8A%A1%E5%99%A8%E4%B8%8A%E7%9A%84-Git-%E5%8D%8F%E8%AE%AE)

#### Git 协议
[Git 协议](https://git-scm.com/book/zh/v2/%E6%9C%8D%E5%8A%A1%E5%99%A8%E4%B8%8A%E7%9A%84-Git-%E5%8D%8F%E8%AE%AE)