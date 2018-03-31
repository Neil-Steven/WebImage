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
    
    // 下载未完成时的占位图
    var placeholder : UIImage!
    // 页面滚动标记
    var isScrolling = false
    // 记录上一次的Y轴偏移量（用以计算滚动速度）
    var lastContentOffsetY : CGFloat = 0
    
    
    
    // MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 控制台打印App根目录
        NSLog("Home directory: %@", NSHomeDirectory());
        
        // 初始化picCollectionView
        picCollectionView.delegate = self
        picCollectionView.dataSource = self
        picCollectionView.frame = UIScreen.main.bounds
        
        
        if let picPlistFile = Bundle.main.path(forResource: "pictures", ofType: "plist") {
            picArray = NSMutableArray(contentsOfFile: picPlistFile) as! Array<String>
        }
        
        self.queue.maxConcurrentOperationCount = 10;
        
        placeholder = createImage(with: UIColor.lightGray)
        
        // 设置refreshControl
        refreshControl.tintColor = UIColor.blue
        refreshControl.attributedTitle = NSAttributedString(string: "下拉刷新")
        refreshControl.addTarget(self, action: #selector(ViewController.refreshAction), for: .valueChanged)
        picCollectionView.addSubview(refreshControl)
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

    @objc func refreshAction() {
        picCollectionView.reloadData()
        refreshControl.endRefreshing()
    }

    // 通过颜色来生成一个纯色图片
    func createImage(with color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y - lastContentOffsetY > CGFloat(10) {
            if isScrolling == false {
                operationCache.removeAll()
                queue.cancelAllOperations()
                isScrolling = true
            }
        } else {
            if isScrolling == true {
                picCollectionView.reloadData()
                isScrolling = false
            }
        }
        
        lastContentOffsetY = scrollView.contentOffset.y
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
        cell.imageView.image = placeholder
        cell.filenameLabel.text = fileName
        
        // 为cell的imageView添加一个activityIndicator
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        activityIndicator.frame = CGRect(x: cell.imageView.frame.size.width/2 - 30, y: cell.imageView.frame.size.height/2 - 30, width: 60, height: 60)
        cell.imageView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        
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
                        
                        // 移除activityIndicator
                        for subview in cell.imageView.subviews {
                            // 找到要删除的子视图的对象
                            if subview.isKind(of: UIActivityIndicatorView.self) {
                                let indicatorView = subview as! UIActivityIndicatorView
                                indicatorView.removeFromSuperview()
                                break
                            }
                        }
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
