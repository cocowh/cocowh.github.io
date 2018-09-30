hexo generate
cp -R public/* .deploy/cocowh.github.io
cd .deploy/cocowh.github.io
git add -A
git commit -m "update"
git push origin master
cd ../..
git add -A
git commit -m 'update post'
git push

