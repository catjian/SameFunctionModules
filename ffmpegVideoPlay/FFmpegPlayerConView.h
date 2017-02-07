//
//  FFmpegPlayerConView.h
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/30.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^FFmpegPlayerConViewBackButtonBlock)(void);
typedef void(^FFmpegPlayerConViewPlayButtonBlock)(BOOL);
typedef void(^FFmpegPlayerConViewSetPositionBlock)(CGFloat);

@interface FFmpegPlayerConView : UIView

@property (nonatomic, copy) FFmpegPlayerConViewBackButtonBlock backBlock;
@property (nonatomic, copy) FFmpegPlayerConViewPlayButtonBlock playBlock;
@property (nonatomic, copy) FFmpegPlayerConViewSetPositionBlock positionBlock;

- (void)setViewTitile:(NSString *)title;

- (void)setDurationTitle:(float)duration;

- (void)setplayedSeconds:(float)seconds;

@end
