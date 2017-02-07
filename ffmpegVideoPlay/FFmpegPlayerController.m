//
//  FFmpegPlayerController.m
//  SameFunctionModules
//
//  Created by jian zhang on 2016/12/26.
//  Copyright © 2016年 jian zhang. All rights reserved.
//

#import "FFmpegPlayerController.h"
#import "FFmpegPlayerConView.h"
#import "FFmpegPlayerDecoder.h"
#import "FFmpegPlayerView.h"
#import "FFmpegPlayerAudioManager.h"
#import <Foundation/NSObjCRuntime.h>
//http://m9.play.vp.autohome.com.cn/flvs/B7823166A8F03C31/2017-02-06/A25A5EE927056AFE-100.mp4?key=2007AADDC7E922DCF213393C206602EC&time=1486458174

@interface FFmpegPlayerController ()

@property (nonatomic, strong) FFmpegPlayerView *PlayerView;

@end

@implementation FFmpegPlayerController
{
    FFmpegPlayerConView *m_ConView;
    FFmpegPlayerDecoder *m_Decoder;
    BOOL m_isHidden;
    BOOL m_isStart;
    dispatch_queue_t m_DecodeQueue;
    
    NSTimeInterval m_tickCorrectionTime;
    NSTimeInterval m_tickCorrectionPosition;
    CGFloat m_NowPosition;
    CGFloat m_IsPlay;
    CGFloat m_IsEnd;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (instancetype)init
{
    return [self initWithMoviePath:@"http://m9.play.vp.autohome.com.cn/flvs/B7823166A8F03C31/2017-02-06/A25A5EE927056AFE-100.mp4?key=2007AADDC7E922DCF213393C206602EC&time=1486458174"];
}

- (instancetype)initWithMoviePath:(NSString *)path
{
    self = [super initWithNibName:nil bundle:nil];
    if (self)
    {
        m_isStart = NO;
        m_IsPlay = YES;
        m_IsEnd = NO;
        m_DecodeQueue = dispatch_queue_create("com.FFmpegDecodeFromStream.thread", 0);
        [self loadVideoWithPath:path];
    }
    return self;
}

- (void)dealloc
{
    id<FFmpegPlayerAudioManager>  m_AudioManager = [FFmpegPlayerAudioManager sharedAudioManager];
    [m_AudioManager deactivateAudioSession];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor blackColor]];
    [self.navigationController setNavigationBarHidden:YES];
    
    m_isHidden = NO;
    __weak typeof(self) weakSelf = self;
        
    id<FFmpegPlayerAudioManager>  m_AudioManager = [FFmpegPlayerAudioManager sharedAudioManager];
    [m_AudioManager activateAudioSession];
    
    m_ConView = [[FFmpegPlayerConView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:m_ConView];
    [m_ConView setBackBlock:^{
        [weakSelf backButtonAction];
    }];
    [m_ConView setPlayBlock:^(BOOL isPlay){
        [weakSelf playAndPauseAction:isPlay];
    }];
    [m_ConView setPositionBlock:^(CGFloat position){
        [weakSelf setPositionAction:position];
    }];
    
    [self setNeedsStatusBarAppearanceUpdate];
    [self.navigationController.navigationBar setBarStyle:UIBarStyleDefault];
    
    
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                            action:@selector(tapGestureRecognizerAction:)];
    [self.view addGestureRecognizer:tapGR];
}

- (void)loadVideoWithPath:(NSString *)path
{
    __weak typeof(self) weakSelf = self;
    m_Decoder = [[FFmpegPlayerDecoder alloc] init];
    __block FFmpegPlayerDecoder *blockDecoder = m_Decoder;
    if (path)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                       dispatch_queue_create("com.FFmpegDecodeWithFilePath.thread", 0), ^{
                           [blockDecoder FFmpegDecodeWithFilePath:path];
                       });
    }
    else
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *outputURL = paths[0];
        NSFileManager *manager = [NSFileManager defaultManager];
        [manager createDirectoryAtPath:outputURL withIntermediateDirectories:YES attributes:nil error:nil];
        outputURL = [outputURL stringByAppendingPathComponent:@"1.mp4"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                       dispatch_queue_create("com.FFmpegDecodeWithFilePath.thread", 0), ^{
                           [blockDecoder FFmpegDecodeWithFilePath:outputURL];
        });
    }
    [m_Decoder setGetVideoInfoBlock:^(BOOL isSuccess){
        [weakSelf performSelectorOnMainThread:@selector(setPlayConViewValues) withObject:nil waitUntilDone:NO];
    }];
    
    [m_Decoder setDecodeVideoBlock:^(FFmpegFrameModel *frameModel){        
        [weakSelf.PlayerView appendVideoFrameModel:frameModel];
        [weakSelf startPlay];
    }];
    [m_Decoder setDecodeAudioBlock:^(FFmpegAudioFrameModel *frameModel){
        [[FFmpegPlayerAudioManager sharedAudioManager] appendAudioFrameModel:frameModel];
    }];
}

