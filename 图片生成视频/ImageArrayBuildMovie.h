//
//  ImageArrayBuildMovie.h
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/26.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void(^ImageArrayBuildMovieSuccessBlock)(NSURL *assetURL);

@interface ImageArrayBuildMovie : NSObject

+ (ImageArrayBuildMovie *)sharedImageArrayBuildMovie;

/**
 通过图片集合创建视频

 @param imagesArray 图片集合
 @param size 视频尺寸
 @param duration 视频时长
 */
- (void)BuildMovieWithImages:(NSArray *)imagesArray videoSize:(CGSize)size videoDuration:(float)duration successBlock:(ImageArrayBuildMovieSuccessBlock)block;
@end
