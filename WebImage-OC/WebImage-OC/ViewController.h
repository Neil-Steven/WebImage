//
//  ViewController.h
//  WebImage-OC
//
//  Created by Neil Steven on 2017/8/13.
//  Copyright © 2017年 Neil Steven. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate>

// CollectionView
@property (strong, nonatomic) UICollectionView *picCollectionView;

// 图片的数据源
@property (strong, nonatomic) NSMutableArray *picArray;
// 下载操作队列
@property (strong, nonatomic) NSOperationQueue *queue;
// 图片缓存池
@property (strong, nonatomic) NSMutableDictionary *imageCache;
// 下载操作缓冲池
@property (strong, nonatomic) NSMutableDictionary *operationCache;

// 下拉刷新控件
@property (strong, nonatomic) UIRefreshControl *refreshControl;

@end
