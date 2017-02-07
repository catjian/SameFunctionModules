//
//  InsertImageIntoMovie.h
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/26.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void(^InsertImageIntoMovieSuccessBlock)(NSURL *assetURL);

@interface InsertImageIntoMovie : NSObject

+ (InsertImageIntoMovie *)sharedInsertImageIntoMovie;

/**
  插入一张图片到视频中

 @param url 视频路径 不能为空
 @param image 图片
 @param size 显示图片的size
 @param alpha 图片的透明度
 */
- (void)insertIntoMovieWithUrl:(NSURL *)url Image:(UIImage *)image ImageSize:(CGSize)size ImageAlpha:(CGFloat)alpha successBlock:(InsertImageIntoMovieSuccessBlock)block;
@end
