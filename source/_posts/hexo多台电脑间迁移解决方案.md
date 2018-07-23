---
title: hexo多台电脑间迁移解决方案
tags: [hexo,git]
comments: true
categories: [git]
date: 2018-07-05 02:34:02
---

由于工作配发了mac，之前在自己的thinkpad上搭建的博客如何迁移到mac上，并且保持博客的完整性和统一性就成了问题。

在网上搜了一下，前人已经给出了巧妙的解决方案，通过在自己的hexo项目上开一个分支，分支中保留hexo所有重要文件，在其他电脑上直接下载此分支，然后使用npm下载所有依赖包，这样其实就可以得到自己的hexo完整项目。通过这个克隆的分支可以写博客上传到master，也可以自更新上传到分支，保证每次使用后的完整性。

具体参考的前人博客[Hexo博客从一台电脑迁移到其他电脑](https://www.jianshu.com/p/beb8d611340a),介绍了总体的解决思路和步骤，具体细节要根据自己的情况而定。

具体到本博客的迁移过程：

* 克隆自己的hexo项目到本地，其实主要目的是获取git配置文件，作为分支的git配置文件，若本地已有git项目，可省略此步，后面直接获取git配置文件即可。

    ```code
    git clone https://github.com/cocowh/cocowh.github.io.git
    ```

* 备份本地的hexo项目，删除依赖库和不必要的文件（多余的主题目录，生成的页面等等，根据自己配置决定），`修改主题中git的配置文件名，否则主题目录被当作单独的git项目无法被跟踪，无法上传`，有个风险是主题配置文件中的信息被暴露出来，如果不上传，在另一台电脑上克隆后又要重新下载配置主题文件，显得繁琐。

    ```code
    cp -R hexo blogbackup
    cp -R cocowh.github.io/.git blogbackup/.git
    cp cocowh.github.io/.gitignore  blogbackup
    cd blogbackup
    rm -rf public node_modules //其实在.gitignore中已经包含这些文件和目录
    ```

* 创建一个叫blogbackup的分支并push到分支。

    ```code
    git checkout -b blogbacku
    git add -A
    git commit -m "备份分支"
    git push --set-upstream origin blogbackup
    ```

* 在另一台已经部署好git、node 、hexo等必须环境的电脑上克隆blogbackup分支到本地，克隆master到本地(没用hexo自带提交指令，自己编写的本地提交脚本，根据情况灵活决定)。

    ```code
    git clone -b blogbackup https://github.com/cocowh/cocowh.github.io.git
    cd coocwh.github.io
    npm update
    mkdir .deploy
    cd .deploy
    git clone https://github.com/cocowh/coocwh.github.io.git
    cd ../..
    hexo g
    hexo s
    ```

到这里已经基本搞定，写博客运行脚本提交到master。再次迁移到另一台电脑上，直接提交到blogbackup分支就好，更新主题要将git文件名修改回来。