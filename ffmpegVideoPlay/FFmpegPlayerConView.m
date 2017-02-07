//
//  FFmpegPlayerConView.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/30.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "FFmpegPlayerConView.h"
#import <MediaPlayer/MediaPlayer.h>

#define DIF_ValueGap (0.01*3)
@interface  FFmpegPlayerConView()

@property (nonatomic, strong) UISlider *volumeViewSlider;

@end

typedef NS_ENUM(NSUInteger, ENUM_Pan_Move_Direction) {
    ENUM_Pan_Move_Direction_None,
    ENUM_Pan_Move_Direction_Up,
    ENUM_Pan_Move_Direction_Down,
    ENUM_Pan_Move_Direction_Left,
    ENUM_Pan_Move_Direction_Right
};

@implementation FFmpegPlayerConView
{
    UIButton *m_BackButton;
    UILabel *m_ViewTitle;
    UILabel *m_PlayedValue;
    UILabel *m_allValue;
    UIProgressView *m_ProgressView;
    UIButton *m_PlayButton;
    CGPoint m_touchBegin;
    CGPoint m_OldTranslation;
    CGFloat m_CurrentLight;
    CGFloat m_CurrentVolume;
    CGFloat m_ProgressValue;
    CGFloat m_Duration;
    CGFloat m_PlayedSec;
    CGFloat m_isSetPosition;
}

- (UISlider *)volumeViewSlider
{
    if (_volumeViewSlider)
    {
        return _volumeViewSlider;
    }
    MPVolumeView *slide = [MPVolumeView new];
    for(UIView *view in[slide subviews])
    {
        if([[[view class] description] isEqualToString:@"MPVolumeSlider"])
        {
            _volumeViewSlider = (UISlider *)view;
            break;
        }
    }
    return _volumeViewSlider;
}

- (instancetype) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self initViewGestureRecognizer];
        [self initSubButtonsWithFrame:frame];
        [self initSubTitleViewsWithFrame:frame];
        m_ProgressValue = 0.f;
        m_ProgressView = [[UIProgressView alloc] initWithFrame:CGRectMake(80, frame.size.height - 20, frame.size.width-80*2, 20)];
        [m_ProgressView setProgress:m_ProgressValue];
        [self addSubview:m_ProgressView];
    }
    return self;
}

- (void)initSubButtonsWithFrame:(CGRect)frame
{
    m_BackButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [m_BackButton setFrame:CGRectMake(10, 25, 34, 34)];
    [m_BackButton setImage:[UIImage imageNamed:@"icon_back"] forState:UIControlStateNormal];
    [m_BackButton addTarget:self
                     action:@selector(FFmpegPlayerConViewBackAction)
           forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:m_BackButton];
    
    
    m_PlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [m_PlayButton setFrame:CGRectMake(0, 0, 60, 60)];
    [m_PlayButton setCenter:self.center];
    [m_PlayButton setImage:[UIImage imageNamed:@"playback_play"] forState:UIControlStateNormal];
    [m_PlayButton setSelected:YES];
    [m_PlayButton addTarget:self
                     action:@selector(FFmpegPlayerConViewPlayAction)
           forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:m_PlayButton];
}

- (void)initSubTitleViewsWithFrame:(CGRect)frame
{
    CGFloat offset_w = (frame.size.width - (20+34)*2);
    m_ViewTitle = [[UILabel alloc] initWithFrame:CGRectMake(20+34, 25, offset_w, 34)];
    [m_ViewTitle setTextColor:[UIColor whiteColor]];
    [m_ViewTitle setBackgroundColor:[UIColor clearColor]];
    [m_ViewTitle setFont:[UIFont systemFontOfSize:20]];
    [m_ViewTitle setTextAlignment:NSTextAlignmentCenter];
    [m_ViewTitle setText:@"Video Title"];
    [self addSubview:m_ViewTitle];
    
    m_PlayedValue = [[UILabel alloc] initWithFrame:CGRectMake(10, frame.size.height - 30, 60, 20)];
    [m_PlayedValue setTextColor:[UIColor whiteColor]];
    [m_PlayedValue setBackgroundColor:[UIColor clearColor]];
    [m_PlayedValue setFont:[UIFont systemFontOfSize:10]];
    [m_PlayedValue setTextAlignment:NSTextAlignmentCenter];
    [m_PlayedValue setText:@"00:00"];
    [self addSubview:m_PlayedValue];
    
    m_allValue = [[UILabel alloc] initWithFrame:CGRectMake(frame.size.width-10-60, frame.size.height - 30, 60, 20)];
    [m_allValue setTextColor:[UIColor whiteColor]];
    [m_allValue setBackgroundColor:[UIColor clearColor]];
    [m_allValue setFont:[UIFont systemFontOfSize:10]];
    [m_allValue setTextAlignment:NSTextAlignmentCenter];
    [m_allValue setText:@"00:00"];
    [self addSubview:m_allValue];
}

