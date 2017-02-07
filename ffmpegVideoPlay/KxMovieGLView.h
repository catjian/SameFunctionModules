//
//  ESGLView.h
//  kxmovie
//
//  Created by Kolyvan on 22.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt

#import <UIKit/UIKit.h>
#import "FFmpegFrameModel.h"
#import "FFmpegPlayerDecoder.h"

@class KxVideoFrame;
@class KxMovieDecoder;

@interface KxMovieGLView : UIView

- (id) initWithFrame:(CGRect)frame
             decoder: (FFmpegPlayerDecoder *) decoder;

- (void) render: (FFmpegFrameModel *) frame;

@end
