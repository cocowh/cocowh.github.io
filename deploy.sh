#!/bin/bash
hexo generate
cp -R public/* .deploy/cocowh.github.io
cd .deploy/cocowh.github.io
echo '--------master begin---------'
git add -A
git commit -m "update"
git push origin master
echo '--------master   end---------'
cd ../..
echo '--------backup begin---------'
git add -A
git commit -m 'update post'
git push
echo '--------backup   end---------'

