---
title: CMakePractice笔记
tags: [cmake,c,c++,note]
comments: true
categories: [cmake]
date: 2020-11-06 20:47:30
---

## Tips

* linux下使用ldd查看动态库依赖关系，mac下使用otool

[项目源码]https://github.com/cocowh/CMakePractice)

[CmakePractice pdf](https://github.com/cocowh/CMakePractice/blob/master/Cmake%E5%AE%9E%E8%B7%B5.pdf)


## cmake常用变量和常用环境变量

### cmake变量引用方式

使用${}进行变量的引用，在IF等语句中，直接使用便令名而不通过${}取值。

### cmake自定义变量的方式

有隐式定义和显示定义两种

隐式定义如使用PROJECT指令时隐式的定义\<projectname\>\_BINARY\_DIR和\<projectname\>\_SOURCE\_DIR两个变量。

显示定义使用SET指令。

### cmake常用变量

#### CMAKE\_BINARY\_DIR、PROJECT\_BINARY\_DIR、\<projectname>\_BINARY\_DIR

指代的内容一致，若in source编译，指工程顶层目录，若out of source编译，指工程编译发生的目录。
PROJECT\_BINARY\_DIR跟其他指令稍有区别。

#### CMAKE\_SOURCE\_DIR、PROJECT\_SOURCE\_DIR、\<projectname\>\_SOURCE\_DIR

指代的内容一致，不论采用何种编译方式，都是工程顶层目录。PROJECT_SOURCE_DIR 跟其他指令稍有区别。

#### CMAKE\_CURRENT\_SOURCE\_DIR

指当前处理的 CMakeLists.txt 所在的路径

#### CMAKE\_CURRENT\_BINARY\_DIR

若是 in-source 编译，它跟 CMAKE\_CURRENT\_SOURCE\_DIR 一致，如果是 out-of-source 编译，他指的是 target 编译目录。

使用ADD\_SUBDIRECTORY(src bin)可以更改这个变量的值。

使用SET(EXECUTABLE\_OUTPUT\_PATH <新路径>)并不会对这个变量造成影响，仅仅修改了最终目标文件存放的路径。


#### CMAKE\_CURRENT\_LIST\_FILE 

输出调用这个变量的 CMakeLists.txt 的完整路径

#### CMAKE_CURRENT_LIST_LINE 

输出这个变量所在的行

#### CMAKE\_MODULE\_PATH
     
用来定义自己的 cmake 模块所在的路径。

若工程比较复杂，有可能编写一些 cmake 模块，这些 cmake 模块随工程发布，
为了让 cmake 在处理 CMakeLists.txt 时找到这些模块，需要通过 SET 指令，将cmake模块路径设置一下。

例如SET(CMAKE\_MODULE\_PATH ${PROJECT\_SOURCE\_DIR}/cmake) ,可通过 INCLUDE 指令来调用自己的模块。


#### EXECUTABLE\_OUTPUT\_PATH 和 LIBRARY\_OUTPUT\_PATH 

分别用来重新定义最终结果的存放目录，目标文件的存放路径和库文件的路径。

#### PROJECT_NAME

返回通过 PROJECT 指令定义的项目名称。

### cmake调用环境变量的方式

使用`$ENV{NAME}`指令调用系统的环境。

使用`SET{ENV{变量名} 值}`设置环境变量。

#### CMAKE\_INCLUDE\_CURRENT\_DIR

自动添加 CMAKE\_CURRENT\_BINARY\_DIR 和 CMAKE\_CURRENT\_SOURCE\_DIR 到当前处理的 CMakeLists.txt。

相当于在每个 CMakeLists.txt 加入: INCLUDE_DIRECTORIES(${CMAKE\_CURRENT\_BINARY\_DIR} ${CMAKE\_CURRENT\_SOURCE\_DIR})

#### CMAKE\_INCLUDE\_DIRECTORIES\_PROJECT\_BEFORE

将工程提供的头文件目录始终至于系统头文件目录的前面，当你定义的头文件确实跟系统发
生冲突时可以提供一些帮助。

#### CMAKE\_INCLUDE\_PATH 和 CMAKE\_LIBRARY\_PATH 

用于解决autotools工程中--extra-include-dir等参数的支持，若头文件没有存放在常规路径（/usr/include，/usr/local/include等），可通过这些变量弥补。

使系统环境变量而不是cmake变量，要在bash中用export或者csh中使用set命令设置或者
`CMAKE_INCLUDE_PATH=/home/include cmake ..`等方式

CMAKE\_INCLUDE\_PATH用在FIND_PATH中，CMAKE\_LIBRARY\_PATH用在FIND\_LIBRARY中


### 系统信息

 1. CMAKE_MAJOR_VERSION，CMAKE 主版本号，比如 2.4.6 中的 2 
 2. CMAKE_MINOR_VERSION，CMAKE 次版本号，比如 2.4.6 中的 4 
 3. CMAKE_PATCH_VERSION，CMAKE补丁等级，比如2.4.6 中的6 
 4. CMAKE_SYSTEM，系统名称，比如 Linux-2.6.22 
 5. CMAKE_SYSTEM_NAME，不包含版本的系统名，比如 Linux 
 6. CMAKE_SYSTEM_VERSION，系统版本，比如 2.6.22 
 7. CMAKE_SYSTEM_PROCESSOR，处理器名称，比如 i686. 
 8. UNIX，在所有的类UNIX平台为TRUE，包括OS X和cygwin 
 9. WIN32，在所有的 win32 平台为 TRUE，包括 cygwin
 
 
 ### 主要的开关选项
 
 1. CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS，用来控制IF ELSE语句的书写方式
 2. BUILD_SHARED_LIBS  
 这个开关用来控制默认的库编译方式，如果不进行设置，使用 ADD_LIBRARY 并没有指定库
 类型的情况下，默认编译生成的库都是静态库。 如果SET(BUILD_SHARED_LIBS ON)后，默认生成的为动态库。 
 3. CMAKE_C_FLAGS  
 设置 C 编译选项，也可以通过指令 ADD_DEFINITIONS()添加。 
 4. CMAKE_CXX_FLAGS  
 设置 C++编译选项，也可以通过指令 ADD_DEFINITIONS()添加。

## cmake常用指令

### 基本指令
#### ADD\_DEFINITIONS

向 C/C++编译器添加-D 定义，比如:  
`ADD_DEFINITIONS(-DENABLE_DEBUG -DABC)`，参数之间用空格分割。  

如果代码中定义了`#ifdef ENABLE_DEBUG #endif`，这个代码块就会生效。

如果要添加其他的编译器开关，可以通过` CMAKE_C_FLAGS `变量和` CMAKE_CXX_FLAGS `变量设置。

#### ADD\_DEPENDENCIES

```
ADD_DEPENDENCIES(target-name depend-target1 depend-target2 ...)
```

定义 target 依赖的其他 target，确保在编译本 target 之前，其他的 target 已经被构
建。

#### ADD\_EXECUTABLE

```
ADD_EXECUTABLE(binName ${SRC_LIST} [file.cpp])
```

生成文件名为binName的可执行文件，源文件是 ${SRC_LIST}定义的源文件列表或多个源文件。

#### ADD\_LIBRARY

```
ADD_LIBRARY(libname [SHARED|STATIC|MODULE]
    [EXCLUDE_FROM_ALL]
        source1 source2 ... sourceN)
```
指定的源文件生成链接文件，然后添加到工程中去。

不需要写全libhello.so，只需要填写hello即可，cmake系统会自动生成libhello.x

类型：

 - SHARED：动态库
 - STATIC：静态库
 - MODULE：在使用dyld的系统有效，若不支持dyld，则被当作SHARED对待
 
EXCLUDE_FROM_ALL：标识此库不会被默认构建，除非有其他的组件依赖或者手工构建

> 不可通过此命令创建同名静态库和动态库


#### ADD\_SUBDIRECTORY

```
ADD_SUBDIRECTORY(source\_dir [binary\_dir] [EXCLUDE\_FROM\_ALL])
```

向当前工程添加存放源文件的子目录，并可以指定中间二进制和目标二进制存放的为止。

#### ADD\_TEST 与 ENABLE\_TESTING 指令

```
ENABLE_TESTING()
```
控制 Makefile 是否构建 test 目标，涉及工程所有目录。

语法很简单，没有任何参数，ENABLE_TESTING()，一般情况这个指令放在工程的主 CMakeLists.txt 中.

```
ADD_TEST(testname Exename arg1 arg2 ...)
```
testname 是自定义的 test 名称，Exename 可以是构建的目标文件也可以是外部脚本等等。
后面连接传递给可执行文件的参数。如果没有在同一个 CMakeLists.txt 中打开 ENABLE_TESTING()指令，任何 ADD_TEST 都是无效的。

#### AUX\_SOURCE\_DIRECTORY

```
AUX_SOURCE_DIRECTORY(dir VARIABLE)
```
发现一个目录下所有的源代码文件并将列表存储在一个变量中，
这个指令临时被用来自动构建源文件列表。因为目前 cmake 还不能自动发现新添加的源文件。

example:

```
AUX_SOURCE_DIRECTORY(. SRC_LIST) 
ADD_EXECUTABLE(main ${SRC_LIST})
```
也可以通过后面 FOREACH 指令来处理这个 LIST

#### CMAKE\_MINIMUM\_REQUIRED

```
CMAKE_MINIMUM_REQUIRED(VERSION versionNumber [FATAL_ERROR])
```

example:

```
CMAKE_MINIMUM_REQUIRED(VERSION 2.5 FATAL_ERROR)
```
如果 cmake 版本小与 2.5，则出现严重错误，整个过程中止。

#### EXEC\_PROGRAM

```
XEC_PROGRAM(Executable [directory in which to run]
                 [ARGS <arguments to executable>]
                 [OUTPUT_VARIABLE <var>]
[RETURN_VALUE <var>])
```
用于在指定的目录运行某个程序，通过 ARGS 添加参数，如果要获取输出和返回值，可通过
OUTPUT_VARIABLE 和 RETURN_VALUE 分别定义两个变量.

在 CMakeLists.txt 处理过程中执行命令，并不会在生成的 Makefile 中执行.

可以帮助在 CMakeLists.txt 处理过程中支持任何命令，比如根据系统情况去
修改代码文件等等。

#### FILE 指令

```
    FILE(WRITE filename "message to write"... )
    FILE(APPEND filename "message to write"... )
    FILE(READ filename variable)
    FILE(GLOB variable [RELATIVE path] [globbing expressions]...)
    FILE(GLOB_RECURSE variable [RELATIVE path] [globbing expressions]...)
    FILE(REMOVE [directory]...) 
    FILE(REMOVE_RECURSE [directory]...) 
    FILE(MAKE_DIRECTORY [directory]...) 
    FILE(RELATIVE_PATH variable directory file) 
    FILE(TO_CMAKE_PATH path result) 
    FILE(TO_NATIVE_PATH path result)
```

#### INCLUDE 指令

```
INCLUDE(file1 [OPTIONAL])
INCLUDE(module [OPTIONAL])
```
用来载入 CMakeLists.txt 文件，也用于载入预定义的 cmake 模块。

OPTIONAL：文件不存在也不会产生错误。

你可以指定载入一个文件，如果定义的是一个模块，那么将在 CMAKE\_MODULE\_PATH 中搜索这个模块并载入。

载入的内容将在处理到 INCLUDE 语句时直接执行。

### INSTALL 指令


INSTALL：定义安装规则，安装的内容可以包括二进制、动态库、静态库以及文件、目录、脚本等

CMAKE\_INSTALL\_PREFIX：类似于configure脚本的-prefix

常见的使用方法`cmake -DCMAKE_INSTALL_PREFIX=/usr .`

若没指定CMAKE\_INSTALL\_PREFIX，默认定义是/usr/local

#### INSTALL目标文件的安装

```
INSTALL(TARGETS targets ...  
    [[ARCHIVE|LIBRARY|RUNTIME]  
        [DESTINATION <dir>]  
        [PERMISSIONS permissions...]  
        [CONFIGURATIONS [Debug|Release|...]]  
        [COMPONENT <component>]  
        [OPTIONAL]  
    ] [...])
```
TARGETS后面跟通过`ADD\_EXECUTABLE`或者`ADD\_LIBRARY`定义的目标文件，可能是可执行二进制、动态库、静态库。

目标类型：ARCHIVE指静态库、LIBRARY指动态库、RUNTIME指可执行目标二进制

DESTINATION定义安装的路径，若以/开头则是绝对路径，`CMAKE_INSTALL_PREFIX`无效，否则安装路径是${CMAKE\_INSTALL\_PREFIX}/<DESTINATION定义的路径>

example：

```example
INSTALL(TARGETS myrun mylib mystaticlib
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION libstatic
)
```
#### INSTALL普通文件的安装

```
INSTALL(FILES files... DESTINATION <dir>
    [PERMISSIONS permissions...]
    [CONFIGURATIONS [Debug|Release|...]]
    [COMPONENT <component>]
    [RENAME <name>] [OPTIONAL])
```

用于安装一般的文件，并可以指定访问权限，文件名是此指令所在路径下的相对路径。

若不定义权限PERMISSIONS，安装后的权限为：OWNER_WRITE，OWNER_READ，GROUP_READ和WORLD_READ，即644权限。


#### INSTALL非目标文件的可执行程序安装(如脚本)

```
INSTALL(PROGTAMS files... DESTINATION <dir>
    [PERMISSIONS permissions...]
    [CONFIGURATIONS [Debug|Release|...]]
    [COMPONENT <component>]
    [RENAME <name>] [OPTIONAL])
```

若不定义权限PERMISSIONS，安装后权限为：OWNER_EXECUTE，GROUP_EXECUTE和WORLD_EXECUTE
，即755权限。

#### INSTALL目录的安装

```
INSTALL(DIRECTORY dires... DESTINATION <dir>
    [FILE_PERMISSIONS permissions...]
    [USE_SOURCE_PERMISSIONS]
    [CONFIGURATIONS [Debug|Release...]]
    [COMPONENT <component>]
    [[PATTERN <pattern> | REGEX <regex>] [EXCLUDE] [PERMISSIONS permissions ...]]
    [...])
```

DIRECTORY：所在Source目录的相对路径，以abc/和abc结尾有不同，若以abc结尾则目录被安装为目标路径下的abc，若以abc/结尾则代表将这个目录中的内容安装到目标路径，但不包括这个目录本身。

PATTERN：用于使用正则表达式进行过滤

PERMISSIONS：用于指定PATTERN过滤后的文件权限。

example:

```
INSTALL(DIRECTORY icons scripts/ DESTINATION share/myproj
    PATTERN "CVS" EXCLUDE
    PATTERN "scripts/*"
    PERMISSIONS OWNER_EXECUTER OWNER_WRITE OWNER_REASD GROUP_EXECUTE GROUP_READ)
```
将icons目录安装<prefix>/share/myproj，将scripts/中的内容安装到<prefix>/share/myproj

不包含目录名为CVS的目录，对于scripts/*文件指定权限为OWNER_EXECUTER OWNER_WRITE OWNER_REASD GROUP_EXECUTE GROUP_READ

#### 安装时CMAKE脚本的执行

```
INSTALL([[SCRIPT <file>] [CODE <code>]] [...])
```

SCRIPT：在安装时调用cmake脚本文件(即<abc>.cmake文件)

CODE：执行CMAKE指令，必须以双引号括起来。

example：`INSTALL(CODE "MESSAGE("Sample install message.")")`


#### INSTALL_FILES

过时安装指令

### FIND_指令

```
FIND_FILE(<VAR> name1 path1 path2 ...)
```
VAR 变量代表找到的文件全路径，包含文件名 

```
FIND_LIBRARY(<VAR> name1 path1 path2 ...)
```
VAR 变量表示找到的库全路径，包含库文件名 

```
FIND_PATH(<VAR> name1 path1 path2 ...)
```
VAR 变量代表包含这个文件的路径。 

```
FIND_PROGRAM(<VAR> name1 path1 path2 ...)
```
VAR 变量代表包含这个程序的全路径。

```
FIND_PACKAGE(<name> [major.minor] [QUIET] [NO_MODULE] 
    [[REQUIRED|COMPONENTS] [componets...]])
```
用来调用预定义在 CMAKE_MODULE_PATH 下的 Find<name>.cmake 模块，你也可以自己 定义Find<name>模块，通过SET(CMAKE_MODULE_PATH dir)将其放入工程的某个目录 中供工程使用，我们在后面的章节会详细介绍 FIND_PACKAGE 的使用方法和 Find 模块的 编写。

example:

```
FIND_LIBRARY(libX X11 /usr/lib) 
IF(NOT libX)
MESSAGE(FATAL_ERROR “libX not found”) 
ENDIF(NOT libX)
```

### 控制指令

#### IF 指令

```
IF(expression)
    # THEN section. 
    COMMAND1(ARGS ...)
    COMMAND2(ARGS ...) ...
ELSE(expression)
    # ELSE section. 
    COMMAND1(ARGS ...) 
    COMMAND2(ARGS ...) ...
ENDIF(expression)
```

凡是出现 IF 的地方一定要有对应的 ENDIF，出现 ELSEIF 的地方，ENDIF 是可选的。

IF(var)，如果变量不是:空，0，N, NO, OFF, FALSE, NOTFOUND 或 <var>_NOTFOUND 时，表达式为真。

IF(NOT var )，与上述条件相反。

IF(var1 AND var2)，当两个变量都为真是为真。

IF(var1 OR var2)，当两个变量其中一个为真时为真。

IF(COMMAND cmd)，当给定的cmd确实是命令并可以调用是为真。

IF(EXISTS dir)或者IF(EXISTS file)，当目录名或者文件名存在时为真。

IF(file1 IS_NEWER_THAN file2)，当 file1 比 file2 新，或者 file1/file2 其 中有一个不存在时为真，文件名使用完整路径。

IF(IS_DIRECTORY dirname)，当dirname是目录时，为真。

IF(variable MATCHES regex)  
IF(string MATCHES regex)  
当给定的变量或者字符串能够匹配正则表达式 regex 时为真。比如:

```
IF("hello" MATCHES "ell")
    MESSAGE("true")
ENDIF("hello" MATCHES "ell")
```

IF(variable LESS number)   
IF(string LESS number)   
IF(variable GREATER number)   
IF(string GREATER number)   
IF(variable EQUAL number)   
IF(string EQUAL number)  
数字比较表达式。


IF(variable STRLESS string)  
IF(string STRLESS string)  
IF(variable STRGREATER string)  
IF(string STRGREATER string)  
IF(variable STREQUAL string)  
IF(string STREQUAL string)   
按照字母序的排列进行比较。

IF(DEFINED variable)，如果变量被定义，为真。


example:

```
IF(WIN32)
    MESSAGE(STATUS “This is windows.”) 
    #作一些 Windows 相关的操作
ELSE(WIN32)
    MESSAGE(STATUS “This is not windows”) 
    #作一些非 Windows 相关的操作
ENDIF(WIN32)
```
ELSE(WIN32)易引起歧义。

可用` CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS `开关。

```
SET(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS ON)

IF(WIN32)
ELSE()
ENDIF()

IF(WIN32)
    #do something related to WIN32 ELSEIF(UNIX)
    #do something related to UNIX
ELSEIF(APPLE)
    #do something related to APPLE
ENDIF(WIN32)
```

#### WHILE

```
WHILE(condition) 
    COMMAND1(ARGS ...) 
    COMMAND2(ARGS ...) ...
ENDWHILE(condition)
```
其真假判断条件可以参考 IF 指令。

#### FOREACH
使用方法有三种形式

##### 列表

```
FOREACH(loop_var arg1 arg2 ...) 
    COMMAND1(ARGS ...) 
    COMMAND2(ARGS ...)
    ...
ENDFOREACH(loop_var)
```

example:

```
AUX_SOURCE_DIRECTORY(. SRC_LIST) 
FOREACH(F ${SRC_LIST})
     MESSAGE(${F})
ENDFOREACH(F)
```

##### 范围

```
FOREACH(loop_var RANGE total) 
ENDFOREACH(loop_var)
```

example:

```
FOREACH(VAR RANGE 10) 
    MESSAGE(${VAR})
ENDFOREACH(VAR)
```

##### 范围和步进

```
FOREACH(loop_var RANGE start stop [step]) 
ENDFOREACH(loop_var)
```

example:

```
FOREACH(A RANGE 5 15 3) 
MESSAGE(${A}) 
ENDFOREACH(A)
```
