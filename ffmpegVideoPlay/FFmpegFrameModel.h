//
//  FFmpegFrameModel.h
//  SameFunctionModules
//
//  Created by jian zhang on 2017/1/4.
//  Copyright © 2017年 jian zhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum {
    FFmpegFrameTypeAudio,
    FFmpegFrameTypeVideo,
    
} FFmpegFrameType;

typedef enum {
    FFmpegVideoFrameFormatRGB,
    FFmpegVideoFrameFormatYUV,
} FFmpegVideoFrameFormat;

@interface FFmpegFrameModel : NSObject

@property (nonatomic) FFmpegFrameType type;
@property (nonatomic) FFmpegVideoFrameFormat format;
@property (nonatomic) NSUInteger width;
@property (nonatomic) NSUInteger height;
@property (nonatomic) CGFloat position;
@property (nonatomic) CGFloat duration;
@property (nonatomic) UInt8 *rgbData;

@end

@interface FFmpegVideoFrameModelRGB : FFmpegFrameModel
@property (nonatomic) NSUInteger linesize;
@property (nonatomic, strong) NSData *rgb;
- (UIImage *) asImage;
@end

@interface FFmpegVideoFrameModelYUV : FFmpegFrameModel
@property (nonatomic, strong) NSData *luma;
@property (nonatomic, strong) NSData *chromaB;
@property (nonatomic, strong) NSData *chromaR;
@end

@interface FFmpegAudioFrameModel : FFmpegFrameModel
@property (nonatomic, strong) NSData *samples;
@end
