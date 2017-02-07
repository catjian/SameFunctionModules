//
//  FFmpegPlayerAudioManager.h
//  SameFunctionModules
//
//  Created by jian zhang on 2017/1/6.
//  Copyright © 2017年 jian zhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFmpegFrameModel.h"

@protocol FFmpegPlayerAudioManager <NSObject>

@property (nonatomic) UInt32 numOutputChannels;
@property (nonatomic) Float64 samplingRate;
@property (nonatomic) UInt32 numBytesPerSample;
@property (nonatomic) BOOL isPlaying;
@property (nonatomic, strong) NSString *audioRoute;
@property (nonatomic) CGFloat playedPostion;

- (BOOL)activateAudioSession;
- (void)deactivateAudioSession;
- (BOOL)play;
- (void)pause:(BOOL)isClear;

- (void)appendAudioFrameModel:(FFmpegAudioFrameModel *)model;

@end

@interface FFmpegPlayerAudioManager : NSObject

+ (id<FFmpegPlayerAudioManager>)sharedAudioManager;

@end
