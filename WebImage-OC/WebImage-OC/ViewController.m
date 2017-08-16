//
//  ViewController.m
//  WebImage-OC
//
//  Created by Neil Steven on 2017/8/13.
//  Copyright © 2017年 Neil Steven. All rights reserved.
//

#import "ViewController.h"
#import "PicCollectionViewCell.h"


@interface ViewController ()

// 页面滚动标记
@property Boolean isScrolling;

@end


@implementation ViewController

LAZY_LOAD(NSOperationQueue, queue)
LAZY_LOAD(NSMutableDictionary, imageCache)
LAZY_LOAD(NSMutableDictionary, operationCache)

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.title = @"WebImage demo";

    // 1.初始化layout
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    
    // 2.初始化collectionView
    self.picCollectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:layout];
    self.picCollectionView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.picCollectionView];
    
    // 3.注册collectionViewCell
    [self.picCollectionView registerClass:[PicCollectionViewCell class] forCellWithReuseIdentifier:@"picCellId"];

    // 4.设置代理
    self.picCollectionView.delegate = self;
    self.picCollectionView.dataSource = self;
    self.picCollectionView.frame = [UIScreen mainScreen].bounds;
    

    // 控制台打印App根目录
    NSLog(@"Home directory: %@", NSHomeDirectory());

    // 初始化isScrolling为NO
    _isScrolling = NO;
    
    // 初始化picArray数据源
    self.picArray = [NSMutableArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pic-large" ofType:@"plist"]];
    
    // 设置下载并发数
    self.queue.maxConcurrentOperationCount = 10;
    

    // 初始化refreshControl
    self.refreshControl = [[UIRefreshControl alloc] init];
    // 设置刷新控件的颜色
    self.refreshControl.tintColor = [UIColor blueColor];
    // 设置刷新控件下边的提示文字及文字的颜色
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"下拉刷新"];
    // 给refreshControl添加一个刷新方法
    [self.refreshControl addTarget:self action:@selector(refreshAction) forControlEvents:UIControlEventValueChanged];
    // 把refreshControl添加到picCollectionView
    [self.picCollectionView addSubview:self.refreshControl];
    // 即使picCollectionView的内容没有占满整个CollectionView也可以实现下拉
    self.picCollectionView.alwaysBounceVertical = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];

    NSLog(@"---------------Memory Warning---------------");
    // 清理图片缓冲池
    [self.imageCache removeAllObjects];
    // 清理下载操作缓冲池
    [self.operationCache removeAllObjects];
    // 取消所有的下载操作
    [self.queue cancelAllOperations];
}

-(void)refreshAction {
    // 刷新表格
    [self.picCollectionView reloadData];
    
    // 结束刷新
    [self.refreshControl endRefreshing];
}



#pragma mark - UIScrollViewDelegate

// 当开始滚动视图时，执行该方法。一次有效滑动（开始滑动，滑动一小段距离，只要手指不松开，只算一次滑动），只执行一次
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    NSLog(@"---------------视图开始滚动---------------");
    
    _isScrolling = YES;
    // 清理下载操作缓冲池
    [self.operationCache removeAllObjects];
    // 取消所有的下载操作
    [self.queue cancelAllOperations];
}

// 滑动视图，当手指离开屏幕那一霎那，调用该方法。一次有效滑动，只执行一次
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
    NSLog(@"---------------手指离开屏幕---------------");
    
    // 如果当手指离开那一瞬后，视图已经停止滚动
    if (!decelerate) {
        NSLog(@"---------------视图停止滚动---------------");
        
        _isScrolling = NO;
        [self.picCollectionView reloadData];
    }
}

// 滚动视图减速完成，滚动将停止时，调用该方法。一次有效滑动，只执行一次
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSLog(@"---------------视图停止滚动---------------");
    
    _isScrolling = NO;
    [self.picCollectionView reloadData];
}

// 指示当用户点击状态栏后，滚动视图是否能够滚动到顶部
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView{
    return YES;
}

// 当滚动视图滚动到最顶端后，执行该方法
- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView{
    NSLog(@"---------------视图滚动至顶部---------------");
    
    _isScrolling = NO;
    // 防止有过多图片尚未加载但立即返回顶部导致下载操作过多
    [self.operationCache removeAllObjects];
    [self.queue cancelAllOperations];
}



