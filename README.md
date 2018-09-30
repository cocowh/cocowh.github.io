## cocowh.github.io

---

## 博客备份、方便换机

---

### 目录结构

├── README.md  
├── \_config.yml  
├── db.json  
├── deploy.sh  
├── new.sh  
├── package-lock.json  
├── package.json  
├── public  
│   ├── 2018  
│   ├── about  
│   ├── archives  
│   ├── assets  
│   ├── atom.xml  
│   ├── categories  
│   ├── content.json  
│   ├── css  
│   ├── images  
│   ├── index.html  
│   ├── js  
│   ├── lib  
│   ├── page  
│   ├── search.xml  
│   └── tags  
├── scaffolds  
│   ├── draft.md  
│   ├── page.md  
│   └── post.md  
├── source  
│   ├── \_posts  
│   ├── about  
│   ├── categories  
│   └── tags  
└── themes  
  └── next 
  
  
### command

```
git clone -b blogbackup https://github.com/cocowh/cocowh.github.io.git blog
cd blog 
npm update
mkdir .deploy
cd .deploy 
git clone https://github.com/cocowh/cocowh.github.io.git
```