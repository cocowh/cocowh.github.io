## 个人博客
[http://bighua.top/](http://bighua.top/)

---

### 目录结构

>├── 2018  
├── CNAME  
├── README.md  
├── about  
├── archives  
├── assets  
├── atom.xml  
├── categories  
├── content.json  
├── css  
├── images  
├── index.html  
├── js  
├── lib  
├── page  
├── search.xml  
└── tags  

### shell

#### new.sh

```
#!/bin/bash
hexo new $1
chmod -R 777 source
```
新建博客：

```
./new.sh postName
```

#### deploy.sh
编译提交到博客仓库

同时更新提交[备份仓库](https://github.com/cocowh/cocowh.github.io/tree/blogbackup)

```
#!/bin/bash
echo '--------hexo generating------'
echo ' '
hexo generate
echo '--------generate end---------'
cp -R public/* .deploy/cocowh.github.io
cd .deploy/cocowh.github.io
echo ' '
echo '--------master begin---------'
git add -A
git commit -m "update"
git push origin master
echo '--------master   end---------'
echo ' '
cd ../..
echo '--------backup begin---------'
git add -A
git commit -m 'update post'
git push
echo '--------backup   end---------'
```

更新博客：

```
./deploy.sh
```