#pragma mark - UICollectionViewDataSource

// 每个section的item个数
-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.picArray.count;
}

// 设置每个item
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    // 重用队列标识
    PicCollectionViewCell *cell = (PicCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"picCellId" forIndexPath:indexPath];
    
    // 获取文件的下载地址和文件名
    NSString *imageSrc = self.picArray[indexPath.row];
    NSArray *p = [imageSrc componentsSeparatedByString:@"/"];
    // 网址通过斜杠分割后的最后一个元素即为图片名
    NSString *fileName = [NSString stringWithFormat:@"%@", p.lastObject];
    
    // 首先判断内存缓存内部是否有图片对象
    if ([self.imageCache objectForKey:fileName]) {
        NSLog(@"第%ld张图片%@存在，从内存加载", (long)indexPath.row, fileName);
        cell.imageView.image = [self.imageCache objectForKey:fileName];
        cell.filenameLabel.text = fileName;
        return cell;
    }
    
    // 判断Caches目录下是否存在该图片
    NSString *filePath = [NSString stringWithFormat:@"%@/%@", kPathCache, fileName];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    UIImage *image = [UIImage imageWithData:data];
    
    // 若存在，则加载后直接返回该cell
    if (image) {
        NSLog(@"第%ld张图片%@存在，从沙盒加载", (long)indexPath.row, fileName);
        // 在内存中保存一份
        [self.imageCache setObject:image forKey:fileName];
        // 从Caches文件夹直接读取并加载
        cell.imageView.image = image;
        cell.filenameLabel.text = fileName;
        
        return cell;
    }
    
    // 若不存在，则先设置占位图
    NSLog(@"第%ld张图片%@不存在，先设置占位图", (long)indexPath.row, fileName);
    cell.imageView.image = [UIImage imageNamed:@"placeholder"];
    cell.filenameLabel.text = fileName;

    // 只有在不下载且页面不在滚动时才刷新cell
    if (![self.operationCache objectForKey:fileName] && !_isScrolling) {
        NSLog(@"第%ld张图片%@不在下载，且页面不在滚动，开始下载", (long)indexPath.row, fileName);

        // 可以及时地解除循环引用
        WeakSelf(self);
        // 创建异步下载操作
        NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
            // 模拟5秒的网络延迟
//            if (indexPath.row > 9) {
//                [NSThread sleepForTimeInterval:5.0];
//            }
            
            // 下载图片
            NSString *imageSrc = self.picArray[indexPath.row];
            NSURL *url = [NSURL URLWithString:imageSrc];
            NSData *data = [NSData dataWithContentsOfURL:url];
            UIImage *image = [UIImage imageWithData:data];
            
            // 如果下载成功
            if (image) {
                NSLog(@"第%ld张图片%@下载成功，刷新对应cell", (long)indexPath.row, fileName);
                // 保存图片到图片缓存池
                [weakself.imageCache setObject:image forKey:fileName];
                // 保存至Caches目录下
                NSString *imagePath = [kPathCache stringByAppendingPathComponent:fileName];
                [data writeToFile:imagePath atomically:YES];
                // 清理对应的下载操作，也可以解除循环引用
                [weakself.operationCache removeObjectForKey:fileName];
            }
            // 如果下载失败
            else {
                NSLog(@"第%ld张图片%@下载失败，尝试重新下载", (long)indexPath.row, fileName);
                // 清理对应的下载操作
                if ([weakself.operationCache objectForKey:fileName])
                    [weakself.operationCache removeObjectForKey:fileName];
            }
            
            // 无论是否下载成功都要回到主线程刷新对应的cell
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [weakself.picCollectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:indexPath.row inSection:0]]];
            }];
        }];
        
        // 将下载操作添加到缓冲池
        [self.operationCache setObject:op forKey:fileName];
        // 将操作添加到队列，操作执行结束之后会自动从队列中移除，一旦移除就解除了循环引用
        [self.queue addOperation:op];
    }
    
    return cell;
}

// 返回分区个数
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}



#pragma mark - UICollectionViewDelegateFlowLayout

// 设置每个item的尺寸
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(CELL_WIDTH, CELL_HEIGHT);
}

// 设置每个item的UIEdgeInsets
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(15, 15, 15, 15);
}

// 设置每个item水平间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 15;
}

// 设置每个item垂直间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 15;
}


@end