- (void)initViewGestureRecognizer
{
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(panGestureRecognizerAction:)];
    [self addGestureRecognizer:panGR];
}

- (void)drawRect:(CGRect)rect
{
    NSLog(@"drawRect %@",[NSValue valueWithCGRect:rect]);
    [m_PlayButton setCenter:self.center];
    CGFloat offset_w = (rect.size.width - (20+34)*2);
    [m_ViewTitle setFrame:CGRectMake(20+34, 25, offset_w, 34)];
    [m_PlayedValue setFrame:CGRectMake(10, rect.size.height - 30, 60, 20)];
    [m_allValue setFrame:CGRectMake(rect.size.width-10-60, rect.size.height - 30, 60, 20)];
    [m_ProgressView setFrame:CGRectMake(80, rect.size.height - 20, rect.size.width-80*2, 20)];
}

#pragma mark - Set Values

- (void)setViewTitile:(NSString *)title
{
    [m_ViewTitle setText:title];
    
    NSInteger fontValue = 20;
    while (1)
    {
        CGSize textSize = [title sizeWithAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:fontValue]}];
        if (textSize.width < m_ViewTitle.frame.size.width - 20)
        {
            break;
        }
        fontValue--;
    }
    [m_ViewTitle setFont:[UIFont systemFontOfSize:fontValue]];
}

- (void)setDurationTitle:(float)duration
{
    m_Duration = duration;
    int iDu = (int)duration;
    float fDu = duration - iDu;
    (fDu >= 0.5)?(iDu++):(iDu);
    NSDateFormatter *dateFormate = [[NSDateFormatter alloc] init];
    if (iDu >= 60*60)
    {
        [dateFormate setDateFormat:@"HH:mm:ss"];
    }
    else
    {
        [dateFormate setDateFormat:@"mm:ss"];
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:iDu];
    NSString *dateStr = [dateFormate stringFromDate:date];    
    [m_allValue setText:dateStr];
}

- (void)setplayedSeconds:(float)seconds
{
    m_PlayedSec = seconds;
    CGFloat proValue = seconds/m_Duration;
    if (proValue == 1)
    {
        [self FFmpegPlayerConViewPlayAction];
    }
    [self setViewProgressValue:proValue];
    int iDu = (int)seconds;
    float fDu = seconds - iDu;
    (fDu >= 0.5)?(iDu++):(iDu);
    NSDateFormatter *dateFormate = [[NSDateFormatter alloc] init];
    if (iDu >= 60*60)
    {
        [dateFormate setDateFormat:@"HH:mm:ss"];
    }
    else
    {
        [dateFormate setDateFormat:@"mm:ss"];
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:iDu];
    NSString *dateStr = [dateFormate stringFromDate:date];
    [m_PlayedValue setText:dateStr];
}

- (void)setViewProgressValue:(CGFloat)value
{
    [m_ProgressView setProgress:value];
}

#pragma mark - Button Actions

- (void)FFmpegPlayerConViewBackAction
{
    if (self.backBlock)
    {
        self.backBlock();
    }
}

- (void)FFmpegPlayerConViewPlayAction
{
    [m_PlayButton setSelected:!m_PlayButton.selected];
    [m_PlayButton setImage:[UIImage imageNamed:(m_PlayButton.selected?@"playback_play":@"playback_pause")]
                  forState:UIControlStateNormal];
    if (self.playBlock)
    {
        self.playBlock(m_PlayButton.selected);
    }
}

#pragma mark - GestureRecognizer Action

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    m_isSetPosition = NO;
    m_touchBegin = [touches.anyObject locationInView:self];
    m_CurrentLight = [[UIScreen mainScreen] brightness];
    m_CurrentVolume = self.volumeViewSlider.value;
}

