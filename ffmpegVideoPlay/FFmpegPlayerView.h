//
//  FFmpegPlayerView.h
//  SameFunctionModules
//
//  Created by jian zhang on 2017/1/3.
//  Copyright © 2017年 jian zhang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FFmpegFrameModel.h"
#import "FFmpegPlayerDecoder.h"

@interface FFmpegPlayerView : UIView

@property (nonatomic) UIInterfaceOrientation interfaceOr;

- (id) initWithFrame:(CGRect)frame
             decoder: (FFmpegPlayerDecoder *) decoder;

- (void)appendVideoFrameModel:(FFmpegFrameModel *)model;

- (FFmpegFrameModel *)render;

- (void)cleanBuffer;

@end
