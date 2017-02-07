//
//  FFmpegPlayerDecoder.h
//  SameFunctionModules
//
//  Created by jian zhang on 2017/1/3.
//  Copyright © 2017年 jian zhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFmpegFrameModel.h"
#import "FFmpegPlayerAudioManager.h"

typedef void(^FFmpegPlayerDecoderGetVideoInfoBlock)(BOOL);

typedef void(^FFmpegPlayerDecoderDecodeVideoBlock)(FFmpegFrameModel *frameModel);
typedef void(^FFmpegPlayerDecoderDecodeAudioBlock)(FFmpegAudioFrameModel *frameModel);

@interface FFmpegPlayerDecoder : NSObject

@property (nonatomic, copy) FFmpegPlayerDecoderGetVideoInfoBlock getVideoInfoBlock;
@property (nonatomic, copy) FFmpegPlayerDecoderDecodeVideoBlock decodeVideoBlock;
@property (nonatomic, copy) FFmpegPlayerDecoderDecodeAudioBlock decodeAudioBlock;

@property (nonatomic) float position;
@property (nonatomic) float duration;
@property (nonatomic) int frameWidth;
@property (nonatomic) int frameHeight;
@property (nonatomic) float videoFPS;

- (void)FFmpegDecodeWithFilePath:(NSString *)path;

- (void)DecodeFromStream:(CGFloat)minDuration;

@end