#pragma mark - Play Timer Control

- (void)startPlay
{
    if (!m_isStart)
    {
        m_isStart = YES;
        __weak typeof(self) weakSelf = self;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [weakSelf playTick];
        });
    }
}

- (void)playTick
{
    __weak typeof(self) weakSelf = self;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
    if (m_IsPlay)
    {
        FFmpegFrameModel *frame = [self.PlayerView render];
        if (m_NowPosition == 0)
        {
            [[FFmpegPlayerAudioManager sharedAudioManager] play];
        }
        if (frame)
        {
            m_NowPosition = frame.position;
        }
        [m_ConView setplayedSeconds:m_NowPosition];
        [[FFmpegPlayerAudioManager sharedAudioManager] setPlayedPostion:m_NowPosition];
        __block NSTimeInterval time = MAX(frame.duration, 0.01);    //frame.duration单包时长
        printf("time = %f\n\n", time);
        popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        frame = nil;
        m_NowPosition += time;
        if(m_NowPosition >= m_Decoder.duration)
        {
            m_IsPlay = NO;
            m_IsEnd = YES;
            m_NowPosition = m_Decoder.duration;
            [m_ConView setplayedSeconds:m_NowPosition];
            [[FFmpegPlayerAudioManager sharedAudioManager] pause:NO];
            return;
        }
        __block FFmpegPlayerDecoder *blockDecoder = m_Decoder;
        dispatch_async(m_DecodeQueue, ^{
            [blockDecoder DecodeFromStream:0.05];
        });
    }
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [weakSelf playTick];
    });
}

#pragma mark - View Control Action

- (void)setPlayConViewValues
{
    [m_ConView setDurationTitle:m_Decoder.duration];
    if (!self.PlayerView)
    {
        self.PlayerView = [[FFmpegPlayerView alloc] initWithFrame:self.view.bounds decoder:m_Decoder];
        [self.view addSubview:self.PlayerView];
        [self.view sendSubviewToBack:self.PlayerView];
    }
}

- (void)backButtonAction
{
    [self.navigationController setNavigationBarHidden:NO];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)playAndPauseAction:(BOOL)isPlay
{
    m_IsPlay = isPlay;
    if (isPlay)
    {
        if (m_IsEnd)
        {
            m_isStart = NO;
            m_IsEnd = NO;
            m_NowPosition = 0;
            [m_Decoder setPosition:0];
        }
        [[FFmpegPlayerAudioManager sharedAudioManager] play];
    }
    else
    {
        [[FFmpegPlayerAudioManager sharedAudioManager] pause:NO];
    }
}

- (void)setPositionAction:(CGFloat)positon
{
    if (positon < 0)
    {
        [self playAndPauseAction:NO];
        [[FFmpegPlayerAudioManager sharedAudioManager] pause:YES];
    }
    else
    {
        [m_Decoder setPosition:positon];
        [self.PlayerView cleanBuffer];
        [[FFmpegPlayerAudioManager sharedAudioManager] pause:YES];
        [self playAndPauseAction:YES];
    }
}

#pragma mark - GestureRecognizer Action

- (void)tapGestureRecognizerAction:(UIPanGestureRecognizer *)gesture
{
    [UIView animateWithDuration:0.5 animations:^{
        [m_ConView setAlpha:m_isHidden?1:0];
        m_isHidden = !m_isHidden;
    }];
}

#pragma mark - Interface orientation

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    self.PlayerView.interfaceOr = toInterfaceOrientation;
}
//屏幕旋转完成的状态
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterface
{
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    NSLog(@"viewWillLayoutSubviews %@",[NSValue valueWithCGRect:self.view.bounds]);
    [m_ConView setFrame:self.view.bounds];
    [m_ConView setBackgroundColor:[UIColor clearColor]];
    [m_ConView setNeedsDisplay];
    [m_ConView layoutIfNeeded];
    [self.PlayerView setFrame:self.view.bounds];
    [self.PlayerView setNeedsDisplay];
    [self.PlayerView layoutIfNeeded];
    [self.view bringSubviewToFront:self.PlayerView];
    [self.view bringSubviewToFront:m_ConView];
}

@end
