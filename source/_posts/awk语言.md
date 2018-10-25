---
title: awk语言
tags: [awk]
comments: true
categories: [awk程序设计语言]
date: 2018-10-23 16:58:42
---
输入数据countries

```
USSR	8649    275	Asia
Canada	3852    25	North America
China	3705    1032	Asia
USA	3615    237	North America
Brazil	3286    134	South America
India	1267    746	Asia
Mexico	762     78	North America
```

### 程序格式

模式-动作语句，以及动作内的语句通常用换行符分割，但是若干条语句也可以出现在同一行，之间用分号分开。一个分号可以放在任何语句的末尾。动作的左花括号必须与其模式在同一行；剩下的部分，包括右花括号，可以出现在下面几行。

空行会被忽略；可以插入在语句之前或之后，提高程序可读性。

注释可以出现在任意一行的末尾，以井号（#）开始，换行符结束。

一条长语句可以拆分成多行，在断行处插入一个反斜杠。

### 模式

#### BEGIN与END
不匹配任何输入行。当awk从输入读取之前，BEGIN的语句开始执行；当所有输入数据读取完毕，END语句开始执行。BEGIN与END分别提供了一种控制初始化与扫尾的方式。BEGIN与END不能与其他模式作组合。若有多个BEGIN，与其关联的动作会按照在程序中出现的顺序执行，同样适用于END。通常将BEGIN放在程序开头，END放在程序结尾，非强制的。

BEGIN常见用于更改输入行被分割为字段的默认方式，分割字符由一个内建变量FS控制。默认情况下字段由空格或（和）制表符分割，此时FS的值被设置为一个空格符。

```
BEGIN { FS = '\t'  
			printf("%10s %6s %5s %s\n\n",
			"COUNTRY", "AREA", "POP", "CONTINENT")
		}
		{ printf("%10s %6s %5s %s\n", $1, $2, $3, $4)
			area = area + $2
			pop = pop + $3
		}
END {printf("\n%10s %6d %5d\n","TOTAL", area, pop)}
```

