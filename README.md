# WebImage
* 语言：Objective-C & Swift 4.1
* 编译平台：Xcode 9.3

#### 2018-04-01:
上传300张分辨率更高的新图至GitHub（原图片地址已失效）。  
升级至Swift 4.1。

#### 2017-08-18:
优化滚动逻辑。

#### 2017-08-17:
最近一直在学习Swift 3，于是先写了这个加载网络图片的demo练练手，顺便巩固一下Objective-C的一些基本语法知识。因为核心代码并不多，于是就把两种语言各写了一遍。注释写得比较多，可供刚学习iOS开发的新手参考~

pic-small.plist 和 pic-large.plist 两个文件中分别保存了300 张图片的地址，但是访问速度不是很快，而且我发现同样加载这些图片，Objective-C版的加载速度比Swift版略快一点，暂时还不知道为什么。

该程序依然还有一些不完善的地方，作为demo功能已经足够，如果日后再添加功能只会修改Swift版的，毕竟Swift代码的可读性更强，也是未来iOS开发的大趋势~

## 效果图：
<img src="https://github.com/Neil-Steven/WebImage/blob/master/Screenshots/demo.gif" width="450" height="800" />