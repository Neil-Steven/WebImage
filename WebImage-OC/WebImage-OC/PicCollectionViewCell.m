//
//  PicCollectionViewCell.m
//  WebImage-OC
//
//  Created by Neil Steven on 2017/8/13.
//  Copyright © 2017年 Neil Steven. All rights reserved.
//

#import "PicCollectionViewCell.h"

@implementation PicCollectionViewCell

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, CELL_WIDTH, CELL_HEIGHT - 20)];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_imageView];
        
        _filenameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, CELL_HEIGHT - 20, CELL_WIDTH, 20)];
        _filenameLabel.textAlignment = NSTextAlignmentCenter;
        _filenameLabel.font = [UIFont systemFontOfSize:12];
        [self.contentView addSubview:_filenameLabel];
    }
    
    return self;
}

@end
