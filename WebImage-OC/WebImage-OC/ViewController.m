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

// 下载未完成时的占位图
@property UIImage *placeholder;
// 页面滚动标记
@property Boolean isScrolling;
// 记录上一次的Y轴偏移量（用以计算滚动速度）
@property CGFloat lastContentOffsetY;

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
    
    
    _placeholder = [self createImageWithColor:[UIColor lightGrayColor]];
    _isScrolling = NO;
    _lastContentOffsetY = 0;
    
    self.picArray = [NSMutableArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"pictures" ofType:@"plist"]];
    self.queue.maxConcurrentOperationCount = 10;
    
    
    // 初始化refreshControl
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor blueColor];
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"下拉刷新"];
    [self.refreshControl addTarget:self action:@selector(refreshAction) forControlEvents:UIControlEventValueChanged];
    [self.picCollectionView addSubview:self.refreshControl];
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

// 通过颜色来生成一个纯色图片
- (UIImage *)createImageWithColor:(UIColor *)color{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}



#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.y - _lastContentOffsetY > 10) {
        if (_isScrolling == NO) {
            [self.operationCache removeAllObjects];
            [self.queue cancelAllOperations];
            _isScrolling = YES;
        }
    } else {
        if (_isScrolling == YES) {
            [self.picCollectionView reloadData];
            _isScrolling = NO;
        }
    }
    
    _lastContentOffsetY = scrollView.contentOffset.y;
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
    cell.imageView.image = _placeholder;
    cell.filenameLabel.text = fileName;
    
    // 为cell的imageView添加一个activityIndicator
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityIndicator.frame = CGRectMake(cell.imageView.frame.size.width/2 - 30, cell.imageView.frame.size.height/2 - 30, 60, 60);
    [cell.imageView addSubview:activityIndicator];
    [activityIndicator startAnimating];
    
    // 只有在不下载且页面不在快速滚动时才刷新cell
    if (![self.operationCache objectForKey:fileName] && !_isScrolling) {
        NSLog(@"第%ld张图片%@不在下载，且页面不在快速滚动，开始下载", (long)indexPath.row, fileName);
        
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
                
                // 移除activityIndicator
                for (id subview in [cell.imageView subviews]) {
                    // 找到要删除的子视图的对象
                    if ([subview isKindOfClass:[UIActivityIndicatorView class]]) {
                        UIActivityIndicatorView *indicatorView = (UIActivityIndicatorView *)subview;
                        [indicatorView removeFromSuperview];
                        break;
                    }
                }
            }
            
            // 如果下载失败
            else {
                NSLog(@"第%ld张图片%@下载失败，尝试重新下载", (long)indexPath.row, fileName);
            }
            
            // 清理对应的下载操作
            if ([weakself.operationCache objectForKey:fileName])
                [weakself.operationCache removeObjectForKey:fileName];
            
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
    return UIEdgeInsetsMake(10, 10, 10, 10);
}

// 设置每个item水平间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}

// 设置每个item垂直间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 10;
}


@end
