//
//  FFmpegVideoFrameModel.m
//  SameFunctionModules
//
//  Created by jian zhang on 2017/1/4.
//  Copyright © 2017年 jian zhang. All rights reserved.
//

#import "FFmpegFrameModel.h"

@implementation FFmpegFrameModel

@end

@implementation FFmpegVideoFrameModelRGB

- (FFmpegVideoFrameFormat) format
{
    return FFmpegVideoFrameFormatRGB;
}

- (UIImage *) asImage
{
    UIImage *image = nil;
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)(_rgb));
    if (provider) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        if (colorSpace) {
            CGImageRef imageRef = CGImageCreate(self.width,
                                                self.height,
                                                8,
                                                24,
                                                self.linesize,
                                                colorSpace,
                                                kCGBitmapByteOrderDefault,
                                                provider,
                                                NULL,
                                                YES, // NO
                                                kCGRenderingIntentDefault);
            
            if (imageRef) {
                image = [UIImage imageWithCGImage:imageRef];
                CGImageRelease(imageRef);
            }
            CGColorSpaceRelease(colorSpace);
        }
        CGDataProviderRelease(provider);
    }
    
    return image;
}

@end

@implementation FFmpegVideoFrameModelYUV

- (FFmpegVideoFrameFormat) format
{
    return FFmpegVideoFrameFormatYUV;
}

@end

@implementation FFmpegAudioFrameModel

@end
