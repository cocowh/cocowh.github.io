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