- (void)panGestureRecognizerAction:(UIPanGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateChanged)
    {
        // ok, now initiate movement in the direction indicated by the user's gesture
        
        switch ([self getPanGestureRecogizerDirection:gesture])
        {
            case ENUM_Pan_Move_Direction_Up:
                [self setGestureRecognizerUpDownValue:YES];
                break;
            case ENUM_Pan_Move_Direction_Down:
                [self setGestureRecognizerUpDownValue:NO];
                break ;
            case ENUM_Pan_Move_Direction_Left:
                [self setGestureRecognizerLeftRightValue:YES];
                break ;
            case ENUM_Pan_Move_Direction_Right:
                [self setGestureRecognizerLeftRightValue:NO];
                break ;
            default :
                break ;
        }
    }
    else if (gesture.state == UIGestureRecognizerStateEnded)
    {        
        if (m_isSetPosition && self.positionBlock)
        {
            self.positionBlock(m_PlayedSec);
        }
    }
}

- (ENUM_Pan_Move_Direction)getPanGestureRecogizerDirection:(UIPanGestureRecognizer *)gesture
{
    ENUM_Pan_Move_Direction panMove = ENUM_Pan_Move_Direction_None;
    CGFloat const gestureMinimumTranslation = 20.f ;
    if (gesture.state == UIGestureRecognizerStateChanged)
    {
        CGPoint translation = [gesture translationInView:self];
        NSLog(@"\n\n%@    %@\n\n",[NSValue valueWithCGPoint:translation],[NSValue valueWithCGPoint:m_OldTranslation]);
        NSLog(@"\n\n%f    %f\n\n",(fabs(translation.x) - fabs(m_OldTranslation.x)),((translation.y) - (m_OldTranslation.y)));
        if (fabs(fabs(translation.x) - fabs(m_OldTranslation.x)) > gestureMinimumTranslation)
        {
            BOOL gestureHorizontal = NO;
            if (translation.y == 0.0 )
                gestureHorizontal = YES;
            else
                gestureHorizontal = (fabs(translation.x / translation.y) > 5.0 );
            
            if (gestureHorizontal)
            {
                if (translation.x > 0.0 )
                    panMove = ENUM_Pan_Move_Direction_Right;
                else
                    panMove = ENUM_Pan_Move_Direction_Left;
            }
            else
            {
                panMove = ENUM_Pan_Move_Direction_None;
            }
            m_OldTranslation = translation;
        }
        else if (fabs(fabs(translation.y) - fabs(m_OldTranslation.y)) > gestureMinimumTranslation)
        {
            BOOL gestureVertical = NO;
            if (translation.x == 0.0 )
                gestureVertical = YES;
            else
                gestureVertical = (fabs(translation.y / translation.x) > 5.0 );
            
            if (gestureVertical)
            {
                if (translation.y > m_OldTranslation.y)
                    panMove = ENUM_Pan_Move_Direction_Down;
                else
                    panMove = ENUM_Pan_Move_Direction_Up;
            }
            else
            {
                panMove = ENUM_Pan_Move_Direction_None;
            }
            m_OldTranslation = translation;
        }
    }
    return panMove;
}

- (void)setGestureRecognizerUpDownValue:(BOOL)isUp
{
    if (m_touchBegin.x < self.center.x)
    {
        if (isUp)
        {
            m_CurrentLight < 1 ?(m_CurrentLight += DIF_ValueGap) : (m_CurrentLight = 1);
        }
        else
        {
            m_CurrentLight > 0 ?(m_CurrentLight -= DIF_ValueGap) : (m_CurrentLight = 0);
        }
        [[UIScreen mainScreen] setBrightness: m_CurrentLight];
    }
    else
    {
        if (isUp)
        {
            m_CurrentVolume < 1 ?(m_CurrentVolume += DIF_ValueGap) : (m_CurrentVolume = 1);
        }
        else
        {
            m_CurrentVolume > 0 ?(m_CurrentVolume -= DIF_ValueGap) : (m_CurrentVolume = 0);
        }
        [self.volumeViewSlider setValue:m_CurrentVolume];
    }
}

- (void)setGestureRecognizerLeftRightValue:(BOOL)isLeft
{
    m_isSetPosition = YES;
    if (m_isSetPosition && self.positionBlock)
    {
        self.positionBlock(-1);
    }
    if (isLeft)
    {
        m_PlayedSec > 0 ?(m_PlayedSec -= DIF_ValueGap*10) : (m_PlayedSec = 0);
    }
    else
    {
        m_PlayedSec < m_Duration-0.5 ?(m_PlayedSec += DIF_ValueGap*10) : (m_PlayedSec = m_Duration-0.5);
    }
    [self setViewProgressValue:m_PlayedSec/m_Duration];
    [self setplayedSeconds:m_PlayedSec];
}

@end
