//
//  ViewController.swift
//  WebImage-Swift
//
//  Created by Neil Steven on 2017/8/15.
//  Copyright © 2017年 Neil Steven. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate {

    // 将Caches目录路径保存为本地变量以方便使用
    let kPathCache = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!

    
    
    // CollectionView
    @IBOutlet weak var picCollectionView: UICollectionView!
    
    // 图片的数据源
    lazy var picArray = Array<String>()
    // 下载操作队列
    lazy var queue = OperationQueue()
    // 图片缓存池
    lazy var imageCache : Dictionary = Dictionary<String, UIImage>()
    // 下载操作缓冲池
    lazy var operationCache : Dictionary = Dictionary<String, Operation>()
    // 下拉刷新控件
    lazy var refreshControl = UIRefreshControl()

    // 页面滚动标记
    var isScrolling = false
    
    

    // MARK: - 
  
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 控制台打印App根目录
        NSLog("Home directory: %@", NSHomeDirectory());
        
        // 初始化picCollectionView
        picCollectionView.delegate = self
        picCollectionView.dataSource = self
        picCollectionView.frame = UIScreen.main.bounds
        
        
        // 初始化picArray数据源
        if let picPlistFile = Bundle.main.path(forResource: "pic-large", ofType: "plist") {
            picArray = NSMutableArray(contentsOfFile: picPlistFile) as! Array<String>
        }

        // 设置下载并发数
        self.queue.maxConcurrentOperationCount = 10;
        
        
        // 设置刷新控件的颜色
        refreshControl.tintColor = UIColor.blue
        // 设置刷新控件下边的提示文字及文字的颜色
        refreshControl.attributedTitle = NSAttributedString(string: "下拉刷新")
        // 给refreshControl添加一个刷新方法
        refreshControl.addTarget(self, action: #selector(ViewController.refreshAction), for: .valueChanged)
        // 把refreshControl添加到picCollectionView
        picCollectionView.addSubview(refreshControl)
        // 即使picCollectionView的内容没有占满整个CollectionView也可以实现下拉
        picCollectionView.alwaysBounceVertical = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        NSLog("---------------Memory Warning---------------");
        // 清理图片缓冲池
        imageCache.removeAll()
        // 清理下载操作缓冲池
        operationCache.removeAll()
        // 取消所有的下载操作
        queue.cancelAllOperations()
    }
    
    
    func refreshAction() {
        picCollectionView.reloadData()
        refreshControl.endRefreshing()
    }
    

    
    // MARK: - UIScrollViewDelegate
    
    // 当开始滚动视图时，执行该方法。一次有效滑动（开始滑动，滑动一小段距离，只要手指不松开，只算一次滑动），只执行一次
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        NSLog("---------------视图开始滚动---------------")
        
        isScrolling = true
        // 清理下载操作缓冲池
        operationCache.removeAll()
        // 取消所有的下载操作
        queue.cancelAllOperations()
    }
    
    // 滑动视图，当手指离开屏幕那一霎那，调用该方法。一次有效滑动，只执行一次
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        NSLog("---------------手指离开屏幕---------------")
        
        // 如果当手指离开那一瞬后，视图已经停止滚动
        if !decelerate {
            NSLog("---------------视图停止滚动---------------");
            
            isScrolling = false
            picCollectionView.reloadData()
        }
    }

    // 滚动视图减速完成，滚动将停止时，调用该方法。一次有效滑动，只执行一次
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        NSLog("---------------视图停止滚动---------------")
        
        isScrolling = false
        picCollectionView.reloadData()
    }

    // 指示当用户点击状态栏后，滚动视图是否能够滚动到顶部
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        return true
    }
    
    // 当滚动视图滚动到最顶端后，执行该方法
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        NSLog("---------------视图滚动至顶部---------------")
        
        isScrolling = false
        // 防止有过多图片尚未加载但立即返回顶部导致下载操作过多
        operationCache.removeAll()
        queue.cancelAllOperations()
    }
    

    // MARK: - UICollectionViewDataSource
    
    // 每个section的item个数
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return picArray.count
    }
    
    // 设置每个item
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // 重用队列标识
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "picCellId", for: indexPath) as! PicCollectionViewCell
        
        // 获取文件的下载地址和文件名
        let imageSrc = picArray[indexPath.row]
        // 网址通过斜杠分割后的最后一个元素即为图片名
        let fileName = imageSrc.components(separatedBy: "/").last!

        
        // 首先判断内存缓存内部是否有图片对象
        if let image = imageCache[fileName] {
            cell.imageView.image = image
            cell.filenameLabel.text = fileName
            return cell
        }
        
        // 判断Caches目录下是否存在该图片
        let filePath = String(format: "%@/%@", kPathCache, fileName)
        // 若存在，则加载后直接返回该cell
        if let image = UIImage(contentsOfFile: filePath) {
            NSLog("第%ld张图片%@存在，从沙盒加载", indexPath.row, fileName);
            
            // 在内存中保存一份
            imageCache.updateValue(image, forKey: fileName)
            // 从Caches文件夹直接读取并加载
            cell.imageView.image = image;
            cell.filenameLabel.text = fileName;
            
            return cell;
        }

        // 若不存在，则先设置占位图
        NSLog("第%ld张图片%@不存在，先设置占位图", indexPath.row, fileName);
        cell.imageView.image = #imageLiteral(resourceName: "placeholder.png")
        cell.filenameLabel.text = fileName
        
        // 只有在不下载且页面不在滚动时才刷新cell
        if (self.operationCache[fileName] == nil) && !isScrolling {
            NSLog("第%ld张图片%@不在下载，且页面不在滚动，开始下载", indexPath.row, fileName);
            
            // 创建异步下载操作
            let op = BlockOperation(block: {
                // 模拟5秒的网络延迟
//                if (indexPath.row > 9) {
//                    Thread.sleep(forTimeInterval: 5.0)
//                }

                // 下载图片
                let imageSrc = self.picArray[indexPath.row]
                let url = URL(string: imageSrc)
                let data = try? Data(contentsOf: url!)
                
                // 如果下载成功
                if data != nil {
                    if let image = UIImage(data: data!) {
                        NSLog("第%ld张图片%@下载成功，刷新对应cell", indexPath.row, fileName);
                        // 保存图片到图片缓存池
                        self.imageCache.updateValue(image, forKey: fileName)
                        // 保存至Caches目录下
                        let imagePath = URL(fileURLWithPath: filePath)
                        try? data!.write(to: imagePath)
                    }
                }
                    
                // 如果下载失败
                else {
                    NSLog("第%ld张图片%@下载失败，尝试重新下载", indexPath.row, fileName);
                }
                
                // 清理对应的下载操作
                self.operationCache.removeValue(forKey: fileName)
                
                // 无论是否下载成功都要回到主线程刷新对应的cell
                OperationQueue.main.addOperation({
                    self.picCollectionView.reloadItems(at: [indexPath])
                })
            })
            
            // 将下载操作添加到缓冲池
            operationCache.updateValue(op, forKey: fileName)
            
            // 将操作添加到队列，操作执行结束之后会自动从队列中移除
            queue.addOperation(op)
        }
        
        return cell;
    }
    
    // 返回分区个数
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
}

